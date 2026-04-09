import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/purchase_service.dart';

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

  Future<void> _subscribe(Offerings? offerings) async {
    setState(() => _loading = true);
    AnalyticsService.instance.logCheckoutStarted(plan: _yearly ? 'yearly' : 'monthly');
    try {
      final active = await PurchaseService.instance.purchase(yearly: _yearly);
      if (active && mounted) {
        AnalyticsService.instance.logPremiumActivated(plan: _yearly ? 'yearly' : 'monthly');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium activated!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')));
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
          content: Text(ok ? 'Subscription restored!' : 'No active subscription found.')));
        if (ok) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // RevenueCat Package에서 현지화된 가격 문자열 추출
  String _priceOf(Package? pkg) {
    if (pkg == null) return '—';
    return pkg.storeProduct.priceString;
  }

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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: offeringsAsync.when(
        loading: () => const _LoadingBody(),
        error: (_, __) => _Body(
          yearly: _yearly,
          loading: _loading,
          monthlyPrice: null,
          yearlyPrice: null,
          onToggle: (v) => setState(() => _yearly = v),
          onSubscribe: () => _subscribe(null),
          onRestore: _restore,
        ),
        data: (offerings) {
          final monthly = offerings?.current?.monthly;
          final annual = offerings?.current?.annual;
          return _Body(
            yearly: _yearly,
            loading: _loading,
            monthlyPrice: _priceOf(monthly),
            yearlyPrice: _priceOf(annual),
            onToggle: (v) => setState(() => _yearly = v),
            onSubscribe: () => _subscribe(offerings),
            onRestore: _restore,
          );
        },
      ),
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
  final String? monthlyPrice;
  final String? yearlyPrice;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSubscribe;
  final VoidCallback onRestore;

  const _Body({
    required this.yearly,
    required this.loading,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.onToggle,
    required this.onSubscribe,
    required this.onRestore,
  });

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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: const [
                      _Feature(icon: '💬', text: 'Unlimited Dalli AI conversations'),
                      _Feature(icon: '📚', text: 'Full 7,200 TOPIK word bank'),
                      _Feature(icon: '🎙️', text: 'Pronunciation scoring & feedback'),
                      _Feature(icon: '🕸️', text: 'Full Word Network exploration'),
                      _Feature(icon: '🎭', text: 'Role-play & Grammar Coach modes'),
                      _Feature(icon: '📊', text: 'Advanced progress analytics'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Plan selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(children: [
                    Expanded(child: _PlanCard(
                      label: 'Monthly',
                      price: monthlyPrice,
                      period: '/month',
                      selected: !yearly,
                      badge: null,
                      onTap: () => onToggle(false),
                    )),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _PlanCard(
                      label: 'Yearly',
                      price: yearlyPrice,
                      period: '/year',
                      selected: yearly,
                      badge: 'Best Value',
                      onTap: () => onToggle(true),
                    )),
                  ]),
                ),
                const SizedBox(height: AppSpacing.sm),

                if (yearly)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.savings_outlined, size: 16, color: AppColors.success),
                          SizedBox(width: 8),
                          Text('Save 48% vs monthly — 7-day free trial',
                            style: TextStyle(
                              fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),

                // Subscribe button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              yearly
                                ? 'Try Free for 7 Days · then ${yearlyPrice ?? '…'}/yr'
                                : 'Subscribe Monthly · ${monthlyPrice ?? '…'}/mo',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                TextButton(
                  onPressed: loading ? null : onRestore,
                  child: const Text('Restore Purchases',
                    style: TextStyle(color: AppColors.textSecondary)),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: const Text(
                    'Cancel anytime. Subscription automatically renews unless canceled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 32))),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Unlock Full Klexi',
            style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800,
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
      Expanded(child: Text(text, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w500,
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
          color: selected ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Text(badge!, style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            price == null
                ? const SizedBox(
                    height: 28,
                    child: Center(
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))))
                : Text(price!, style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(period, style: const TextStyle(
              fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
