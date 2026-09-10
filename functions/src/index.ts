import * as admin from "firebase-admin";
import express from "express";
import cors from "cors";
import { onRequest } from "firebase-functions/v2/https";
import { requireAuth } from "./auth";
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

// JSON 본문 상한 16KB — 대용량 프롬프트 주입/메모리 고갈 방어 (WP-01)
app.use(express.json({ limit: "16kb" }));

// 헬스체크만 무인증. 나머지 라우트는 Firebase ID 토큰 필수.
app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.use("/api/ai-chat", requireAuth);
app.use("/api/ai-tts", requireAuth);
app.use("/api/pronunciation", requireAuth);

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
  },
  app
);
