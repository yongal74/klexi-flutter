import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/tts_service.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(wordRepositoryProvider);
    final words = repo.getAllWords();
    final w = words.firstWhere((w) => w.id == widget.wordId, orElse: () => words.first);
    setState(() => _word = w);
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
              onPressed: () => ref.read(ttsServiceProvider).speak(word.korean),
            ),
        ],
      ),
      body: word == null
          ? const Center(child: CircularProgressIndicator())
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
                        Text(word.korean,
                          style: const TextStyle(
                            fontFamily: 'NotoSansKR',
                            fontSize: 56, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 2)),
                        if (word.pronunciation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('[${word.pronunciation}]',
                            style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8))),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Text(word.english,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.95))),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Info row
                  Row(children: [
                    _InfoChip('TOPIK ${word.level}', AppColors.topikColor(word.level)),
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
                            fontSize: 18, height: 1.8,
                            color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(word.exampleTranslation,
                          style: const TextStyle(
                            fontSize: 15, color: AppColors.textSecondary, height: 1.5)),
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
                        children: word.relatedIds.map((id) => _RelatedChip(id)).toList(),
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
    child: Text(label, style: TextStyle(
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
        Text(title, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.textMuted, letterSpacing: 0.5)),
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
    child: Text(wordId, style: const TextStyle(
      fontSize: 13, color: AppColors.textSecondary)),
  );
}
