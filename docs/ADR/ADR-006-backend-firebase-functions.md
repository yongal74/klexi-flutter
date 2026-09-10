# ADR-006: Backend — Firebase Cloud Functions

**Date:** 2026-03
**Status:** Accepted
**Deciders:** Klexi dev team

---

## Context

Klexi needs a backend for:
- AI chat (OpenAI API key must not be in the client)
- TTS proxying (Naver CLOVA + Google Cloud TTS API keys)
- Future: push notification scheduling, analytics aggregation

## Decision

Use **Firebase Cloud Functions** with TypeScript/Express as the backend.

### Architecture

```
Client (Flutter)
    │
    ├── POST /api/ai-chat      → ai-chat.ts   → OpenAI GPT-4o-mini (SSE)
    ├── POST /api/tts/clova    → ai-tts.ts    → Naver CLOVA Voice API
    └── POST /api/tts/google   → ai-tts.ts    → Google Cloud TTS
```

**Base URL:** `https://klexi-30ab5.web.app` (Firebase Hosting + Functions rewrite)

### AI Chat Design

```typescript
// functions/src/index.ts
// SSE streaming — chunks sent as they arrive from OpenAI
// History: last 8 messages only (cost control)
// Server-side cache: 1 hour TTL, max 200 entries (identical messages)
```

**Modes:**
- `freeChat` — open conversation
- `wordReview` — practice today's vocabulary
- `rolePlay` — scenario-based dialogue
- `grammarCoach` — grammar pattern practice

### TTS Proxy Design

```typescript
// functions/src/ai-tts.ts
// CLOVA: POST /api/tts/clova → returns MP3 bytes
// Google: POST /api/tts/google → returns MP3 bytes
// No server-side caching (client caches locally)
```

### Deployment

```bash
cd functions
npm run build && firebase deploy --only functions
```

### Legacy Code

`functions/src/polar.ts` — retained for reference only (old Polar webhook handler). Not deployed in production.

## Consequences

- **Positive**: API keys never exposed to client.
- **Positive**: Firebase Functions scales to zero — no idle cost.
- **Negative**: Cold start latency (~1–2s) on first request after idle.
- **Watch**: OpenAI API costs scale with usage; monitor monthly spend.
