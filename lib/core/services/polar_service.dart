// lib/core/services/polar_service.dart
// Polar 결제 서비스 — RevenueCat 대체
// 결제 흐름: 백엔드 → Polar checkout URL → 브라우저 → 결제 → 앱으로 복귀 → 검증

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_config.dart';

const String _kPrefKey = 'klexi_is_premium';
const String _kSubIdKey = 'klexi_subscription_id';

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

// ── Result types ──────────────────────────────────────────────────────────────

class CheckoutResult {
  final String checkoutUrl;
  final String checkoutId;
  CheckoutResult({required this.checkoutUrl, required this.checkoutId});
}

// ── Service ───────────────────────────────────────────────────────────────────

class PolarService {
  PolarService._();
  static final PolarService instance = PolarService._();

  late PremiumNotifier _notifier;
  bool _ready = false;

  void attachNotifier(PremiumNotifier notifier) {
    _notifier = notifier;
  }

  /// main()에서 runApp() 전에 호출
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool(_kPrefKey) ?? false;
    _ready = true;

    if (cached) {
      _notifier.setPremium(true);
      // 백그라운드에서 구독 검증 (캐시 무효화 방지)
      _verifyInBackground(prefs);
    }
  }

  void _verifyInBackground(SharedPreferences prefs) async {
    try {
      if (!AppConfig.isBackendConfigured) return;
      final subId = prefs.getString(_kSubIdKey);
      if (subId == null) return;

      final uri = Uri.parse('${AppConfig.backendUrl}/api/polar/subscription/$subId');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final sub = data['subscription'] as Map<String, dynamic>?;
        final status = sub?['status'] as String? ?? '';
        final active = status == 'active';
        await _persist(active);
      }
    } catch (_) {
      // 네트워크 실패 — 캐시 유지
    }
  }

  /// Polar checkout 세션 생성
  Future<CheckoutResult> createCheckout({
    required bool yearly,
    required String customerEmail,
  }) async {
    if (!AppConfig.isBackendConfigured || !AppConfig.isPolarConfigured) {
      // 개발 모드: 실제 결제 없이 프리미엄 부여
      debugPrint('⚠️ Polar not configured — granting dev premium');
      await _persist(true);
      throw const _DevModeException();
    }

    final productId = yearly
        ? AppConfig.polarYearlyProductId
        : AppConfig.polarMonthlyProductId;

    final uri = Uri.parse('${AppConfig.backendUrl}/api/polar/checkout');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'productId': productId,
        'customerEmail': customerEmail,
        'successUrl': AppConfig.premiumSuccessUrl,
        'metadata': {'plan': yearly ? 'yearly' : 'monthly'},
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Checkout 생성 실패: ${res.statusCode}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    return CheckoutResult(
      checkoutUrl: data['checkoutUrl'] as String,
      checkoutId: data['checkoutId'] as String,
    );
  }

  /// Polar checkout URL을 브라우저에서 열기
  Future<void> openCheckout(String checkoutUrl) async {
    final uri = Uri.parse(checkoutUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('결제 페이지를 열 수 없습니다');
    }
  }

  /// 이메일로 구독 상태 확인 (결제 완료 후 호출)
  Future<bool> verifyByEmail(String email) async {
    if (!AppConfig.isBackendConfigured) {
      return _notifier.isPremium;
    }

    try {
      final uri = Uri.parse(
        '${AppConfig.backendUrl}/api/polar/verify?email=${Uri.encodeComponent(email)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final active = data['active'] as bool? ?? false;
        final subId = data['subscriptionId'] as String?;

        if (subId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kSubIdKey, subId);
        }

        await _persist(active);
        return active;
      }
    } catch (e) {
      debugPrint('Verify error: $e');
    }
    return false;
  }

  /// 구독 취소
  Future<void> cancelSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subId = prefs.getString(_kSubIdKey);
      if (subId == null || !AppConfig.isBackendConfigured) return;

      await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/polar/subscription/$subId/cancel'),
      ).timeout(const Duration(seconds: 10));

      // 즉시 해제하지 않음 — 기간 만료 시 자동 해제
    } catch (e) {
      debugPrint('Cancel error: $e');
    }
  }

  Future<void> _persist(bool value) async {
    _notifier.setPremium(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, value);
  }

  bool get isReady => _ready;
}

class _DevModeException implements Exception {
  const _DevModeException();
}

final purchaseServiceProvider = Provider<PolarService>(
  (_) => PolarService.instance,
);
