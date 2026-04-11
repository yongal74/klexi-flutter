import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

class ClozeQuizScreen extends ConsumerStatefulWidget {
  const ClozeQuizScreen({super.key});
  @override
  ConsumerState<ClozeQuizScreen> createState() => _ClozeQuizScreenState();
}

class _ClozeQuizScreenState extends ConsumerState<ClozeQuizScreen> {
  List<Word> _quiz = [];
  int _index = 0;
  String? _selected;
  List<String> _choices = [];
  bool _loading = true;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(wordRepositoryProvider);
    final all = repo.getAllWords();
    final rng = Random();
    final shuffled = List.of(all)..shuffle(rng);
    setState(() {
      _quiz = shuffled.take(10).toList();
      _loading = false;
      _buildChoices();
    });
  }

  void _buildChoices() {
    if (_quiz.isEmpty) return;
    final target = _quiz[_index];
    final others = <String>[];
    // Add 3 random distractors from same level if possible
    final rng = Random();
    final candidates = _quiz.where((w) => w.id != target.id).toList()..shuffle(rng);
    for (final w in candidates.take(3)) {
      others.add(w.korean);
    }
    _choices = [target.korean, ...others]..shuffle(rng);
  }

  void _answer(String choice) {
    if (_selected != null) return;
    setState(() {
      _selected = choice;
      if (choice == _quiz[_index].korean) _correct++;
    });
  }

  void _next() {
    if (_index + 1 >= _quiz.length) {
      _showResult();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _buildChoices();
    });
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
        title: const Text('Quiz Complete!', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$_correct / ${_quiz.length}',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 8),
          Text('${(_correct / _quiz.length * 100).round()}% correct',
            style: const TextStyle(color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); context.pop(); },
            child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_quiz.isEmpty) return const Scaffold(body: Center(child: Text('No quiz available')));

    final word = _quiz[_index];

    // Build sentence with blank
    final sentence = (word.exampleTranslation.trim().length > 3)
        ? word.exampleTranslation
        : word.english;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Fill in the Blank'),
        backgroundColor: AppColors.surface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_index + 1}/${_quiz.length}',
                style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  // Progress
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_index + 1) / _quiz.length,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3l),

                  // Question card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.cardPadLg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      children: [
                        Text('Fill in the Korean word:',
                          style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.lg),
                        Text(sentence,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, height: 1.6, color: AppColors.textPrimary)),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.primary, width: 2.5)),
                          ),
                          child: const Text('?',
                            style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.x3l),

                  // Choices
                  ...List.generate(_choices.length, (i) {
                    final ch = _choices[i];
                    final isCorrect = ch == word.korean;
                    final isSelected = ch == _selected;
                    Color bg = AppColors.surface;
                    Color border = AppColors.border;
                    Color text = AppColors.textPrimary;
                    if (_selected != null) {
                      if (isCorrect) { bg = AppColors.success.withOpacity(0.12); border = AppColors.success; text = AppColors.success; }
                      else if (isSelected) { bg = AppColors.error.withOpacity(0.12); border = AppColors.error; text = AppColors.error; }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: GestureDetector(
                        onTap: () => _answer(ch),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(color: border, width: 1.5),
                          ),
                          child: Text(ch,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansKR',
                              fontSize: 18, fontWeight: FontWeight.w600, color: text)),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),

          if (_selected != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm,
                AppSpacing.lg, AppSpacing.lg + MediaQuery.of(context).padding.bottom),
              child: ElevatedButton(
                onPressed: _next,
                child: Text(_index + 1 >= _quiz.length ? 'Finish' : 'Next'),
              ),
            ),
        ],
      ),
    );
  }
}
