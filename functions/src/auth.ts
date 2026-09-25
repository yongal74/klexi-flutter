// auth.ts — Firebase ID 토큰 검증 미들웨어 (WP-01)
// 모든 비용 유발 라우트(/api/ai-chat, /api/ai-tts, /api/pronunciation)에 적용한다.
// /api/health 는 무인증 유지(가용성 점검용, 비용 없음).
import * as admin from "firebase-admin";
import { defineString } from "firebase-functions/params";
import type { Request, Response, NextFunction } from "express";

/**
 * 인증 강도. 라이브(build52) 앱은 토큰을 보내지 않으므로, 인증을 곧바로
 * 강제하면 배포 즉시 기존 사용자 전원의 AI 기능이 401 로 죽는다.
 *
 *  soft — 토큰이 아예 없으면 통과시킨다(경고 로그만 남겨 잔존 구버전을 계수).
 *         토큰이 있는데 무효면 401. 무효 토큰은 신버전만 보내므로,
 *         구버전 호환을 지키면서도 토큰 위조는 막는다.
 *  hard — 토큰이 없어도 401. build53 이 충분히 보급된 뒤 전환한다.
 *
 * 전환 조건(build53 ≥ 90% 또는 출시 14일 경과 중 먼저 오는 시점)은
 * docs/UPGRADE_PLAN_build53.md 와 HANDOFF 문서에 있다.
 * 값 변경은 코드 수정 없이 배포 파라미터로 지정한다.
 */
const authMode = defineString("AUTH_MODE", { default: "soft" });

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
  const match = /^bearer\s+(.+)$/i.exec(header);
  const token = match ? match[1].trim() : null;

  if (!token) {
    if (authMode.value() === "soft") {
      // 잔존 구버전 트래픽 계수용. hard 전환 판단 근거가 된다.
      console.warn(`[auth] missing token (soft) path=${req.path}`);
      next();
      return;
    }
    res.status(401).json({ error: "unauthenticated" });
    return;
  }

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    (req as AuthedRequest).uid = decoded.uid;
    next();
  } catch (error: unknown) {
    // 토큰 내용은 절대 로그에 남기지 않는다.
    // 무효 토큰은 soft 모드에서도 거절한다 — 구버전 클라이언트는 애초에
    // Authorization 헤더를 보내지 않으므로 호환성에 영향이 없다.
    const msg = error instanceof Error ? error.message : String(error);
    console.warn("[auth] invalid token:", msg);
    res.status(401).json({ error: "invalid_token" });
  }
}
