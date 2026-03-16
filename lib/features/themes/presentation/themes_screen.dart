import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';

class _ThemePack {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final int wordCount;
  final Color color;

  const _ThemePack({
    required this.id, required this.name, required this.emoji,
    required this.description, required this.wordCount, required this.color,
  });
}

const _packs = [
  _ThemePack(id: 'kdrama',  name: 'K-Drama',  emoji: '🎬', description: 'Emotional dialogues and K-drama vocabulary', wordCount: 600, color: Color(0xFF9C27B0)),
  _ThemePack(id: 'kpop',   name: 'K-Pop',    emoji: '🎵', description: 'Fan culture, lyrics, and idol vocabulary',   wordCount: 600, color: Color(0xFFE91E63)),
  _ThemePack(id: 'kfood',  name: 'K-Food',   emoji: '🍜', description: 'Korean cuisine, restaurants, and cooking',  wordCount: 600, color: Color(0xFFFF5722)),
  _ThemePack(id: 'manners',name: 'Manners',  emoji: '🙇', description: 'Formal speech, greetings, and honorifics',  wordCount: 600, color: Color(0xFF2196F3)),
  _ThemePack(id: 'slang',  name: 'Slang',   emoji: '😎', description: 'Internet speak, youth language, casual talk', wordCount: 600, color: Color(0xFF4CAF50)),
  _ThemePack(id: 'travel', name: 'Travel',   emoji: '✈️', description: 'Airport, hotels, directions, and tourism',   wordCount: 600, color: Color(0xFF00BCD4)),
];

class ThemesScreen extends ConsumerWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Theme Vocabulary'),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: Text('3,600 words across 6 themes',
              style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.listGap,
                mainAxisSpacing: AppSpacing.listGap,
                childAspectRatio: 0.9,
              ),
              itemCount: _packs.length,
              itemBuilder: (_, i) => _ThemeCard(
                pack: _packs[i],
                onTap: () => context.push(
                  AppRoutes.themeDetail.replaceFirst(':id', _packs[i].id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final _ThemePack pack;
  final VoidCallback onTap;
  const _ThemeCard({required this.pack, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: pack.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Center(
                child: Text(pack.emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(pack.name,
              style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(pack.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
            const Spacer(),
            Row(
              children: [
                Text('${pack.wordCount} words',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: pack.color)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 12, color: pack.color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
