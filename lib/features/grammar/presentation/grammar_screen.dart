import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../data/content/grammar/grammar_data.dart';
import '../../../data/models/grammar_pattern.dart';

class GrammarScreen extends ConsumerStatefulWidget {
  const GrammarScreen({super.key});
  @override
  ConsumerState<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends ConsumerState<GrammarScreen> {
  int _level = 0; // 0 = all
  String _search = '';

  List<GrammarPattern> get _filtered {
    var list = kGrammarData;
    if (_level > 0) list = list.where((g) => g.level == _level).toList();
    if (_search.isNotEmpty) {
      list = list.where((g) =>
        g.title.toLowerCase().contains(_search.toLowerCase()) ||
        g.meaning.toLowerCase().contains(_search.toLowerCase())).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Grammar Patterns'),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search patterns…',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Level filter
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                _LevelTab(label: 'All', value: 0, current: _level,
                  onTap: (v) => setState(() => _level = v)),
                ...List.generate(6, (i) => _LevelTab(
                  label: 'L${i + 1}', value: i + 1, current: _level,
                  onTap: (v) => setState(() => _level = v),
                  color: AppColors.topikColor(i + 1),
                )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Pattern count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Text('${_filtered.length} patterns',
                  style: const TextStyle(
                    fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.listGap),
              itemBuilder: (_, i) => _GrammarCard(
                pattern: _filtered[i],
                onTap: () => context.push(
                  AppRoutes.grammarDetail.replaceFirst(':id', _filtered[i].id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrammarCard extends StatelessWidget {
  final GrammarPattern pattern;
  final VoidCallback onTap;
  const _GrammarCard({required this.pattern, required this.onTap});

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
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.topikBg(pattern.level),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Center(
                child: Text('${pattern.level}',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.topikColor(pattern.level))),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pattern.title,
                    style: const TextStyle(
                      fontFamily: 'NotoSansKR',
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(pattern.meaning,
                    style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
                  if (pattern.examples.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(pattern.examples.first.korean,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NotoSansKR',
                        fontSize: 13, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LevelTab extends StatelessWidget {
  final String label;
  final int value;
  final int current;
  final ValueChanged<int> onTap;
  final Color? color;

  const _LevelTab({
    required this.label, required this.value,
    required this.current, required this.onTap, this.color,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
