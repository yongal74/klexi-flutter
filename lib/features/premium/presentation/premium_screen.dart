import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/purchase_service.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _yearly = true;
  bool _loading = false;

  Future<void> _subscribe() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(purchaseServiceProvider);
      await svc.purchasePremium(yearly: _yearly);
      if (mounted) Navigator.pop(context);
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
      final svc = ref.read(purchaseServiceProvider);
      await svc.restorePurchases();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero gradient
            Container(
              height: 280,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x2l),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('✨', style: TextStyle(fontSize: 36))),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Text('Unlock Full Klexi',
                        style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('Unlimited words, AI chat, and more',
                        style: TextStyle(
                          fontSize: 16, color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
              ),
            ),
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
            const SizedBox(height: AppSpacing.x2l),

            // Plan selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(children: [
                Expanded(child: _PlanCard(
                  label: 'Monthly',
                  price: '\$4.99',
                  period: '/month',
                  selected: !_yearly,
                  badge: null,
                  onTap: () => setState(() => _yearly = false),
                )),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _PlanCard(
                  label: 'Yearly',
                  price: '\$29.99',
                  period: '/year',
                  selected: _yearly,
                  badge: 'Best Value',
                  onTap: () => setState(() => _yearly = true),
                )),
              ]),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (_yearly)
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
                      Text('Save 50% vs monthly — 7-day free trial',
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
              child: ElevatedButton(
                onPressed: _loading ? null : _subscribe,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_yearly ? 'Start Free Trial' : 'Subscribe Monthly',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            TextButton(
              onPressed: _loading ? null : _restore,
              child: const Text('Restore Purchases',
                style: TextStyle(color: AppColors.textSecondary)),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Cancel anytime. Subscription automatically renews unless canceled.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
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
      Text(text, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
    ]),
  );
}

class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String period;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label, required this.price, required this.period,
    required this.selected, required this.badge, required this.onTap,
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
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(badge!, style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            if (badge != null) const SizedBox(height: 8),
            Text(label, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(price, style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(period, style: const TextStyle(
              fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
