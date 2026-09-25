import * as admin from "firebase-admin";
import express from "express";
import cors from "cors";
import { onRequest } from "firebase-functions/v2/https";
import OpenAI from "openai";
import { requireAuth } from "./auth";
import { bodyLimit, rateLimit } from "./guard";
import { setupAIChatRoutes } from "./ai-chat";
import { setupAITTSRoutes } from "./ai-tts";
import { setupPronunciationRoutes } from "./pronunciation";

admin.initializeApp();

const app = express();

const allowedOrigins = [
  "https://klexi-30ab5.web.app",
  "https://klexi-30ab5.firebaseapp.com",
  ...(process.env.FUNCTIONS_EMULATOR === "true"
    ? ["http://localhost:3000", "http://localhost:8080"]
    : []),
];

app.use(cors({
  origin: allowedOrigins,
  credentials: true,
}));

// JSON 파싱(로컬·에뮬레이터용). Cloud Functions 에선 런타임이 먼저 파싱하므로
// 실제 크기 상한은 아래 bodyLimit(rawBody 길이 검사)이 담당한다.
app.use(express.json({ limit: "16kb" }));

// 헬스체크만 무인증. 나머지 라우트는 Firebase ID 토큰 필수.
// ?deep=1 이면 OpenAI 키까지 확인한다 — 09-25 에 키가 무효화된 걸 아무도 몰랐다
// (기존 health 는 OpenAI 를 안 봐서 200 이었다). 모니터링 업타임 체크를 이 주소로 건다.
let deepCache: { ok: boolean; at: number } | null = null;
app.get("/api/health", async (req, res) => {
  const base = { status: "ok", timestamp: new Date().toISOString() };
  if (req.query.deep !== "1") {
    res.json(base);
    return;
  }
  if (!deepCache || Date.now() - deepCache.at > 10 * 60 * 1000) {
    try {
      await new OpenAI({ apiKey: process.env.OPENAI_API_KEY }).models.list();
      deepCache = { ok: true, at: Date.now() };
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      console.error("[health] OpenAI check failed:", msg);
      deepCache = { ok: false, at: Date.now() };
    }
  }
  if (deepCache.ok) {
    res.json({ ...base, openai: "ok" });
  } else {
    res.status(503).json({ ...base, status: "degraded", openai: "failed" });
  }
});

// 순서: 크기 상한 → 인증(uid 확보) → 사용자별 호출 제한
app.use("/api/ai-chat", bodyLimit(16 * 1024), requireAuth, rateLimit("chat", 40, 10 * 60 * 1000));
app.use("/api/ai-tts", bodyLimit(8 * 1024), requireAuth, rateLimit("tts", 150, 10 * 60 * 1000));
app.use(
  "/api/pronunciation",
  bodyLimit(3 * 1024 * 1024),
  requireAuth,
  rateLimit("pron", 60, 10 * 60 * 1000)
);

setupAIChatRoutes(app);
setupAITTSRoutes(app);
setupPronunciationRoutes(app);

// 잘못된 JSON / 본문 초과는 500 대신 400 으로 응답한다.
app.use((err: unknown, _req: express.Request, res: express.Response, next: express.NextFunction) => {
  const e = err as { type?: string; status?: number };
  if (e && (e.type === "entity.too.large" || e.type === "entity.parse.failed")) {
    res.status(400).json({ error: "invalid_body" });
    return;
  }
  next(err);
});

// invoker: "public" 은 Cloud Run 레벨 접근 허용. 실제 인가는 위 requireAuth 가 담당한다.
export const api = onRequest(
  {
    timeoutSeconds: 60,
    memory: "512MiB",
    region: "us-central1",
    invoker: "public",
    maxInstances: 5,
    // OpenAI 키는 Secret Manager 에서 주입한다(process.env.OPENAI_API_KEY 로 노출됨).
    // 예전엔 배포 시점 .env 로 들어가 있어서, .env 없이 재배포하면 키가 사라졌다.
    // 설정: firebase functions:secrets:set OPENAI_API_KEY --project klexi-30ab5
    secrets: ["OPENAI_API_KEY"],
  },
  app
);
