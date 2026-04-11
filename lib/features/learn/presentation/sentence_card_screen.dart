import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/daily_session_service.dart';
import '../../../core/services/polar_service.dart';
import '../../../core/utils/tts_service.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

class SentenceCardScreen extends ConsumerStatefulWidget {
  final int? level;
  final String? wordId;   // browse from a specific word in the level list
  final int startIndex;   // start at this index in today's session
  const SentenceCardScreen({super.key, this.level, this.wordId, this.startIndex = 0});
  @override
  ConsumerState<SentenceCardScreen> createState() => _SentenceCardScreenState();
}

class _SentenceCardScreenState extends ConsumerState<SentenceCardScreen>
    with SingleTickerProviderStateMixin {
  List<Word> _words = [];
  int _index = 0;
  bool _browseMode = false; // true when launched from word list (no study rating)
  bool _revealed = false;
  bool _loading = true;

  late AnimationController _flipCtrl;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _load();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(wordRepositoryProvider);
    final isPremium = ref.read(isPremiumProvider);

    if (widget.level != null) {
      final lvlWords = repo.getWordsByLevel(widget.level!);
      if (widget.wordId != null) {
        // Browse mode: show all level words starting from the tapped word
        final idx = lvlWords.indexWhere((w) => w.id == widget.wordId);
        setState(() {
          _words = lvlWords;
          _index = idx >= 0 ? idx : 0;
          _browseMode = true;
          _loading = false;
        });
      } else {
        final seed = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
        final shuffled = List<Word>.from(lvlWords);
        for (int i = shuffled.length - 1; i > 0; i--) {
          final j = (seed * (i + 1)) % (i + 1);
          final tmp = shuffled[i]; shuffled[i] = shuffled[j]; shuffled[j] = tmp;
        }
        setState(() { _words = shuffled; _browseMode = true; _loading = false; });
      }
    } else if (widget.wordId != null) {
      // Single-word browse from daily session tile tap
      final all = repo.getAllWords();
      final word = all.firstWhere(
        (w) => w.id == widget.wordId,
        orElse: () => all.first,
      );
      setState(() {
        _words = [word];
        _index = 0;
        _browseMode = true;
        _loading = false;
      });
    } else {
      final session = ref.read(dailySessionServiceProvider);
      final ids = await session.getTodayWordIds();
      final all = repo.getAllWords();
      final sessionWords = all
          .where((w) => ids.contains(w.id) && (isPremium || w.level == 1))
          .take(20)
          .toList();
      setState(() {
        _words = sessionWords;
        _index = widget.startIndex.clamp(0, sessionWords.isEmpty ? 0 : sessionWords.length - 1);
        _loading = false;
      });
    }
  }

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    _flipCtrl.forward();
  }

  void _next(int quality) async {
    if (!_browseMode) {
      final session = ref.read(dailySessionServiceProvider);
      if (_words.isNotEmpty) {
        await session.recordReview(_words[_index].id, quality);
        // Update live today-count provider
        final count = await session.getTodayStudiedCount();
        if (mounted) ref.read(todayStudiedCountProvider.notifier).state = count;
      }
    }
    if (_index + 1 >= _words.length) {
      if (_browseMode && mounted) {
        context.pop();
        return;
      }
      if (mounted) {
        // Save this session's words for Quiz/Review/Practice
        ref.read(lastSessionWordsProvider.notifier).state =
            _words.map((w) => w.id).toList();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
            title: const Text('Session Complete! 🎉',
                textAlign: TextAlign.center),
            content: const Text(
                'Great work! Practice what you learned or continue with more words.',
                textAlign: TextAlign.center),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go(AppRoutes.home);
                },
                child: const Text('Home'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.sentencePractice);
                },
                child: const Text('Practice →'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.pop(); // back to session list
                  context.push(AppRoutes.sentenceCard); // fresh session
                },
                child: const Text('Next 20 →'),
              ),
            ],
          ),
        );
      }
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
    });
    _flipCtrl.reset();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learn')),
        body: const Center(child: Text('No words for today!')),
      );
    }

    final word = _words[_index];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_index + 1) / _words.length,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_index + 1}/${_words.length}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),

            // ── Main card ──────────────────────────────────
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
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.topikBg(word.level),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                          ),
                          child: Text(
                            'TOPIK ${word.level}  •  ${word.category}',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: AppColors.topikColor(word.level)),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x2l),

                        // Korean word + TTS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(word.korean,
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansKR',
                                    fontSize: 44, fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary, letterSpacing: 2)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up_rounded,
                                size: 26, color: AppColors.primary),
                              onPressed: () => ref.read(ttsServiceProvider).speak(word.korean),
                            ),
                          ],
                        ),

                        // 발음기호 (항상 공간 유지 — 위치 안정화)
                        SizedBox(
                          height: 22,
                          child: Text(
                            word.pronunciation.isEmpty ? '' : '[${word.pronunciation}]',
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x2l),

                        // Example sentence + TTS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(word.example,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansKR',
                                  fontSize: 16, height: 1.7,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up_outlined,
                                size: 18, color: AppColors.textMuted),
                              onPressed: () => ref.read(ttsServiceProvider).speak(
                                word.example, speed: TtsSpeed.slow),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ── 번역 영역 (항상 공간 유지 — 위치 안정화) ──
                        Visibility(
                          visible: _revealed,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: AnimatedOpacity(
                            opacity: _revealed ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Column(
                              children: [
                                Divider(color: AppColors.border, height: AppSpacing.x2l),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(word.english,
                                    style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(word.exampleTranslation,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
                              ],
                            ),
                          ),
                        ),

                        // ── Tap to reveal (항상 공간 유지) ──
                        Visibility(
                          visible: !_revealed,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: AnimatedOpacity(
                            opacity: _revealed ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: const Text('Tap to reveal',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Rating buttons ─────────────────────────────
            AnimatedOpacity(
              opacity: _revealed ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_revealed,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                    child: Row(
                      children: [
                        _RatingBtn(label: 'Again', color: AppColors.error,
                          onTap: () => _next(1)),
                        const SizedBox(width: AppSpacing.sm),
                        _RatingBtn(label: 'Good', color: AppColors.warning,
                          onTap: () => _next(3)),
                        const SizedBox(width: AppSpacing.sm),
                        _RatingBtn(label: 'Easy', color: AppColors.success,
                          onTap: () => _next(5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _RatingBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ),
      ),
    ),
  );
}
