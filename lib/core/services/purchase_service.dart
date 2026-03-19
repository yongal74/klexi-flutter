import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── API Keys ────────────────────────────────────────────────────────────────
// TODO: Replace with your actual RevenueCat API keys from the dashboard.
// Android key: https://app.revenuecat.com → Project → Apps → Android
// iOS key:     https://app.revenuecat.com → Project → Apps → iOS
const String _kAndroidApiKey = 'YOUR_REVENUECAT_ANDROID_KEY';
const String _kIosApiKey     = 'YOUR_REVENUECAT_IOS_KEY';

// Product IDs — must match App Store Connect / Play Console and RevenueCat
// TODO: These are referenced when you uncomment the RevenueCat purchasePackage call above.
// ignore: unused_element
const String _kMonthlyId = 'klexi_premium_monthly';
// ignore: unused_element
const String _kYearlyId  = 'klexi_premium_yearly';

// Entitlement ID — set in RevenueCat dashboard → Entitlements → "premium"
const String _kEntitlement = 'premium';

const String _kPrefKey = 'klexi_is_premium';

// ── State Notifier ──────────────────────────────────────────────────────────

class PremiumNotifier extends StateNotifier<bool> {
  PremiumNotifier() : super(false);

  void setPremium(bool value) => state = value;
  bool get isPremium => state;
}

final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>(
  (ref) => PremiumNotifier(),
);

/// Convenience alias — watch this to gate UI on premium status.
/// Usage: `final isPro = ref.watch(isPremiumProvider);`
final isPremiumProvider = Provider<bool>((ref) => ref.watch(premiumProvider));

// ── Service ─────────────────────────────────────────────────────────────────

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  // Riverpod notifier injected after initialization so the service can update state
  late PremiumNotifier _notifier;

  bool _ready = false;

  void attachNotifier(PremiumNotifier notifier) {
    _notifier = notifier;
  }

  /// Call once in main() before runApp.
  Future<void> initialize() async {
    // Load cached premium status immediately so gating works before network
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool(_kPrefKey) ?? false;
    _ready = true;

    if (cached) _notifier.setPremium(true);

    try {
      await Purchases.setLogLevel(LogLevel.error);
      final apiKey = Platform.isAndroid ? _kAndroidApiKey : _kIosApiKey;

      // Skip if placeholder key — RevenueCat will reject 'YOUR_*' keys
      if (apiKey.startsWith('YOUR_')) return;

      final config = PurchasesConfiguration(apiKey);
      await Purchases.configure(config);

      final info = await Purchases.getCustomerInfo();
      final active = info.entitlements.active.containsKey(_kEntitlement);
      await _persist(active);
    } catch (_) {
      // Network failure — use cached value; not fatal
    }
  }

  Future<bool> purchasePremium({required bool yearly}) async {
    try {
      final apiKey = Platform.isAndroid ? _kAndroidApiKey : _kIosApiKey;
      if (apiKey.startsWith('YOUR_')) {
        // Dev mode: grant premium without real payment
        await _persist(true);
        return true;
      }

      final offerings = await Purchases.getOfferings();
      final package = yearly
          ? offerings.current?.annual
          : offerings.current?.monthly;
      if (package == null) throw Exception('Package not found in RevenueCat');
      final info = await Purchases.purchasePackage(package);
      final active = info.entitlements.active.containsKey(_kEntitlement);
      await _persist(active);
      return active;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final apiKey = Platform.isAndroid ? _kAndroidApiKey : _kIosApiKey;
      if (apiKey.startsWith('YOUR_')) return _notifier.isPremium;

      final info = await Purchases.restorePurchases();
      final active = info.entitlements.active.containsKey(_kEntitlement);
      await _persist(active);
      return active;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> checkStatus() async {
    try {
      final apiKey = Platform.isAndroid ? _kAndroidApiKey : _kIosApiKey;
      if (apiKey.startsWith('YOUR_')) return;
      final info = await Purchases.getCustomerInfo();
      final active = info.entitlements.active.containsKey(_kEntitlement);
      await _persist(active);
    } catch (_) {}
  }

  Future<void> _persist(bool value) async {
    _notifier.setPremium(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, value);
  }

  bool get isReady => _ready;
}

final purchaseServiceProvider = Provider<PurchaseService>(
  (_) => PurchaseService.instance,
);
