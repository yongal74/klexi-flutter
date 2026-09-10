# ADR-001: State Management — flutter_riverpod

**Date:** 2026-03
**Status:** Accepted
**Deciders:** Klexi dev team

---

## Context

Klexi requires:
- Global state shared across feature screens (premium status, user level, today's study count)
- Async state for data loading (word sessions, purchase status)
- Dependency injection for services (TtsService, DailySessionService, etc.)
- Testable state without widget coupling

## Decision

Use **flutter_riverpod 2.x** as the single state management and DI solution.

**Patterns used:**

| Provider type | Use case |
|---|---|
| `Provider<T>` | Stateless services (WordRepository, TtsService, FcmService) |
| `StateNotifierProvider<N, T>` | Mutable global state (isPremiumProvider, userTopikLevelProvider) |
| `FutureProvider<T>` | One-shot async loads |
| `ref.read()` | Event handlers (button taps, lifecycle callbacks) |
| `ref.watch()` | Build-reactive bindings |

## Key Providers

```dart
// lib/core/providers/user_level_provider.dart
final userTopikLevelProvider = StateNotifierProvider<UserLevelNotifier, int>(...);

// lib/core/services/purchase_service.dart
final isPremiumProvider = StateNotifierProvider<PremiumNotifier, bool>(...);

// lib/core/services/daily_session_service.dart
final dailySessionServiceProvider = Provider<DailySessionService>(...);
final todayStudiedCountProvider = StateProvider<int>(...);

// lib/data/repositories/word_repository.dart
final wordRepositoryProvider = Provider<WordRepository>(...);
```

## Consequences

- **Positive**: Clear separation of state and UI; easy service injection in tests with `ProviderContainer`.
- **Positive**: `ConsumerStatefulWidget` / `ConsumerWidget` pattern is consistent across all screens.
- **Negative**: Riverpod 2.x has breaking changes from 1.x; upgrading to 3.x will require `@riverpod` code-gen migration.
- **Watch**: `StateNotifier` is soft-deprecated in Riverpod 3.x — future migration to `Notifier` / `AsyncNotifier`.
