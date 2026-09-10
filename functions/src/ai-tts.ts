import OpenAI from "openai";
import type { Express, Request, Response } from "express";

let _openai: OpenAI | null = null;
function getOpenAI(): OpenAI {
  if (!_openai) _openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  return _openai;
}


const ALLOWED_VOICES = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"] as const;
type Voice = (typeof ALLOWED_VOICES)[number];

const MAX_TEXT_LEN = 500;

export function setupAITTSRoutes(app: Express): void {
  app.post("/api/ai-tts", async (req: Request, res: Response) => {
    const body = (typeof req.body === "object" && req.body !== null
      ? req.body
      : {}) as Record<string, unknown>;

    const text = body.text;
    if (typeof text !== "string" || text.length === 0) {
      return res.status(400).json({ error: "text is required" });
    }
    if (text.length > MAX_TEXT_LEN) {
      return res.status(400).json({ error: `Text too long (max ${MAX_TEXT_LEN} chars)` });
    }

    // voice 화이트리스트 — 임의 값이 OpenAI 로 그대로 전달되지 않게 한다 (WP-01)
    let voice: Voice = "nova";
    if (body.voice !== undefined) {
      if (typeof body.voice !== "string" || !(ALLOWED_VOICES as readonly string[]).includes(body.voice)) {
        return res.status(400).json({ error: "invalid voice" });
      }
      voice = body.voice as Voice;
    }

    try {
      const mp3 = await getOpenAI().audio.speech.create({ model: "tts-1", voice, input: text });
      const buffer = Buffer.from(await mp3.arrayBuffer());
      res.setHeader("Content-Type", "audio/mpeg");
      res.setHeader("Content-Length", buffer.length.toString());
      return res.send(buffer);
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      console.error("TTS error:", msg);
      return res.status(500).json({ error: "Failed to generate speech" });
    }
  });
}
