// pronunciation.ts — OpenAI Whisper 기반 발음 채점 엔드포인트
import OpenAI, { toFile } from "openai";
import type { Express, Request, Response } from "express";
import multer from "multer";

let _openai: OpenAI | null = null;
function getOpenAI(): OpenAI {
  if (!_openai) _openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  return _openai;
}

// 메모리 저장 (디스크 없이 Buffer로 처리)
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

interface PronunciationResponse {
  score: number;
  transcript: string;
  expected: string;
  feedback: string;
  details: Array<{ expected: string; heard: string; correct: boolean }>;
}

/** Levenshtein 거리 기반 유사도 점수 (0~100) */
function computeScore(expected: string, transcript: string): number {
  const normalize = (s: string) =>
    s.trim().toLowerCase().replace(/[^가-힣a-z0-9]/g, "");

  const exp = normalize(expected);
  const got = normalize(transcript);

  if (exp === got) return 100;
  if (exp.length === 0) return 0;

  const m = exp.length;
  const n = got.length;
  const dp: number[][] = Array.from({ length: m + 1 }, (_, i) =>
    Array.from({ length: n + 1 }, (_, j) => (i === 0 ? j : j === 0 ? i : 0))
  );

  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      dp[i][j] =
        exp[i - 1] === got[j - 1]
          ? dp[i - 1][j - 1]
          : 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
    }
  }

  const similarity = 1 - dp[m][n] / Math.max(m, n);
  return Math.max(0, Math.min(100, Math.round(similarity * 100)));
}

function buildFeedback(score: number, expected: string, transcript: string): string {
  if (score >= 90) return "발음이 정확해요! 훌륭합니다 🎉";
  if (score >= 75) return `거의 다 왔어요! "${expected}"를 다시 한번 천천히 말해보세요.`;
  if (score >= 50) return `"${expected}"를 여러 번 들어보고 따라 말해보세요.`;
  if (transcript) return `"${transcript}"라고 들렸어요. "${expected}"에 집중해보세요.`;
  return "목소리가 잘 들리지 않았어요. 마이크에 가까이 대고 다시 시도해주세요.";
}

export function setupPronunciationRoutes(app: Express): void {
  app.post(
    "/api/pronunciation/score",
    upload.single("audio"),
    async (req: Request, res: Response) => {
      try {
        const audioFile = req.file;
        const expectedText = req.body?.text as string | undefined;

        if (!audioFile) {
          return res.status(400).json({ error: "audio field is required" });
        }
        if (!expectedText) {
          return res.status(400).json({ error: "text field is required" });
        }

        // Buffer → OpenAI File 변환 (toFile 헬퍼 사용)
        const openaiFile = await toFile(
          audioFile.buffer,
          audioFile.originalname || "recording.m4a",
          { type: audioFile.mimetype || "audio/m4a" }
        );

        // OpenAI Whisper STT
        const transcription = await getOpenAI().audio.transcriptions.create({
          file: openaiFile,
          model: "whisper-1",
          language: "ko",
          response_format: "text",
        });

        const transcript = (transcription as unknown as string).trim();
        const score = computeScore(expectedText, transcript);
        const feedback = buildFeedback(score, expectedText, transcript);

        // 음절 단위 상세 비교
        const expChars = [...expectedText.replace(/\s/g, "")];
        const gotChars = [...transcript.replace(/\s/g, "")];
        const details = expChars.map((ch, i) => ({
          expected: ch,
          heard: gotChars[i] ?? "",
          correct: ch === gotChars[i],
        }));

        const result: PronunciationResponse = {
          score,
          transcript,
          expected: expectedText,
          feedback,
          details,
        };

        return res.json(result);
      } catch (error: unknown) {
        const msg = error instanceof Error ? error.message : String(error);
        console.error("[Pronunciation] Error:", msg);
        return res.status(500).json({
          score: 0,
          transcript: "",
          expected: "",
          feedback: "채점 서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
          details: [],
        });
      }
    }
  );
}
