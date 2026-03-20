// lib/core/constants/app_config.dart
// ─────────────────────────────────────────────────────────────────────────────
// ⚠️  이 파일을 직접 수정하세요 (Polar 대시보드 → Products에서 ID 확인)
// ─────────────────────────────────────────────────────────────────────────────

class AppConfig {
  AppConfig._();

  // ── 백엔드 URL ────────────────────────────────────────────────────────────
  // klexi-auth Replit 배포 URL (끝에 / 없음)
  static const String backendUrl = 'YOUR_BACKEND_URL_HERE';
  // 예시: 'https://klexi-auth.yourname.repl.co'

  // ── Polar 상품 ID ─────────────────────────────────────────────────────────
  // Polar 대시보드 → Products → 각 상품의 ID 복사
  static const String polarMonthlyProductId = 'YOUR_POLAR_MONTHLY_PRODUCT_ID';
  static const String polarYearlyProductId  = 'YOUR_POLAR_YEARLY_PRODUCT_ID';

  // ── 웹앱 URL (수정 불필요) ─────────────────────────────────────────────────
  static const String webAppUrl = 'https://klexi-30ab5.web.app';
  static String get premiumSuccessUrl => '$webAppUrl/#/premium-success';

  // ── 설정 여부 확인 ────────────────────────────────────────────────────────
  static bool get isBackendConfigured => !backendUrl.startsWith('YOUR_');
  static bool get isPolarConfigured   =>
      !polarMonthlyProductId.startsWith('YOUR_') &&
      !polarYearlyProductId.startsWith('YOUR_');
}
