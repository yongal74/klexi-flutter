// lib/core/services/purchase_service.dart
// RevenueCat 인앱결제 서비스

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../constants/app_config.dart';

// ── State Notifier ────────────────────────────────────────────────────────────

class PremiumNotifier extends StateNotifier<bool> {
  PremiumNotifier() : super(false);

  void setPremium(bool value) => state = value;
  bool get isPremium => state;
}

final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>(
  (ref) => PremiumNotifier(),
);

final isPremiumProvider = Provider<bool>((ref) => ref.watch(premiumProvider));

// ── Service ───────────────────────────────────────────────────────────────────

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  late PremiumNotifier _notifier;

  void attachNotifier(PremiumNotifier notifier) {
    _notifier = notifier;
  }

  Future<void> initialize() async {
    await Purchases.configure(
      PurchasesConfiguration(AppConfig.revenueCatApiKey),
    );

    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      final active = customerInfo.entitlements.active.containsKey('premium');
      _notifier.setPremium(active);
    });

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final active = customerInfo.entitlements.active.containsKey('premium');
      _notifier.setPremium(active);
    } catch (e) {
      debugPrint('RevenueCat init error: $e');
    }
  }

  Future<bool> purchase({required bool yearly}) async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) throw Exception('No offerings available');

      final targetType = yearly ? PackageType.annual : PackageType.monthly;
      Package? pkg;
      for (final p in current.availablePackages) {
        if (p.packageType == targetType) {
          pkg = p;
          break;
        }
      }
      if (pkg == null) throw Exception('Package not found');

      // ignore: deprecated_member_use
      final result = await Purchases.purchasePackage(pkg);
      final active = result.customerInfo.entitlements.active.containsKey('premium');
      _notifier.setPremium(active);
      return active;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final active = customerInfo.entitlements.active.containsKey('premium');
      _notifier.setPremium(active);
      return active;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }
}

final purchaseServiceProvider = Provider<PurchaseService>(
  (_) => PurchaseService.instance,
);
