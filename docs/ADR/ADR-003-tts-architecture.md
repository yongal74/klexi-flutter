# ADR-003: TTS Architecture — Multi-Tier Fallback

**Date:** 2026-03
**Status:** Accepted
**Deciders:** Klexi dev team

---

## Context

Korean TTS quality matters enormously for a language learning app. Device TTS (Google TTS on Android) has acceptable quality but lacks the natural intonation needed for learners to model pronunciation correctly.

Requirements:
- High-quality Korean pronunciation for premium users
- Works offline as fallback for free users
- Caches audio to avoid repeated API calls

## Decision

Implement a **3-tier TTS fallback** in `TtsService`:

```
Premium users:
  1st → Naver CLOVA Voice (server proxy)    ← best Korean quality
  2nd → Google Cloud TTS Neural2 (server)   ← high quality fallback
  3rd → Device TTS (flutter_tts)            ← offline fallback

Free users:
  → Device TTS only
```

**Implementation:**
```dart
// lib/core/utils/tts_service.dart
Future<void> speak(String text, {TtsSpeed speed, bool isPremium}) async {
  if (isPremium) {
    if (await _speakWithClova(text, speed)) return;
    if (await _speakWithGoogle(text, speed)) return;
  }
  await _speakWithTts(text, speed);
}
```

**Server proxy:**
- Backend URL: `AppConfig.backendUrl` (`https://klexi-30ab5.web.app`)
- Endpoints: `POST /api/tts/clova`, `POST /api/tts/google`
- `Dio` client configured with 5s connect / 10s receive timeout

**Audio caching:**
- MP3 files cached locally via `tts_service_mobile.dart` platform implementation
- Cache key: `{text}_{speed}_{engine}`

**Speed settings:**
```dart
enum TtsSpeed { normal, slow }
// normal → CLOVA speed 0, Google speakingRate 1.0, flutter_tts 0.5
// slow   → CLOVA speed -4, Google speakingRate 0.65, flutter_tts 0.4
```

## Critical Bug Fixed (build48)

`dioProvider` had `defaultValue: 'https://your-server.com'` — a placeholder that was never replaced. Premium TTS was silently failing for all users since launch. Fixed to use `AppConfig.backendUrl`.

## Consequences

- **Positive**: Premium users get studio-quality Korean TTS.
- **Positive**: Graceful degradation ensures TTS always works even without network.
- **Negative**: Server proxy costs (CLOVA API + Google Cloud TTS charges).
- **Watch**: CLOVA Voice API rate limits; implement retry logic if needed.
