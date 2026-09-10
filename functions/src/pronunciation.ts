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
// 상한 2MB — 한 문장 녹음이면 충분하고, 메모리/OpenAI 비용 폭주를 막는다 (WP-01)
const MAX_AUDIO_BYTES = 2 * 1024 * 1024;
const MAX_TEXT_LEN = 200;
const ALLOWED_AUDIO_MIME = [
  "audio/m4a",
  "audio/mp4",
  "audio/x-m4a",
  "audio/aac",
  "audio/mpeg",
  "audio/mp3",
  "audio/wav",
  "audio/x-wav",
  "audio/webm",
  "audio/ogg",
];

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_AUDIO_BYTES, files: 1, fields: 4 },
  fileFilter: (_req, file, cb) => {
    const mime = (file.mimetype || "").split(";")[0].trim().toLowerCase();
    if (!ALLOWED_AUDIO_MIME.includes(mime)) {
      cb(new Error("unsupported_audio_type"));
      return;
    }
    cb(null, true);
  },
});

/** multer 오류(용량 초과·형식 불일치)를 500 대신 400 으로 변환한다. */
function uploadAudio(req: Request, res: Response, next: (err?: unknown) => void): void {
  upload.single("audio")(req, res, (err: unknown) => {
    if (err) {
      const code = (err as { code?: string }).code;
      const reason =
        code === "LIMIT_FILE_SIZE"
          ? "audio too large (max 2MB)"
          : (err as Error).message === "unsupported_audio_type"
          ? "unsupported audio type"
          : "invalid upload";
      res.status(400).json({ error: reason });
      return;
    }
    next();
  });
}

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
    uploadAudio,
    async (req: Request, res: Response) => {
      try {
        const audioFile = req.file;
        const expectedText = req.body?.text as string | undefined;

        if (!audioFile) {
          return res.status(400).json({ error: "audio field is required" });
        }
        if (!expectedText || typeof expectedText !== "string") {
          return res.status(400).json({ error: "text field is required" });
        }
        // 길이 상한 — computeScore 가 O(m·n) 이라 무제한이면 DoS 가 된다 (WP-01)
        if (expectedText.length > MAX_TEXT_LEN) {
          return res.status(400).json({ error: `text too long (max ${MAX_TEXT_LEN} chars)` });
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
