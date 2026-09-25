// pronunciation.ts — OpenAI Whisper 기반 발음 채점 엔드포인트
//
// 업로드 파싱은 busboy 로 req.rawBody 를 직접 읽는다. Cloud Functions 는 Express
// 앞단에서 본문 스트림을 이미 다 읽어 rawBody 에 넣기 때문에, 스트림을 읽는
// multer 는 파일을 받지 못한다(요청이 멈추거나 "audio field is required").
import OpenAI, { toFile } from "openai";
import Busboy from "busboy";
import type { Express, Request, Response, NextFunction } from "express";

let _openai: OpenAI | null = null;
function getOpenAI(): OpenAI {
  if (!_openai) _openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  return _openai;
}

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
  // build52 앱은 contentType 을 지정하지 않아 dio 기본값(octet-stream)으로 온다.
  // 실제 형식은 아래 sniffAudio 가 파일 머리로 판별한다.
  "application/octet-stream",
];

interface Upload {
  buffer: Buffer;
  filename: string;
  mimetype: string;
}

type UploadRequest = Request & { upload?: Upload; fields?: Record<string, string> };

/** multipart 를 파싱해 req.upload / req.fields 에 넣는다. 오류는 400. */
function parseMultipart(req: Request, res: Response, next: NextFunction): void {
  let bb: Busboy.Busboy;
  try {
    bb = Busboy({
      headers: req.headers,
      limits: { fileSize: MAX_AUDIO_BYTES, files: 1, fields: 4 },
    });
  } catch {
    res.status(400).json({ error: "invalid upload" });
    return;
  }

  const r = req as UploadRequest;
  const fields: Record<string, string> = {};
  const chunks: Buffer[] = [];
  let file: { filename: string; mimetype: string } | null = null;
  let failure: string | null = null;

  bb.on("field", (name, value) => {
    fields[name] = value;
  });
  bb.on("file", (name, stream, info) => {
    const mime = (info.mimeType || "").split(";")[0].trim().toLowerCase();
    if (name !== "audio") {
      failure = "unsupported audio type";
      stream.resume();
      return;
    }
    // 형식 표시는 클라이언트마다 제각각(build52 는 표시 없음)이라 여기선 받고,
    // 다 받은 뒤 허용 목록 또는 파일 머리 판별로 최종 확인한다.
    file = { filename: info.filename || "recording", mimetype: mime };
    stream.on("data", (d: Buffer) => chunks.push(d));
    stream.on("limit", () => {
      failure = "audio too large (max 2MB)";
    });
  });
  bb.on("error", () => {
    if (!res.headersSent) res.status(400).json({ error: "invalid upload" });
  });
  bb.on("close", () => {
    if (res.headersSent) return;
    if (failure) {
      res.status(400).json({ error: failure });
      return;
    }
    r.fields = fields;
    if (file) {
      const f = file as { filename: string; mimetype: string };
      const buffer = Buffer.concat(chunks);
      const known = sniffAudio(buffer, "", "").name !== "";
      if (!ALLOWED_AUDIO_MIME.includes(f.mimetype) && !known) {
        res.status(400).json({ error: "unsupported audio type" });
        return;
      }
      r.upload = { buffer, filename: f.filename, mimetype: f.mimetype };
    }
    next();
  });

  const raw = (req as Request & { rawBody?: Buffer }).rawBody;
  if (raw) {
    bb.end(raw); // Cloud Functions
  } else {
    req.pipe(bb); // 로컬 Express·에뮬레이터
  }
}

/**
 * 파일 머리(magic bytes)로 실제 형식을 판별해 Whisper 가 알아보는 파일명·타입을 붙인다.
 * build52 는 m4a 녹음을 "recording.webm"·octet-stream 으로 보내서, 그대로 넘기면
 * Whisper 가 형식을 잘못 읽는다.
 */
function sniffAudio(buf: Buffer, fallbackName: string, fallbackType: string) {
  const head = buf.subarray(0, 12);
  if (head.subarray(4, 8).toString("ascii") === "ftyp") {
    return { name: "recording.m4a", type: "audio/mp4" };
  }
  if (head.subarray(0, 4).toString("ascii") === "RIFF") {
    return { name: "recording.wav", type: "audio/wav" };
  }
  if (head.subarray(0, 4).toString("ascii") === "OggS") {
    return { name: "recording.ogg", type: "audio/ogg" };
  }
  if (head[0] === 0x1a && head[1] === 0x45 && head[2] === 0xdf && head[3] === 0xa3) {
    return { name: "recording.webm", type: "audio/webm" };
  }
  if (head.subarray(0, 3).toString("ascii") === "ID3" || (head[0] === 0xff && (head[1] & 0xe0) === 0xe0)) {
    return { name: "recording.mp3", type: "audio/mpeg" };
  }
  return { name: fallbackName, type: fallbackType };
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

// 사용자는 영어권 학습자 — 피드백은 영어로(구버전 앱은 이 문구를 그대로 보여준다)
function buildFeedback(score: number, expected: string, transcript: string): string {
  if (score >= 90) return "Excellent pronunciation! 🎉";
  if (score >= 75) return `Almost there! Say "${expected}" once more, slowly.`;
  if (score >= 50) return `Listen to "${expected}" a few times and repeat after it.`;
  if (transcript) return `We heard "${transcript}". Focus on "${expected}".`;
  return "We couldn't hear you clearly. Hold the phone closer and try again.";
}

export function setupPronunciationRoutes(app: Express): void {
  app.post(
    "/api/pronunciation/score",
    parseMultipart,
    async (req: Request, res: Response) => {
      try {
        const r = req as UploadRequest;
        const audioFile = r.upload;
        const expectedText = r.fields?.text;

        if (!audioFile || audioFile.buffer.length === 0) {
          return res.status(400).json({ error: "audio field is required" });
        }
        if (!expectedText || typeof expectedText !== "string") {
          return res.status(400).json({ error: "text field is required" });
        }
        // 길이 상한 — computeScore 가 O(m·n) 이라 무제한이면 DoS 가 된다 (WP-01)
        if (expectedText.length > MAX_TEXT_LEN) {
          return res.status(400).json({ error: `text too long (max ${MAX_TEXT_LEN} chars)` });
        }

        const detected = sniffAudio(
          audioFile.buffer,
          audioFile.filename || "recording.m4a",
          audioFile.mimetype === "application/octet-stream" ? "audio/mp4" : audioFile.mimetype
        );
        const openaiFile = await toFile(audioFile.buffer, detected.name, {
          type: detected.type,
        });

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
          feedback: "Scoring is temporarily unavailable. Please try again shortly.",
          details: [],
        });
      }
    }
  );
}
