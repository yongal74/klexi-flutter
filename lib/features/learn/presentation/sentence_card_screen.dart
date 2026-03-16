import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/daily_session_service.dart';
import '../../../core/utils/tts_service.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

class SentenceCardScreen extends ConsumerStatefulWidget {
  final int? level; // null = today's session, non-null = level-specific practice
  const SentenceCardScreen({super.key, this.level});
  @override
  ConsumerState<SentenceCardScreen> createState() => _SentenceCardScreenState();
}

class _SentenceCardScreenState extends ConsumerState<SentenceCardScreen>
    with SingleTickerProviderStateMixin {
  List<Word> _words = [];
  int _index = 0;
  bool _revealed = false;
  bool _loading = true;

  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutCubic));
    _load();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(wordRepositoryProvider);

    if (widget.level != null) {
      // Level-specific practice — pick 20 random words from this level
      final lvlWords = repo.getWordsByLevel(widget.level!);
      final seed = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
      final shuffled = List<Word>.from(lvlWords);
      for (int i = shuffled.length - 1; i > 0; i--) {
        final j = (seed * (i + 1)) % (i + 1);
        final tmp = shuffled[i]; shuffled[i] = shuffled[j]; shuffled[j] = tmp;
      }
      setState(() { _words = shuffled.take(20).toList(); _loading = false; });
    } else {
      final session = ref.read(dailySessionServiceProvider);
      final ids = await session.getTodayWordIds();
      final all = repo.getAllWords();
      setState(() {
        _words = all.where((w) => ids.contains(w.id)).take(20).toList();
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
    final session = ref.read(dailySessionServiceProvider);
    if (_words.isNotEmpty) {
      await session.recordReview(_words[_index].id, quality);
    }
    if (_index + 1 >= _words.length) {
      if (mounted) context.go(AppRoutes.home);
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
            // Progress bar
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
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),

            // Main card
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
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppColors.topikColor(word.level)),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x3l),

                        // Korean word + TTS button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              word.korean,
                              style: const TextStyle(
                                fontFamily: 'NotoSansKR',
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.volume_up_rounded,
                                  size: 28, color: AppColors.primary),
                              onPressed: () => ref.read(ttsServiceProvider).speak(word.korean),
                              tooltip: 'Listen',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          word.pronunciation.isEmpty ? '' : '[${word.pronunciation}]',
                          style: const TextStyle(
                            fontSize: 16, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.x3l),

                        // Example sentence + TTS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                word.example,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansKR',
                                  fontSize: 18,
                                  height: 1.8,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up_outlined,
                                  size: 20, color: AppColors.textMuted),
                              onPressed: () => ref.read(ttsServiceProvider).speak(
                                  word.example, speed: TtsSpeed.slow),
                              tooltip: 'Listen (slow)',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Translation (revealed)
                        AnimatedOpacity(
                          opacity: _revealed ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Column(
                            children: [
                              Divider(color: AppColors.border, height: AppSpacing.x2l),
                              Text(word.english,
                                style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                              const SizedBox(height: AppSpacing.sm),
                              Text(word.exampleTranslation,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15, color: AppColors.textSecondary, height: 1.5)),
                            ],
                          ),
                        ),

                        if (!_revealed) ...[
                          const SizedBox(height: AppSpacing.x3l),
                          const Text('Tap to reveal',
                            style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Action buttons (revealed state)
            AnimatedOpacity(
              opacity: _revealed ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_revealed,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                  child: Row(
                    children: [
                      _RatingBtn(label: 'Practice', color: AppColors.error,
                        onTap: () => _next(1)),
                      const SizedBox(width: AppSpacing.sm),
                      _RatingBtn(label: 'Almost', color: AppColors.warning,
                        onTap: () => _next(3)),
                      const SizedBox(width: AppSpacing.sm),
                      _RatingBtn(label: 'Got it', color: AppColors.success,
                        onTap: () => _next(5)),
                    ],
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
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ),
        ),
      ),
    );
  }
}
