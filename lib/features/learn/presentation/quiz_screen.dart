import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/daily_session_service.dart' show dailySessionServiceProvider, lastSessionWordsProvider;
import '../../../core/services/purchase_service.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

/// Global provider to pass wrong word IDs from quiz to review screen.
final quizWrongWordsProvider = StateProvider<List<String>>((ref) => []);

class _QuizQuestion {
  final Word word;
  final List<String> options;   // 4 English meanings
  final int correctIndex;

  const _QuizQuestion({
    required this.word,
    required this.options,
    required this.correctIndex,
  });
}

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  List<_QuizQuestion> _questions = [];
  bool _loading = true;

  int _current = 0;
  int? _selectedOption;     // null = not answered yet
  int _correctCount = 0;
  final List<String> _wrongWordIds = [];

  bool get _answered => _selectedOption != null;
  bool get _finished => _current >= _questions.length && _questions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(wordRepositoryProvider);
    final isPremium = ref.read(isPremiumProvider);
    final session = ref.read(dailySessionServiceProvider);
    final all = repo.getAllWords();

    // Prefer the last studied session; fall back to today's session words
    final lastIds = ref.read(lastSessionWordsProvider);
    final List<Word> todayWords;
    if (lastIds.isNotEmpty) {
      todayWords = all
          .where((w) => lastIds.contains(w.id) && (isPremium || w.level == 1))
          .take(20)
          .toList();
    } else {
      final ids = await session.getTodayWordIds();
      todayWords = all
          .where((w) => ids.contains(w.id) && (isPremium || w.level == 1))
          .take(20)
          .toList();
    }

    if (todayWords.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final rng = Random();
    final questions = <_QuizQuestion>[];

    for (final word in todayWords) {
      // Build 3 distractors from other words in the session
      final others = todayWords.where((w) => w.id != word.id).toList()
        ..shuffle(rng);
      final distractors = others.take(3).map((w) => w.english).toList();

      final options = [...distractors, word.english]..shuffle(rng);
      final correctIndex = options.indexOf(word.english);

      questions.add(_QuizQuestion(
        word: word,
        options: options,
        correctIndex: correctIndex,
      ));
    }

    if (mounted) {
      setState(() {
        _questions = questions;
        _loading = false;
      });
    }
  }

  void _select(int optionIndex) {
    if (_answered) return;
    final q = _questions[_current];
    final isCorrect = optionIndex == q.correctIndex;

    setState(() {
      _selectedOption = optionIndex;
      if (isCorrect) {
        _correctCount++;
      } else {
        _wrongWordIds.add(q.word.id);
      }
    });
  }

  void _next() {
    if (_current + 1 >= _questions.length) {
      // Quiz done — update provider and show results
      ref.read(quizWrongWordsProvider.notifier).state =
          List<String>.from(_wrongWordIds);
      final level = ref.read(isPremiumProvider) ? 0 : 1;
      AnalyticsService.instance.logQuizCompleted(
        correct: _correctCount,
        total: _questions.length,
        topikLevel: level,
      );
      setState(() {
        _current++;  // triggers _finished
        _selectedOption = null;
      });
    } else {
      setState(() {
        _current++;
        _selectedOption = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(
          child: Text('No words available for quiz.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    if (_finished) return _buildResults();
    return _buildQuiz();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Quiz'),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => context.pop(),
      ),
    );
  }

  Widget _buildQuiz() {
    final q = _questions[_current];
    final progress = (_current + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress
              Row(
                children: [
                  Text(
                    '${_current + 1} / ${_questions.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.border,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2l),

              // Question card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.cardPadLg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    const Text(
                      'What does this word mean?',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      q.word.korean,
                      style: const TextStyle(
                        fontFamily: 'NotoSansKR',
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (q.word.pronunciation.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '[${q.word.pronunciation}]',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),

              // Options
              ...List.generate(q.options.length, (i) {
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppSpacing.buttonGapLg),
                  child: _OptionButton(
                    label: q.options[i],
                    index: i,
                    selectedIndex: _selectedOption,
                    correctIndex: q.correctIndex,
                    onTap: () => _select(i),
                  ),
                );
              }),

              const Spacer(),

              // Next button
              AnimatedOpacity(
                opacity: _answered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_answered,
                  child: SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonH,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      child: Text(
                        _current + 1 >= _questions.length
                            ? 'See Results'
                            : 'Next →',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final total = _questions.length;
    final percent = total > 0 ? (_correctCount / total * 100).round() : 0;
    final wrongWords = _questions
        .where((q) => _wrongWordIds.contains(q.word.id))
        .map((q) => q.word)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Score card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.cardPadLg),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: Column(
                  children: [
                    const Text('Quiz Complete! 🎉',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '$_correctCount / $total',
                      style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                    Text(
                      '$percent% correct',
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // Wrong words list
              if (wrongWords.isNotEmpty) ...[
                Text(
                  'Words to Review (${wrongWords.length})',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.md),
                ...wrongWords.map((w) => Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.listGap),
                      padding: const EdgeInsets.all(AppSpacing.cardPad),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(
                            color: AppColors.error.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.korean,
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansKR',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  w.english,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.topikBg(w.level),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Text(
                              'TOPIK ${w.level}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.topikColor(w.level)),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: AppSpacing.sectionGap),
              ],

              // Action buttons
              if (wrongWords.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonH,
                  child: ElevatedButton(
                    onPressed: () =>
                        context.push(AppRoutes.reviewSession),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    child: const Text(
                      'Review Wrong Words →',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (wrongWords.isNotEmpty)
                const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonH,
                child: OutlinedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Option Button ──────────────────────────────────────────────────────────────

class _OptionButton extends StatelessWidget {
  final String label;
  final int index;
  final int? selectedIndex;
  final int correctIndex;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.correctIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final answered = selectedIndex != null;
    final isSelected = selectedIndex == index;
    final isCorrect = index == correctIndex;

    Color borderColor = AppColors.border;
    Color bgColor = AppColors.surface;
    Color textColor = AppColors.textPrimary;

    if (answered) {
      if (isCorrect) {
        borderColor = AppColors.success;
        bgColor = AppColors.success.withOpacity(0.08);
        textColor = AppColors.success;
      } else if (isSelected) {
        borderColor = AppColors.error;
        bgColor = AppColors.error.withOpacity(0.08);
        textColor = AppColors.error;
      }
    }

    return GestureDetector(
      onTap: answered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            vertical: 14, horizontal: AppSpacing.cardPad),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: borderColor),
          boxShadow: AppColors.subtleShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: answered && isCorrect
                    ? AppColors.success.withOpacity(0.15)
                    : answered && isSelected
                        ? AppColors.error.withOpacity(0.15)
                        : AppColors.bg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor),
              ),
            ),
            if (answered && isCorrect)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.success),
            if (answered && isSelected && !isCorrect)
              const Icon(Icons.cancel_rounded,
                  size: 18, color: AppColors.error),
          ],
        ),
      ),
    );
  }
}
