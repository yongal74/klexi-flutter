# ADR-009: Backend Authentication — Firebase ID Token on Every Paid Route

**Date:** 2026-09-10
**Status:** Accepted
**Deciders:** Klexi PM 봇(claude-ad) / 구현 봇 트랙 A
**관련 작업:** build53 WP-01

---

## Context

build52 까지 `functions/src/index.ts` 는 `invoker: "public"` 으로 배포됐고, **어떤 라우트도 호출자를
확인하지 않았다.** `/api/ai-chat`, `/api/ai-tts`, `/api/pronunciation/score` 는 전부 OpenAI 비용을
발생시키는데, URL 만 알면 누구나 무제한으로 호출할 수 있었다. 추가로:

- `messages` 배열을 검증하지 않아 공격자가 `role: "system"` 을 끼워 넣어 서버 프롬프트를 무력화할 수 있었다.
- 응답 캐시 키가 `level:message` 뿐이라 모드가 달라도 같은 캐시를 먹었다(교차 오염).
- `pronunciation` 의 `text` 길이가 무제한이라 Levenshtein O(m·n) 으로 CPU 를 태울 수 있었다.
- 업로드 상한이 10MB 였다.

## Decision

1. **Firebase ID 토큰 검증을 Express 미들웨어로 넣는다** (`functions/src/auth.ts`, `requireAuth`).
   `Authorization: Bearer <idToken>` → `admin.auth().verifyIdToken()` → `req.uid`.
   실패는 401 `unauthenticated` / `invalid_token`.
2. 적용 범위는 `/api/ai-chat`, `/api/ai-tts`, `/api/pronunciation`. **`/api/health` 만 무인증**
   (비용이 없고 가용성 점검에 쓰인다).
3. `invoker: "public"` 은 유지한다. Cloud Run IAM 을 잠그면 모바일 클라이언트가 호출할 수 없고,
   Firebase ID 토큰이 애플리케이션 레벨 인가를 이미 담당하기 때문이다.
4. 입력 검증을 라우트별로 강제한다 — role 화이트리스트(user/assistant), content 1~1,000자,
   messages 1~8개, mode 화이트리스트, voice 화이트리스트, 오디오 2MB + mimetype, text 200자,
   `express.json({ limit: "16kb" })`.
5. 비용 상한으로 `maxInstances: 5` 를 건다. OpenAI 대시보드의 월 하드캡은 계정 소유자 몫.

## Alternatives considered

- **App Check 만 쓴다** — 기기 무결성은 보지만 사용자 신원이 없어 남용자를 특정할 수 없다.
  (App Check 는 ID 토큰과 병행 가능한 후속 과제로 남긴다.)
- **API 키를 앱에 심는다** — 앱 바이너리에서 추출 가능. 무의미.
- **IAM 으로 invoker 를 잠근다** — 모바일 앱은 서비스 계정을 가질 수 없다. 불가.

## Consequences

- **Positive**: 익명 남용이 막힌다. 남용 시 uid 단위로 추적·차단 가능.
- **Positive**: 프롬프트 주입(`role: "system"`)과 대용량 본문 DoS 가 라우트 진입 전에 차단된다.
- **Negative**: **게스트 사용자는 AI 기능을 쓸 수 없다.** 클라이언트(트랙 B)는 401 을
  `AuthRequiredException` 으로 바꿔 "Sign in to use AI features" 안내를 띄워야 한다.
  게스트에게 AI 를 열어주려면 Firebase 익명 인증 도입이 별도로 필요하다(build54 후보).
- **Negative**: 토큰 만료(1시간) 시 클라이언트가 갱신해야 한다 — `getIdToken()` 이 자동 갱신하므로
  매 요청 호출하는 것으로 충분하다.
- **Watch**: 응답 캐시는 여전히 **전 사용자 공유**다. 캐시 키에 `mode` 를 넣어 모드 간 오염은
  막았지만, 캐시된 내용 자체는 서버가 만든 일반 응답이라 개인정보가 섞이지 않는다는 전제에 의존한다.
  개인화 응답을 캐시하게 되면 키에 uid 를 넣어야 한다.

## Verification

배포 전 로컬 검증(트랙 A, 2026-09-10): 토큰 없음/Bearer 아님 → 401, `role:"system"` → 400,
messages 9개 → 400, content 1,001자 → 400, mode 임의값 → 400, voice 임의값 → 400,
tts 501자 → 400, 본문 16KB 초과 → 400, 정상 요청 → 200.
배포 후에는 유효 토큰 200 / 무토큰 401 을 실제 엔드포인트로 재확인한다.
