// lib/core/widgets/paywall_gate.dart
// Reusable paywall gate — wraps any screen to enforce premium access.
//
// Usage:
//   PaywallGate(child: MyPremiumScreen())
//
// If the user is free, shows an upgrade prompt instead of [child].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../router/app_router.dart';
import '../services/polar_service.dart';

class PaywallGate extends ConsumerWidget {
  final Widget child;
  final String? featureName;
  final String? featureDescription;

  const PaywallGate({
    super.key,
    required this.child,
    this.featureName,
    this.featureDescription,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium) return child;
    return _PaywallPlaceholder(
      featureName: featureName,
      featureDescription: featureDescription,
    );
  }
}

class _PaywallPlaceholder extends StatelessWidget {
  final String? featureName;
  final String? featureDescription;
  const _PaywallPlaceholder({this.featureName, this.featureDescription});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(featureName ?? 'Pro Feature'),
        backgroundColor: AppColors.surface,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                    child: Icon(Icons.lock_rounded,
                        color: Colors.white, size: 36)),
              ),
              const SizedBox(height: 24),
              Text(
                featureName != null
                    ? 'Unlock $featureName'
                    : 'Klexi Pro Required',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                featureDescription ??
                    'Upgrade to Klexi Pro to access all features including levels 2–6, AI chat, pronunciation analysis, and the full Word Network.',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push(AppRoutes.premium),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Upgrade to Pro',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
