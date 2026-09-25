import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/utils/tts_service.dart';
import '../../../data/content/themes/themes_index.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

class WordCardScreen extends ConsumerStatefulWidget {
  final String wordId;
  const WordCardScreen({super.key, required this.wordId});
  @override
  ConsumerState<WordCardScreen> createState() => _WordCardScreenState();
}

class _WordCardScreenState extends ConsumerState<WordCardScreen> {
  Word? _word;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = _findWord(widget.wordId);
    if (!mounted) return;
    setState(() {
      _word = w;
      _notFound = w == null;
    });
    if (w != null) {
      AnalyticsService.instance
          .logWordCardViewed(wordId: w.id, topikLevel: w.level);
    }
  }

  /// TOPIK 단어(id "3-120")와 테마 단어(id "theme-kdrama-1-1")는 저장소가 다르다.
  /// 예전에는 TOPIK 목록에서만 찾고 못 찾으면 첫 단어를 보여줘서,
  /// 테마 단어를 누르면 항상 엉뚱한 단어가 떴다.
  Word? _findWord(String id) {
    if (id.startsWith('theme-')) {
      final themeId = id.split('-')[1];
      for (final w in getThemeWords(themeId)) {
        if (w.id == id) return w;
      }
    }
    for (final w in ref.read(wordRepositoryProvider).getAllWords()) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final word = _word;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(word?.korean ?? ''),
        backgroundColor: AppColors.surface,
        actions: [
          if (word != null)
            IconButton(
              icon: const Icon(Icons.volume_up_outlined),
              tooltip: 'Listen',
              onPressed: () => ref.read(ttsServiceProvider).speak(word.korean),
            ),
        ],
      ),
      body: word == null
          ? Center(
              child: _notFound
                  ? const Text("This word couldn't be found.",
                      style: TextStyle(color: AppColors.textSecondary))
                  : const CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.cardPadLg),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    ),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(word.korean,
                              style: const TextStyle(
                                  fontFamily: 'NotoSansKR',
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 2)),
                        ),
                        if (word.pronunciation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('[${word.pronunciation}]',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.8))),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Text(word.english,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.95))),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Info row
                  Row(children: [
                    _InfoChip('TOPIK ${word.level}',
                        AppColors.topikColor(word.level)),
                    const SizedBox(width: AppSpacing.sm),
                    _InfoChip(word.partOfSpeech, AppColors.accent),
                    if (word.category.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _InfoChip(word.category, AppColors.info),
                    ],
                  ]),
                  const SizedBox(height: AppSpacing.lg),

                  // Example sentence card
                  _SectionCard(
                    title: 'Example Sentence',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(word.example,
                            style: const TextStyle(
                                fontFamily: 'NotoSansKR',
                                fontSize: 18,
                                height: 1.8,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(word.exampleTranslation,
                            style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                                height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.listGap),

                  // Related words
                  if (word.relatedIds.isNotEmpty)
                    _SectionCard(
                      title: 'Related Words',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: word.relatedIds
                            .map((id) => _RelatedChip(id))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

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
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5)),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      );
}

class _RelatedChip extends StatelessWidget {
  final String wordId;
  const _RelatedChip(this.wordId);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.chipPadH, vertical: AppSpacing.chipPadV),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(wordId,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      );
}
