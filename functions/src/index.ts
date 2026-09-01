import * as admin from "firebase-admin";
import express from "express";
import cors from "cors";
import { onRequest } from "firebase-functions/v2/https";
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

app.use(express.json());

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

setupAIChatRoutes(app);
setupAITTSRoutes(app);
setupPronunciationRoutes(app);

export const api = onRequest({ timeoutSeconds: 60, memory: "512MiB", region: "us-central1", invoker: "public" }, app);
