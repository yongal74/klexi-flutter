import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat 인앱 결제 서비스
/// 실제 사용 전에:
///   1. pubspec.yaml에 purchases_flutter: ^8.7.4 추가
///   2. RevenueCat 대시보드에서 API 키 생성
///   3. 아래 _apiKey에 실제 키 입력
///   4. App Store Connect / Play Console에서 상품 생성

class PurchaseService {
  static const String _androidApiKey = 'your_revenuecat_android_key';
  static const String _iosApiKey     = 'your_revenuecat_ios_key';

  // Product IDs (must match RevenueCat dashboard)
  static const String monthlyId = 'klexi_premium_monthly';
  static const String yearlyId  = 'klexi_premium_yearly';

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void> initialize() async {
    // await Purchases.setLogLevel(LogLevel.debug);
    // final config = PurchasesConfiguration(
    //   Platform.isAndroid ? _androidApiKey : _iosApiKey,
    // );
    // await Purchases.configure(config);
    // final customerInfo = await Purchases.getCustomerInfo();
    // _isPremium = customerInfo.entitlements.active.isNotEmpty;
  }

  Future<bool> purchasePremium({required bool yearly}) async {
    try {
      // final offerings = await Purchases.getOfferings();
      // final package = yearly
      //     ? offerings.current?.annual
      //     : offerings.current?.monthly;
      // if (package == null) throw Exception('Package not found');
      // final customerInfo = await Purchases.purchasePackage(package);
      // _isPremium = customerInfo.entitlements.active.isNotEmpty;
      // return _isPremium;
      _isPremium = true; // Mock for now
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      // final customerInfo = await Purchases.restorePurchases();
      // _isPremium = customerInfo.entitlements.active.isNotEmpty;
      // return _isPremium;
      return _isPremium;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> checkStatus() async {
    // final customerInfo = await Purchases.getCustomerInfo();
    // _isPremium = customerInfo.entitlements.active.isNotEmpty;
  }
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService();
});

final isPremiumProvider = StateProvider<bool>((ref) => false);
