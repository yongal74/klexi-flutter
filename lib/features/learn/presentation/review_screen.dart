import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/daily_session_service.dart' show dailySessionServiceProvider, lastSessionWordsProvider;
import '../../../core/services/polar_service.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';
import 'quiz_screen.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen>
    with SingleTickerProviderStateMixin {
  List<Word> _wrongWords = [];
  List<Word> _srsWords = [];
  bool _loading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(wordRepositoryProvider);
    final isPremium = ref.read(isPremiumProvider);
    final session = ref.read(dailySessionServiceProvider);
    final wrongIds = ref.read(quizWrongWordsProvider);

    final all = repo.getAllWords();

    // Wrong quiz words
    final wrong = all
        .where((w) => wrongIds.contains(w.id) && (isPremium || w.level == 1))
        .toList();

    // All Review tab: prefer last studied session, fall back to today's session
    List<Word> srsWords;
    try {
      final lastIds = ref.read(lastSessionWordsProvider);
      if (lastIds.isNotEmpty) {
        srsWords = all
            .where((w) => lastIds.contains(w.id) && (isPremium || w.level == 1))
            .toList();
      } else {
        final todaySession = await session.getTodaySession();
        final todayIds = todaySession.words.map((w) => w.id).toSet();
        srsWords = all
            .where((w) => todayIds.contains(w.id) && (isPremium || w.level == 1))
            .toList();
      }
    } catch (_) {
      srsWords = [];
    }

    if (mounted) {
      setState(() {
        _wrongWords = wrong;
        _srsWords = srsWords;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Review'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Wrong Answers'),
            Tab(text: 'All Review'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _WordList(words: _wrongWords),
                _WordList(words: _srsWords),
              ],
            ),
    );
  }
}

class _WordList extends StatelessWidget {
  final List<Word> words;

  const _WordList({required this.words});

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Great job! No words to review.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: words.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSpacing.listGap),
      itemBuilder: (context, i) => _WordCard(word: words[i]),
    );
  }
}

class _WordCard extends StatelessWidget {
  final Word word;

  const _WordCard({required this.word});

  @override
  Widget build(BuildContext context) {
    final levelColor = AppColors.topikColor(word.level);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.korean,
                      style: const TextStyle(
                        fontFamily: 'NotoSansKR',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    if (word.pronunciation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '[${word.pronunciation}]',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      word.english,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.topikBg(word.level),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      'TOPIK ${word.level}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: levelColor),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      word.partOfSpeech,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (word.example.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.example,
                    style: const TextStyle(
                      fontFamily: 'NotoSansKR',
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    word.exampleTranslation,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
