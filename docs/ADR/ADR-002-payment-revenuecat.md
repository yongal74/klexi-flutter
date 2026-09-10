# ADR-002: In-App Purchase — RevenueCat

**Date:** 2026-03 (migrated from Polar)
**Status:** Accepted
**Deciders:** Klexi dev team

---

## Context

Klexi needs a premium subscription system with:
- Monthly and annual plans
- Free trial (7 days for annual)
- Cross-platform receipt validation
- Entitlement management without server-side logic

Previous system (Polar) was a web-based payment link — not a native in-app purchase, which violated Google Play policies for digital goods.

## Decision

Use **RevenueCat** (`purchases_flutter 9.x`) for all in-app purchase management.

**Configuration:**
```dart
// lib/core/constants/app_config.dart
static const String revenueCatApiKey = 'goog_BGlWjxuopFQTSNIxAFkAIFrmZXO';

// Entitlement ID (MUST match RevenueCat dashboard exactly)
const String _premiumEntitlement = 'premium';
```

**Plans:**
- `PackageType.monthly` — monthly subscription
- `PackageType.annual` — annual subscription with 7-day free trial

**State:**
```dart
// PremiumNotifier checks entitlements on app start + after purchase
final isPremiumProvider = StateNotifierProvider<PremiumNotifier, bool>(...);

// Convenience alias
final premiumProvider = isPremiumProvider;
```

**Paywall protection:**
- `PaywallGate` widget wraps premium routes in `app_router.dart`
- Inline paywall prompt in `LearnScreen` for locked levels

## Migration from Polar

- `polar_service.dart` retained as a re-export shim for one release cycle (build46)
- Fully removed by build47 — all imports updated to `purchase_service.dart`

## Consequences

- **Positive**: Native IAP flow; Google Play policy compliant; handles receipt validation server-side.
- **Positive**: RevenueCat dashboard provides subscriber analytics without custom backend.
- **Negative**: RevenueCat SDK adds ~2MB to APK size.
- **Watch**: Entitlement name `'premium'` is case-sensitive — must match dashboard exactly.
