import * as admin from "firebase-admin";
import express from "express";
import cors from "cors";
import { onRequest } from "firebase-functions/v2/https";
import { setupAIChatRoutes } from "./ai-chat";
import { setupAITTSRoutes } from "./ai-tts";

admin.initializeApp();

const app = express();

app.use(cors({
  origin: [
    "https://klexi-30ab5.web.app",
    "https://klexi-30ab5.firebaseapp.com",
    "http://localhost:3000",
    "http://localhost:8080",
  ],
  credentials: true,
}));

app.use(express.json());

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

setupAIChatRoutes(app);
setupAITTSRoutes(app);

export const api = onRequest({ timeoutSeconds: 60, memory: "512MiB", region: "us-central1", invoker: "public" }, app);
