import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/content/grammar/grammar_data.dart';
import '../../../data/models/grammar_pattern.dart';

class GrammarDetailScreen extends ConsumerWidget {
  final String patternId;
  const GrammarDetailScreen({super.key, required this.patternId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pattern = kGrammarData.firstWhere(
      (g) => g.id == patternId,
      orElse: () => kGrammarData.first,
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(pattern.title,
          style: const TextStyle(fontFamily: 'NotoSansKR')),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.cardPadLg),
              decoration: BoxDecoration(
                gradient: AppColors.levelGradient(pattern.level),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Text('TOPIK ${pattern.level}',
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(pattern.title,
                    style: const TextStyle(
                      fontFamily: 'NotoSansKR',
                      fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(pattern.meaning,
                    style: TextStyle(
                      fontSize: 16, color: Colors.white.withOpacity(0.85), height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Usage / Structure
            if (pattern.structure.isNotEmpty)
              _InfoCard(
                title: 'How to Use',
                child: Text(pattern.structure,
                  style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary, height: 1.6)),
              ),
            const SizedBox(height: AppSpacing.listGap),

            // Examples
            _InfoCard(
              title: 'Examples (${pattern.examples.length})',
              child: Column(
                children: pattern.examples.asMap().entries.map((e) {
                  final idx = e.key;
                  final ex = e.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (idx > 0) ...[
                        Divider(color: AppColors.border, height: AppSpacing.x2l),
                      ],
                      Text(ex.korean,
                        style: const TextStyle(
                          fontFamily: 'NotoSansKR',
                          fontSize: 18, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary, height: 1.7)),
                      const SizedBox(height: 4),
                      Text(ex.english,
                        style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.cardPad),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.subtleShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}
