# ADR-005: Authentication — Firebase Auth + Google Sign-In

**Date:** 2026-03
**Status:** Accepted
**Deciders:** Klexi dev team

---

## Context

Klexi needs authentication to:
- Persist study records across devices (future)
- Gate premium features per user
- Support frictionless onboarding (no forced sign-up)

## Decision

Use **Firebase Auth** with **Google Sign-In** as the primary authentication method, with **guest mode** as the default entry point.

### Auth Flow

```
App Launch
    │
    ├── No account → Guest Mode
    │       │
    │       └── Study data saved locally (Hive: 'study_records_guest_{uuid}')
    │
    └── Has account → Firebase Auth session restored
            │
            └── Study data saved locally (Hive: 'study_records_{userId}')

Guest → Google Sign-In:
    1. GoogleSignIn().signIn()
    2. FirebaseAuth.signInWithCredential(googleCredential)
    3. _migrateHiveData(guestId, userId)  ← preserves all SRS history
```

### Implementation

```dart
// lib/core/services/auth_service.dart
class AuthService {
  Future<void> signInWithGoogle() async { ... }
  Future<void> signOut() async { ... }
  Future<void> _migrateHiveData(String fromId, String toId) async { ... }
}
```

### Why No Email/Password?

- Google Sign-In covers the majority of Android users
- Reduces friction (one tap vs. form fill)
- Firebase handles token refresh, security

## Consequences

- **Positive**: Zero-friction onboarding; users can try before signing in.
- **Positive**: Guest → signed-in migration preserves all study progress.
- **Negative**: Only Google Sign-In supported (no Apple Sign-In yet — needed for iOS App Store).
- **Watch**: iOS launch will require Apple Sign-In implementation (App Store requirement when Google Sign-In is offered).
