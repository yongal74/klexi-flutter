// auth.ts — Firebase ID 토큰 검증 미들웨어 (WP-01)
// 모든 비용 유발 라우트(/api/ai-chat, /api/ai-tts, /api/pronunciation)에 적용한다.
// /api/health 는 무인증 유지(가용성 점검용, 비용 없음).
import * as admin from "firebase-admin";
import type { Request, Response, NextFunction } from "express";

/** 인증된 요청 — 검증 통과 시 uid 가 채워진다. */
export interface AuthedRequest extends Request {
  uid?: string;
}

export async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const header = req.headers.authorization ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : null;

  if (!token) {
    res.status(401).json({ error: "unauthenticated" });
    return;
  }

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    (req as AuthedRequest).uid = decoded.uid;
    next();
  } catch (error: unknown) {
    // 토큰 내용은 절대 로그에 남기지 않는다.
    const msg = error instanceof Error ? error.message : String(error);
    console.warn("[auth] invalid token:", msg);
    res.status(401).json({ error: "invalid_token" });
  }
}
