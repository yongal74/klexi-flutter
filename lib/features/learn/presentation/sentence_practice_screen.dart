// lib/features/learn/presentation/sentence_practice_screen.dart
// Sentence Practice — shows pre-generated group sentences for today's 20 learned words.
// Sentences naturally incorporate the vocabulary, making memorization easier through context.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/daily_session_service.dart'
    show dailySessionServiceProvider, lastSessionWordsProvider;
import '../../../core/services/polar_service.dart';
import '../../../core/utils/tts_service.dart';
import '../../../data/content/sentence_groups_data.dart';
import '../../../data/content/sentence_groups_registry.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

class SentencePracticeScreen extends ConsumerStatefulWidget {
  const SentencePracticeScreen({super.key});

  @override
  ConsumerState<SentencePracticeScreen> createState() =>
      _SentencePracticeScreenState();
}

class _SentencePracticeScreenState
    extends ConsumerState<SentencePracticeScreen> {
  List<PracticeSentence> _sentences = [];
  SentenceGroup? _group;
  bool _loading = true;

  int _cardIndex = 0;
  bool _revealed = false;
  bool _allComplete = false;
  bool _ttsPlaying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(wordRepositoryProvider);
    final isPremium = ref.read(isPremiumProvider);
    final session = ref.read(dailySessionServiceProvider);

    // Get today's / last session word IDs
    final lastIds = ref.read(lastSessionWordsProvider);
    final List<String> sessionWordIds;
    if (lastIds.isNotEmpty) {
      sessionWordIds = lastIds.take(20).toList();
    } else {
      sessionWordIds = await session.getTodayWordIds();
    }

    // Find matching sentence group from pre-generated data
    final group = _findMatchingGroup(sessionWordIds, isPremium);

    if (mounted) {
      setState(() {
        _group = group;
        _sentences = group?.sentences ?? _fallbackSentences(
          repo.getAllWords()
            .where((w) => sessionWordIds.contains(w.id) && (isPremium || w.level == 1))
            .take(4)
            .toList(),
        );
        _loading = false;
      });
    }
  }

  /// Find the sentence group whose wordIds most overlap with the session words.
  SentenceGroup? _findMatchingGroup(List<String> sessionIds, bool isPremium) {
    if (sessionIds.isEmpty) return null;
    final sessionSet = sessionIds.toSet();

    SentenceGroup? best;
    int bestScore = 0;

    for (final group in kAllSentenceGroups) {
      if (!isPremium && group.level > 1) continue;
      final overlap = group.wordIds.where((id) => sessionSet.contains(id)).length;
      if (overlap > bestScore) {
        bestScore = overlap;
        best = group;
      }
    }
    return best;
  }

  /// Fallback: build sentences from individual word examples when no group matches.
  List<PracticeSentence> _fallbackSentences(List<Word> words) {
    return words.map((w) => PracticeSentence(
      korean: w.example,
      english: w.exampleTranslation,
      highlights: [w.korean],
    )).toList();
  }

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
  }

  Future<void> _speak(String text) async {
    AnalyticsService.instance.logTtsPlayed(source: 'sentence_practice');
    if (_ttsPlaying) {
      await ref.read(ttsServiceProvider).stop();
      setState(() => _ttsPlaying = false);
      return;
    }
    setState(() => _ttsPlaying = true);
    await ref.read(ttsServiceProvider).speak(text, isPremium: true);
    if (mounted) setState(() => _ttsPlaying = false);
  }

  void _next() {
    if (_cardIndex + 1 >= _sentences.length) {
      AnalyticsService.instance.logSentencePracticeCompleted(
        topikLevel: _group?.level ?? 1,
      );
      setState(() => _allComplete = true);
    } else {
      setState(() {
        _cardIndex++;
        _revealed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_sentences.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(
          child: Text('No sentences available.\nComplete a study session first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
        ),
      );
    }
    if (_allComplete) return _buildAllComplete();
    return _buildCard();
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    title: const Text('Sentence Practice'),
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      onPressed: () => context.pop(),
    ),
  );

  Widget _buildCard() {
    final sentence = _sentences[_cardIndex];
    final progress = (_cardIndex + 1) / _sentences.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(children: [
          // ── Progress ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sentence ${_cardIndex + 1} of ${_sentences.length}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    if (_group != null)
                      Text(
                        'TOPIK ${_group!.level} · Group ${_group!.groupIndex}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),

          // ── Sentence card ──────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: GestureDetector(
                onTap: _reveal,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sentenceCardPad),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // TTS button
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => _speak(sentence.korean),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                            ),
                            child: Icon(
                              _ttsPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Korean sentence with highlights
                      _buildHighlightedSentence(sentence),
                      const SizedBox(height: AppSpacing.x2l),

                      // Translation reveal
                      AnimatedOpacity(
                        opacity: _revealed ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: _revealed
                            ? Column(children: [
                                Divider(
                                    color: AppColors.border,
                                    height: AppSpacing.x2l),
                                Text(
                                  sentence.english,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    height: 1.5,
                                  ),
                                ),
                              ])
                            : Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Tap to reveal translation',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted.withOpacity(0.7)),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Next button ────────────────────────────────
          AnimatedOpacity(
            opacity: _revealed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_revealed,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.x2l),
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
                      _cardIndex + 1 >= _sentences.length
                          ? 'Finish'
                          : 'Next →',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Renders Korean sentence with vocab highlights in primary color.
  Widget _buildHighlightedSentence(PracticeSentence sentence) {
    final korean = sentence.korean;
    final highlights = sentence.highlights;

    if (highlights.isEmpty) {
      return Text(
        korean,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.6,
        ),
      );
    }

    // Build a list of TextSpans, highlighting each vocab word
    final spans = <TextSpan>[];
    String remaining = korean;

    // Sort highlights by their position in the sentence
    final sorted = highlights
        .where((h) => korean.contains(h))
        .toList()
      ..sort((a, b) => korean.indexOf(a).compareTo(korean.indexOf(b)));

    for (final word in sorted) {
      final idx = remaining.indexOf(word);
      if (idx < 0) continue;
      if (idx > 0) {
        spans.add(TextSpan(text: remaining.substring(0, idx)));
      }
      spans.add(TextSpan(
        text: word,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary,
          decorationThickness: 2.5,
        ),
      ));
      remaining = remaining.substring(idx + word.length);
    }
    if (remaining.isNotEmpty) {
      spans.add(TextSpan(text: remaining));
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.6,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildAllComplete() => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: _buildAppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 64)),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Practice Complete!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'You\'ve reviewed all sentences for this session.\nReady to test yourself?',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x3l),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonH,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.quizSession),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: const Text('Take Quiz →',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Back to Home',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    ),
  );
}
