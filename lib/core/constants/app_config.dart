// lib/core/constants/app_config.dart

class AppConfig {
  AppConfig._();

  // ── 백엔드 URL ────────────────────────────────────────────────────────────
  static const String backendUrl = 'https://klexi-30ab5.web.app';

  // ── RevenueCat API Key ────────────────────────────────────────────────────
  static const String revenueCatApiKey = 'goog_BGlWjxuopFQTSNIxAFkAIFrmZXO';

  // ── 설정 여부 확인 ────────────────────────────────────────────────────────
  static bool get isBackendConfigured => true;

  // ── 날짜 시드 (오늘 기준) ─────────────────────────────────────────────────
  static const int msPerDay = 86400000;
  static int get daySeed => DateTime.now().millisecondsSinceEpoch ~/ msPerDay;
}
