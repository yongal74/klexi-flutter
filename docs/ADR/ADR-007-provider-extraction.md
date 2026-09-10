# ADR-007: Extract userTopikLevelProvider to core/providers

**Date:** 2026-04-11 (build48)
**Status:** Accepted
**Deciders:** Klexi dev team

---

## Context

`userTopikLevelProvider` was defined inside `lib/features/home/presentation/home_screen.dart`. Three other feature files needed it:

- `lib/features/chat/presentation/dalli_chat_screen.dart`
- `lib/features/learn/presentation/daily_session_screen.dart`
- `lib/features/learn/presentation/sentence_card_screen.dart`

These files imported it via:
```dart
import '../../home/presentation/home_screen.dart' show userTopikLevelProvider;
```

This creates a **cross-feature dependency** — `learn` and `chat` features depending on the `home` feature's presentation layer. This violates feature isolation and makes the dependency graph confusing.

## Decision

Extract `userTopikLevelProvider` and `UserLevelNotifier` to:
```
lib/core/providers/user_level_provider.dart
```

`home_screen.dart` re-exports it for backward compatibility:
```dart
export '../../../core/providers/user_level_provider.dart' show userTopikLevelProvider;
```

All 3 callers updated to import directly from core:
```dart
import '../../../core/providers/user_level_provider.dart';
```

### Class visibility change

`_UserLevelNotifier` (private) → `UserLevelNotifier` (public), since it now lives in its own file and may be needed externally (e.g., tests).

## Consequences

- **Positive**: `learn`, `chat` features no longer depend on `home` presentation layer.
- **Positive**: `userTopikLevelProvider` is now a proper shared-state primitive in `core/`.
- **Positive**: Easier to test `UserLevelNotifier` in isolation.
- **Neutral**: `home_screen.dart` export line retained — callers that still import via `home_screen.dart` continue to work.
