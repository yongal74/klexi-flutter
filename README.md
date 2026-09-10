# Klexi — Learn Korean Through Sentences

> TOPIK 1–6 vocabulary, AI conversation, Word Network, Grammar Coach, and pronunciation feedback — in one Android app.

[![CI](https://github.com/yongal74/klexi-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/yongal74/klexi-flutter/actions/workflows/ci.yml)

---

## Overview

Klexi is a Flutter app for learners of Korean at TOPIK levels 1–6. It combines a daily vocabulary
session with spaced review, quizzes, an AI conversation tutor, and pronunciation scoring.

| | |
|---|---|
| **Platform** | Android (production). An iOS project exists but is not released. |
| **Play listing** | `com.twentykorean.app` |
| **Live version** | 1.0.6+52 (published 2026-09-02) |
| **In development** | 1.0.6+53 |
| **Backend** | Firebase Cloud Functions + Hosting — `https://klexi-30ab5.web.app` |

---

## Features

| Feature | Description | Premium |
|---|---|---|
| Daily Study | 20 words/day, reviews on a fixed interval ladder `1→3→7→14→30→60` days (ADR-004 — this is **not** SM-2) | Free (TOPIK 1 only) |
| Sentence Cards | Flip cards with Korean sentence context | Free |
| Quiz | Multiple-choice & fill-in review | Free |
| Sentence Practice | Fill-in-the-blank writing practice | Free |
| Dalli AI Chat | GPT-4o-mini conversation in 4 modes (free chat / word review / role play / grammar coach) | Yes |
| Grammar Coach | Grammar pattern browser with examples | Yes |
| Theme Packs | Themed vocabulary sets | Yes |
| Pronunciation | Recording + OpenAI Whisper scoring | Yes |
| Word Network | Graph-based related-word explorer | Free |
| Hangeul | Letter tracing practice | Free |
| Progress | Streaks and study statistics | Free |
| TOPIK 2–6 | Full 7,200-word vocabulary access | Yes |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.41.4 / Dart 3.x |
| State management | flutter_riverpod 2.x (ADR-001) |
| Routing | go_router 14.x — `lib/core/router/app_router.dart` |
| Local storage | Hive (study records, chat history), SharedPreferences (settings) |
| Auth | Firebase Auth + Google Sign-In (ADR-005) |
| Payments | RevenueCat / purchases_flutter 9.x, entitlement id `premium` (ADR-002) |
| Backend | Firebase Cloud Functions, TypeScript + Express (ADR-006) |
| AI chat | OpenAI GPT-4o-mini, SSE streaming |
| TTS | OpenAI TTS (`/api/ai-tts`) with device TTS fallback (ADR-003) |
| Analytics | Firebase Analytics + Crashlytics |
| Push / reminders | FCM + flutter_local_notifications |

> **Web is not a supported target.** purchases_flutter has no web implementation, so a Flutter web
> build renders a blank screen. `web/index.html` is therefore a static landing page, not the app.

---

## Backend

Source: `functions/` (Node 22, TypeScript). Deployed as a single `api` HTTPS function; Hosting
rewrites `/api/**` to it.

| Route | Auth | Purpose |
|---|---|---|
| `GET /api/health` | none | Liveness check |
| `POST /api/ai-chat` | Firebase ID token | Dalli conversation, SSE stream |
| `POST /api/ai-tts` | Firebase ID token | OpenAI text-to-speech (mp3) |
| `POST /api/pronunciation/score` | Firebase ID token | Whisper transcription + similarity score |

Every paid route requires `Authorization: Bearer <Firebase ID token>` (ADR-009); requests without a
valid token get `401`. Input limits: chat messages 1–8 of at most 1,000 chars each (roles `user` and
`assistant` only), TTS text at most 500 chars with a `voice` whitelist, pronunciation audio at most
2MB with `text` at most 200 chars, JSON body at most 16KB, `maxInstances: 5`.

```bash
cd functions
npm ci
npm run build        # tsc — run before deploying; lib/ is build output and is not committed
```

`functions/.env` holds `OPENAI_API_KEY` and is never committed.

---

## Project structure

```
lib/
  core/
    constants/     AppColors, AppSpacing, AppConfig, AppTypography, AppStrings
    providers/     cross-feature shared state (userTopikLevelProvider, ...)
    router/        GoRouter configuration  <- read before editing any screen
    services/      auth, purchase, fcm, notification, analytics, pronunciation,
                   daily_session (study records + scheduling)
    theme/         AppTheme
    utils/         TtsService
    widgets/       MainScaffold, PaywallGate
  data/
    content/       7,200 vocab words, grammar patterns, theme sentences
    models/        Word, GrammarPattern
    repositories/  WordRepository (singleton, cached — ADR-008)
  features/        auth, chat, grammar, hangeul, home, learn, premium, progress,
                   pronunciation, settings, themes, word_network
functions/src/     auth.ts, index.ts, ai-chat.ts, ai-tts.ts, pronunciation.ts
web/               landing page + /privacy, /terms, /delete-account
docs/              ADR + CHANGELOG (single source of truth)
```

---

## Getting started

### Prerequisites

- Flutter 3.41.4 (`flutter --version`) — the CI pin; `pubspec.lock` requires 3.38.4 or newer
- Java 17 for Android builds
- Firebase project with `android/app/google-services.json`
- `lib/firebase_options.dart` (generate with `flutterfire configure`)

Both Firebase files are excluded from git; ask the project owner for them.

### Run

```bash
flutter pub get
flutter run                 # Android device or emulator
flutter analyze
flutter test
```

### Release build

Signing needs `android/key.properties` pointing at the release keystore:

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=../klexi-release.jks     # resolves to android/klexi-release.jks
```

```bash
flutter build appbundle --release
# verify the signature matches the live listing (META-INF/7EDE361C.SF)
jarsigner -verify -verbose:summary -certs build/app/outputs/bundle/release/app-release.aab
```

### Secrets checklist

| File | Contents | In git? |
|---|---|---|
| `lib/firebase_options.dart` | Firebase client config | No |
| `android/app/google-services.json` | Firebase Android config | No |
| `android/klexi-release.jks` | Release signing key | No — never modify or delete |
| `android/key.properties` | Keystore credentials | No |
| `functions/.env` | `OPENAI_API_KEY` | No |

CI release builds read `KEYSTORE_BASE64` and `KEY_PROPERTIES` from repository secrets.

---

## Architecture decisions

Full records in [`docs/ADR/`](docs/ADR/), index in [`docs/README.md`](docs/README.md).

- **ADR-001** Riverpod for state management
- **ADR-002** RevenueCat for in-app purchases
- **ADR-003** TTS architecture
- **ADR-004** Spaced repetition — fixed interval ladder (corrected 2026-09-10; it was never SM-2)
- **ADR-005** Firebase Auth + Google Sign-In
- **ADR-006** Firebase Cloud Functions backend
- **ADR-007** `userTopikLevelProvider` extracted to `core/providers`
- **ADR-008** `WordRepository` singleton caching
- **ADR-009** Backend auth — Firebase ID token on every paid route
- **ADR-010** Study records scoped per Firebase UID

---

## CI/CD

GitHub Actions runs on every push to `master`, `main` or `develop`:

1. **analyze-and-test** — `flutter analyze --no-fatal-infos` plus `flutter test --coverage`
2. **build-android** — release AAB (master only, skipped when signing secrets are absent)

---

## Changelog

[`docs/CHANGELOG.md`](docs/CHANGELOG.md)

---

## Gotchas

- Read `lib/core/router/app_router.dart` before editing any screen — the file that renders is often
  not the one the name suggests.
- The RevenueCat entitlement id must be exactly `premium` (case-sensitive).
- Hive box names must not change without a data migration (ADR-010).
- `functions/lib/` is build output and is not committed — run `npm run build` before deploying.
