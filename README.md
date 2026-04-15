# Klexi — Learn Korean Through Sentences

> TOPIK 1–6 vocabulary, AI conversation, Word Network, Grammar Coach, and Pronunciation feedback — all in one app.

[![CI](https://github.com/yongal74/klexi-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/yongal74/klexi-flutter/actions/workflows/ci.yml)

---

## Overview

Klexi is a Flutter-based Korean learning app targeting non-native speakers at all TOPIK levels (1–6). It combines spaced repetition, AI conversation, and cultural content to accelerate Korean acquisition.

**Platform:** Android (production), iOS (in progress)
**Current Version:** 1.0.6+49
**Status:** Google Play production live

---

## Features

| Feature | Description | Premium |
|---|---|---|
| Daily Study | SM-2 SRS — 20 words/day, auto-scheduled | Free (TOPIK 1 only) |
| Sentence Cards | Flip cards with Korean sentence context | Free |
| Quiz | Multiple-choice & fill-in review | Free |
| Sentence Practice | Fill-in-the-blank writing practice | Free |
| Dalli AI Chat | GPT-4o-mini conversation in 4 modes | ✅ |
| Grammar Coach | 100+ grammar patterns with examples | ✅ |
| Theme Packs | K-drama, K-pop, K-food, Travel vocabulary | ✅ |
| Pronunciation | Recording + server-side scoring | ✅ |
| Word Network | Graph-based related word explorer | Free |
| TOPIK 2–6 | Full 7,200 word vocabulary access | ✅ |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x / Dart 3.6 |
| State Management | flutter_riverpod 2.x |
| Routing | go_router 14.x |
| Local DB | Hive (SRS records), SharedPreferences (settings) |
| Auth | Firebase Auth + Google Sign-In |
| Payments | RevenueCat (purchases_flutter 9.x) |
| Backend | Firebase Cloud Functions (TypeScript/Express) |
| AI Chat | OpenAI GPT-4o-mini (SSE streaming) |
| TTS | Naver CLOVA Voice → Google Neural2 → Device TTS |
| Analytics | Firebase Analytics + Crashlytics |
| Push | FCM + flutter_local_notifications |

---

## Project Structure

```
lib/
├── core/
│   ├── constants/          # AppColors, AppSpacing, AppConfig, AppTypography
│   ├── providers/          # userTopikLevelProvider (cross-feature shared state)
│   ├── router/             # GoRouter configuration
│   ├── services/           # auth, purchase, fcm, notification, analytics, pronunciation
│   ├── theme/              # AppTheme
│   ├── utils/              # TtsService (CLOVA/Google/Device fallback), SrsAlgorithm
│   └── widgets/            # MainScaffold, PaywallGate
├── data/
│   ├── content/            # 7,200 vocab words, grammar patterns, theme sentences
│   ├── models/             # Word, GrammarPattern
│   └── repositories/       # WordRepository (singleton, fully cached)
└── features/
    ├── auth/               # Google Sign-In screen
    ├── chat/               # Dalli AI chat (SSE streaming)
    ├── grammar/            # Grammar pattern browser
    ├── hangeul/            # Hangeul tracing
    ├── home/               # Dashboard, level selector, sentence spotlight
    ├── learn/              # daily_session, sentence_card, quiz, review, practice
    ├── premium/            # RevenueCat paywall
    ├── pronunciation/      # Recording + scoring
    ├── settings/           # Notifications, account
    ├── themes/             # K-culture themed vocabulary packs
    └── word_network/       # Graph-based word relationship explorer
```

---

## Getting Started

### Prerequisites

- Flutter 3.x (`flutter --version`)
- Java 17 (for Android builds)
- Firebase project with `google-services.json` placed at `android/app/`
- `lib/firebase_options.dart` (generated via `flutterfire configure`)

### Install & Run

```bash
git clone https://github.com/yongal74/klexi-flutter.git
cd klexi-flutter
flutter pub get
flutter run
```

### Build Release AAB

```bash
# Requires android/key.properties with keystore credentials
flutter build appbundle --release
```

---

## Architecture Decisions

See [`C:/KlexiDev/docs/ADR/`](../docs/ADR/) for full Architecture Decision Records.

Key decisions:
- **ADR-001**: Riverpod for state management
- **ADR-002**: RevenueCat for in-app purchases
- **ADR-003**: Multi-tier TTS (CLOVA → Google → Device)
- **ADR-004**: SM-2 based SRS algorithm
- **ADR-005**: Firebase Auth + Google Sign-In
- **ADR-006**: Firebase Cloud Functions backend
- **ADR-007**: userTopikLevelProvider extracted to core/providers
- **ADR-008**: WordRepository singleton caching strategy

---

## CI/CD

GitHub Actions runs on every push to `master`/`main`/`develop`:

1. **analyze-and-test** — `flutter analyze --no-fatal-infos` + `flutter test --coverage`
2. **build-android** — Release AAB (master branch only)

Required repository secrets for release builds:
- `KEYSTORE_BASE64` — base64-encoded keystore file
- `KEY_PROPERTIES` — contents of `android/key.properties`

---

## Changelog

See [`C:/KlexiDev/docs/CHANGELOG.md`](../docs/CHANGELOG.md)

---

## Important Notes

- `android/keystore/klexi-release.jks` — **NEVER modify or delete**
- `lib/firebase_options.dart` — excluded from git (contains API keys)
- `android/key.properties` — excluded from git (signing credentials)
- RevenueCat entitlement ID must be exactly `'premium'` (case-sensitive)
- Hive box names must not change without user data migration
