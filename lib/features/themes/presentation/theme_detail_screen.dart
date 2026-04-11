import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../data/content/themes/themes_index.dart';

class ThemeDetailScreen extends ConsumerStatefulWidget {
  final String themeId;
  const ThemeDetailScreen({super.key, required this.themeId});
  @override
  ConsumerState<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends ConsumerState<ThemeDetailScreen> {
  int _level = 0;

  List<ThemeWord> get _all => getThemeWords(widget.themeId);
  List<ThemeWord> get _filtered => _level == 0
      ? _all
      : _all.where((w) => w.level == _level).toList();

  String get _name {
    const names = {
      'kdrama': 'K-Drama', 'kpop': 'K-Pop', 'kfood': 'K-Food',
      'manners': 'Manners', 'slang': 'Slang', 'travel': 'Travel',
    };
    return names[widget.themeId] ?? widget.themeId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_name),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          // Level filter
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              children: [
                _LevelChip(label: 'All', value: 0, current: _level,
                  onTap: (v) => setState(() => _level = v)),
                ...List.generate(6, (i) => _LevelChip(
                  label: 'L${i + 1}', value: i + 1, current: _level,
                  onTap: (v) => setState(() => _level = v),
                  color: AppColors.topikColor(i + 1),
                )),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(children: [
              Text('${_filtered.length} words',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.listGap),
              itemBuilder: (_, i) {
                final w = _filtered[i];
                return GestureDetector(
                  onTap: () => context.push('${AppRoutes.wordCard}?id=${w.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPad),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppColors.subtleShadow,
                    ),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.topikBg(w.level),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                        child: Center(child: Text('${w.level}',
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.topikColor(w.level)))),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.korean,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'NotoSansKR',
                              fontSize: 18, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                          Text(w.english,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      )),
                      if (w.example.isNotEmpty)
                        const Icon(Icons.chat_bubble_outline,
                          size: 16, color: AppColors.textMuted),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  final int value;
  final int current;
  final ValueChanged<int> onTap;
  final Color? color;

  const _LevelChip({required this.label, required this.value,
    required this.current, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c : c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: active ? c : c.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: active ? Colors.white : c)),
      ),
    );
  }
}
