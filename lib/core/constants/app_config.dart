// lib/core/constants/app_config.dart

class AppConfig {
  AppConfig._();

  // ── 백엔드 URL ────────────────────────────────────────────────────────────
  static const String backendUrl = 'https://klexi-30ab5.web.app';

  // ── RevenueCat API Key ────────────────────────────────────────────────────
  static const String revenueCatApiKey = 'goog_BGlWjxuopFQTSNIxAFkAIFrmZXO';

  // ── 설정 여부 확인 ────────────────────────────────────────────────────────
  static bool get isBackendConfigured => true;
}
