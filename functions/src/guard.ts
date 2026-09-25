// guard.ts — 비용 유발 라우트 보호: 요청 크기 상한 + 사용자별 호출 제한.
//
// Cloud Functions 는 Express 앞단에서 본문을 미리 읽어 req.rawBody 에 넣는다.
// 그래서 express.json({limit}) 만으로는 크기 상한이 걸리지 않을 수 있어,
// rawBody 길이로 직접 검사한다.
//
// 호출 제한은 인스턴스 메모리 기반 고정 창(fixed window)이다. 인스턴스가
// 최대 maxInstances(5)개이므로 실제 상한은 최대 5배까지 느슨해질 수 있다.
// 목적은 스크립트로 OpenAI 비용을 태우는 남용을 막는 것이지 정밀 과금이 아니다.
import type { Request, Response, NextFunction } from "express";
import type { AuthedRequest } from "./auth";

export function bodyLimit(maxBytes: number) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const raw = (req as Request & { rawBody?: Buffer }).rawBody;
    const len = raw?.length ?? Number(req.headers["content-length"] ?? 0);
    if (len > maxBytes) {
      res.status(413).json({ error: "payload_too_large" });
      return;
    }
    next();
  };
}

interface Window {
  start: number;
  count: number;
}

const windows = new Map<string, Window>();
const MAX_KEYS = 10000;

function clientKey(req: Request): string {
  const uid = (req as AuthedRequest).uid;
  if (uid) return `u:${uid}`;
  const fwd = String(req.headers["x-forwarded-for"] ?? "").split(",")[0].trim();
  return `ip:${fwd || req.ip || "unknown"}`;
}

/** [limit] 회 / [windowMs] 를 넘으면 429. 키는 로그인 uid, 없으면 IP. */
export function rateLimit(name: string, limit: number, windowMs: number) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const key = `${name}:${clientKey(req)}`;
    const now = Date.now();
    const w = windows.get(key);
    if (!w || now - w.start >= windowMs) {
      if (windows.size >= MAX_KEYS) windows.clear();
      windows.set(key, { start: now, count: 1 });
      next();
      return;
    }
    w.count++;
    if (w.count > limit) {
      const retry = Math.ceil((w.start + windowMs - now) / 1000);
      res.setHeader("Retry-After", String(retry));
      console.warn(`[guard] rate limited ${key}`);
      res.status(429).json({ error: "rate_limited", retryAfterSeconds: retry });
      return;
    }
    next();
  };
}
