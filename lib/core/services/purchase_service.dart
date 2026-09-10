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

  PremiumNotifier? _notifier;

  void attachNotifier(PremiumNotifier notifier) {
    _notifier = notifier;
  }

  void _setPremium(bool value) => _notifier?.setPremium(value);

  Future<void> initialize() async {
    await Purchases.configure(
      PurchasesConfiguration(AppConfig.revenueCatApiKey),
    );

    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      final active = customerInfo.entitlements.active.containsKey('premium');
      _setPremium(active);
    });

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final active = customerInfo.entitlements.active.containsKey('premium');
      _setPremium(active);
    } on Exception catch (e) {
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
      final active =
          result.customerInfo.entitlements.active.containsKey('premium');
      _setPremium(active);
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
      _setPremium(active);
      return active;
    } on Exception catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }

  /// 로그인한 사용자를 RevenueCat 에 연결한다. 이걸 호출해야 구독이
  /// 기기가 아니라 계정에 묶이고, 로그아웃 시 엔타이틀먼트가 따라 내려간다.
  Future<void> logIn(String uid) async {
    try {
      final result = await Purchases.logIn(uid);
      _setPremium(
        result.customerInfo.entitlements.active.containsKey('premium'),
      );
    } on Exception catch (e) {
      debugPrint('RevenueCat logIn error: $e');
    }
  }

  /// 로그아웃/계정삭제 시 호출. 실패해도 로컬 프리미엄 상태는 반드시 내린다.
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } on Exception catch (e) {
      debugPrint('RevenueCat logOut error: $e');
    } finally {
      _setPremium(false);
    }
  }
}

final purchaseServiceProvider = Provider<PurchaseService>(
  (_) => PurchaseService.instance,
);
