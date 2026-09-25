import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/purchase_service.dart';
import '../../../core/widgets/google_sign_in_prompt.dart';

// ── 가격 정보 Provider — RevenueCat에서 실시간 로드 ──────────
final _offeringsProvider = FutureProvider<Offerings?>((ref) async {
  try {
    return await Purchases.getOfferings();
  } catch (e) {
    debugPrint('[Premium] Offerings 로드 실패: $e');
    return null;
  }
});

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _yearly = true;
  bool _loading = false;

  Future<void> _subscribe({required bool yearly}) async {
    // 게스트 결제는 AI 기능을 못 쓰고 기기 변경 시 구독도 잃는다 → 결제 전에 로그인
    final signedIn = await ensureGoogleSignIn(context, ref,
        reason:
            'Sign in before subscribing so your Premium works with AI features and stays with you on any device.');
    if (!signedIn || !mounted) return;
    setState(() => _loading = true);
    final plan = yearly ? 'yearly' : 'monthly';
    AnalyticsService.instance.logCheckoutStarted(plan: plan);
    try {
      final active = await PurchaseService.instance.purchase(yearly: yearly);
      if (active && mounted) {
        AnalyticsService.instance.logPremiumActivated(plan: plan);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Premium activated!')));
        Navigator.pop(context);
      }
    } catch (e, st) {
      AnalyticsService.instance.recordError(e, st, fatal: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Purchase couldn't be completed. You were not charged — please try again.")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    try {
      final ok = await PurchaseService.instance.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok
                ? 'Subscription restored!'
                : 'No active subscription found.')));
        if (ok) Navigator.pop(context);
      }
    } catch (e, st) {
      AnalyticsService.instance.recordError(e, st, fatal: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Couldn't restore purchases. Check your connection and try again.")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _retry() => ref.invalidate(_offeringsProvider);

  @override
  Widget build(BuildContext context) {
    final offeringsAsync = ref.watch(_offeringsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: offeringsAsync.when(
        loading: () => const _LoadingBody(),
        error: (_, __) =>
            _ErrorBody(onRetry: _retry, onRestore: _restore, loading: _loading),
        data: (offerings) {
          final monthly = offerings?.current?.monthly;
          final annual = offerings?.current?.annual;
          // 가격을 못 받으면 스피너를 영원히 돌리지 말고 재시도 화면을 보여준다
          if (monthly == null && annual == null) {
            return _ErrorBody(
                onRetry: _retry, onRestore: _restore, loading: _loading);
          }
          final plans = _PlanInfo.from(monthly: monthly, annual: annual);
          // 연간 상품이 없으면 월간으로 고정
          final yearly = _yearly && annual != null;
          return _Body(
            yearly: yearly,
            loading: _loading,
            plans: plans,
            onToggle: (v) => setState(() => _yearly = v),
            onSubscribe: () => _subscribe(yearly: yearly),
            onRestore: _restore,
          );
        },
      ),
    );
  }
}

/// 스토어 상품에서 실제 가격·무료체험·절약률을 계산한다.
/// 문구를 하드코딩하면 실제 상품 구성과 어긋날 때 허위 표시가 된다.
class _PlanInfo {
  final String? monthlyPrice;
  final String? yearlyPrice;
  final int? trialDays;
  final int? savePercent;

  const _PlanInfo(
      {this.monthlyPrice, this.yearlyPrice, this.trialDays, this.savePercent});

  factory _PlanInfo.from({Package? monthly, Package? annual}) {
    final m = monthly?.storeProduct;
    final y = annual?.storeProduct;
    int? save;
    if (m != null && y != null && m.price > 0) {
      final pct = ((1 - y.price / (m.price * 12)) * 100).round();
      if (pct > 0) save = pct;
    }
    return _PlanInfo(
      monthlyPrice: m?.priceString,
      yearlyPrice: y?.priceString,
      trialDays: y == null ? null : _trialDays(y),
      savePercent: save,
    );
  }

  static int? _trialDays(StoreProduct p) {
    final iso = p.defaultOption?.freePhase?.billingPeriod?.iso8601;
    if (iso != null) return _isoToDays(iso);
    final intro = p.introductoryPrice;
    if (intro != null && intro.price == 0) {
      return _isoToDays(intro.period);
    }
    return null;
  }

  /// "P7D" → 7, "P1W" → 7, "P1M" → 30
  static int? _isoToDays(String iso) {
    final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso);
    if (match == null) return null;
    final n = int.parse(match.group(1)!);
    switch (match.group(2)) {
      case 'D':
        return n;
      case 'W':
        return n * 7;
      case 'M':
        return n * 30;
      case 'Y':
        return n * 365;
    }
    return null;
  }
}

// ── 가격 로드 실패 바디 ─────────────────────────────────────
class _ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onRestore;
  final bool loading;
  const _ErrorBody(
      {required this.onRetry, required this.onRestore, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroSection(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x2l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 40, color: AppColors.textMuted),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    "Couldn't load prices",
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: loading ? null : onRestore,
                    child: const Text('Restore Purchases',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 로딩 바디 ─────────────────────────────────────────────
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroSection(),
        const Expanded(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

// ── 메인 바디 ─────────────────────────────────────────────
class _Body extends StatelessWidget {
  final bool yearly;
  final bool loading;
  final _PlanInfo plans;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSubscribe;
  final VoidCallback onRestore;

  const _Body({
    required this.yearly,
    required this.loading,
    required this.plans,
    required this.onToggle,
    required this.onSubscribe,
    required this.onRestore,
  });

  String? get monthlyPrice => plans.monthlyPrice;
  String? get yearlyPrice => plans.yearlyPrice;

  String get _yearlyHint {
    final parts = <String>[
      if (plans.savePercent != null) 'Save ${plans.savePercent}% vs monthly',
      if (plans.trialDays != null) '${plans.trialDays}-day free trial',
    ];
    return parts.join(' — ');
  }

  String get _ctaText {
    if (!yearly) return 'Subscribe Monthly · ${monthlyPrice ?? ''}/mo';
    if (plans.trialDays != null) {
      return 'Try Free for ${plans.trialDays} Days · then ${yearlyPrice ?? ''}/yr';
    }
    return 'Subscribe Yearly · ${yearlyPrice ?? ''}/yr';
  }

  Future<void> _open(String path) async {
    await launchUrl(Uri.parse('${AppConfig.backendUrl}$path'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroSection(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.x2l),

                // Feature list
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: const [
                      _Feature(
                          icon: '💬', text: 'Unlimited Dalli AI conversations'),
                      _Feature(icon: '📚', text: 'Full 7,200 TOPIK word bank'),
                      _Feature(
                          icon: '🎙️',
                          text: 'Pronunciation scoring & feedback'),
                      _Feature(
                          icon: '🕸️', text: 'Full Word Network exploration'),
                      _Feature(
                          icon: '🎭', text: 'Role-play & Grammar Coach modes'),
                      _Feature(icon: '📊', text: 'Advanced progress analytics'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Plan selector
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(children: [
                    if (monthlyPrice != null)
                      Expanded(
                          child: _PlanCard(
                        label: 'Monthly',
                        price: monthlyPrice,
                        period: '/month',
                        selected: !yearly,
                        badge: null,
                        onTap: () => onToggle(false),
                      )),
                    if (yearlyPrice != null) ...[
                      if (monthlyPrice != null)
                        const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: _PlanCard(
                        label: 'Yearly',
                        price: yearlyPrice,
                        period: '/year',
                        selected: yearly,
                        badge: 'Best Value',
                        onTap: () => onToggle(true),
                      )),
                    ],
                  ]),
                ),
                const SizedBox(height: AppSpacing.sm),

                if (yearly && _yearlyHint.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.savings_outlined,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(_yearlyHint,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),

                // Subscribe button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : onSubscribe,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_ctaText,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                TextButton(
                  onPressed: loading ? null : onRestore,
                  child: const Text('Restore Purchases',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  child: Text(
                      'Cancel anytime in Google Play. Subscription renews automatically unless canceled at least 24 hours before the end of the current period.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _open('/terms'),
                      child: const Text('Terms of Use',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const Text('·',
                        style: TextStyle(color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: () => _open('/privacy'),
                      child: const Text('Privacy Policy',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hero 섹션 ─────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.x2l, AppSpacing.lg, AppSpacing.x2l, AppSpacing.x2l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child:
                const Center(child: Text('✨', style: TextStyle(fontSize: 32))),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Unlock Full Klexi',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String icon;
  final String text;
  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151)))),
        ]),
      );
}

class _PlanCard extends StatelessWidget {
  final String label;
  final String? price;
  final String period;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.period,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.cardPad),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 26,
              child: badge != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Text(badge!,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            price == null
                ? const SizedBox(
                    height: 28,
                    child: Center(
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))))
                : SizedBox(
                    height: 32,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(price!,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                    ),
                  ),
            Text(period,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
