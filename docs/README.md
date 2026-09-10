# Klexi — Documentation Index

## Architecture Decision Records (ADR)

| # | Title | Status | Date |
|---|---|---|---|
| [ADR-001](ADR/ADR-001-state-management-riverpod.md) | State Management — flutter_riverpod | Accepted | 2026-03 |
| [ADR-002](ADR/ADR-002-payment-revenuecat.md) | In-App Purchase — RevenueCat | Accepted | 2026-03 |
| [ADR-003](ADR/ADR-003-tts-architecture.md) | TTS Architecture — Multi-Tier Fallback | Accepted | 2026-03 |
| [ADR-004](ADR/ADR-004-srs-algorithm.md) | Spaced Repetition — Fixed Interval Ladder (SM-2 아님) | Accepted (2026-09-10 정정) | 2026-03 |
| [ADR-005](ADR/ADR-005-auth-flow.md) | Authentication — Firebase + Google Sign-In | Accepted | 2026-03 |
| [ADR-006](ADR/ADR-006-backend-firebase-functions.md) | Backend — Firebase Cloud Functions | Accepted | 2026-03 |
| [ADR-007](ADR/ADR-007-provider-extraction.md) | Extract userTopikLevelProvider to core | Accepted | 2026-04-11 |
| [ADR-008](ADR/ADR-008-word-repository-caching.md) | WordRepository Singleton Caching | Accepted | 2026-04-11 |
| [ADR-009](ADR/ADR-009-backend-auth-id-token.md) | Backend Auth — Firebase ID Token on Paid Routes | Accepted | 2026-09-10 |
| [ADR-010](ADR/ADR-010-study-data-per-uid.md) | Study Records Scoped per Firebase UID | Accepted | 2026-09-10 |

## Changelog

- [CHANGELOG.md](CHANGELOG.md) — Full build history with fixes per version

## 규칙

- 이 폴더가 프로젝트 문서의 **단일 원본**이다(build53 이전에는 저장소 밖 `KlexiDev/docs/` 에만 있었다).
- 주요 기술 선택·아키텍처 변경 시 ADR 을 추가한다. 번호는 이어서 매긴다.
- 기존 ADR 의 내용이 코드와 다르면 **삭제하지 말고 정정판으로 갱신**하고, 무엇이 왜 틀렸는지 남긴다.
