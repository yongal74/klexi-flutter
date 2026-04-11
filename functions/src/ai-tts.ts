import OpenAI from "openai";
import type { Express, Request, Response } from "express";

let _openai: OpenAI | null = null;
function getOpenAI(): OpenAI {
  if (!_openai) _openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  return _openai;
}


export function setupAITTSRoutes(app: Express): void {
  app.post("/api/ai-tts", async (req: Request, res: Response) => {
    try {
      const { text, voice = "nova" } = req.body as {
        text: string;
        voice?: "alloy" | "echo" | "fable" | "onyx" | "nova" | "shimmer";
      };
      if (!text || typeof text !== "string") {
        return res.status(400).json({ error: "text is required" });
      }
      if (text.length > 500) {
        return res.status(400).json({ error: "Text too long (max 500 chars)" });
      }
      const mp3 = await getOpenAI().audio.speech.create({ model: "tts-1", voice, input: text });
      const buffer = Buffer.from(await mp3.arrayBuffer());
      res.setHeader("Content-Type", "audio/mpeg");
      res.setHeader("Content-Length", buffer.length.toString());
      res.send(buffer);
    } catch (error: any) {
      console.error("TTS error:", error?.message || error);
      res.status(500).json({ error: "Failed to generate speech" });
    }
  });
}
