import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

class PronunciationScreen extends ConsumerStatefulWidget {
  const PronunciationScreen({super.key});
  @override
  ConsumerState<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends ConsumerState<PronunciationScreen>
    with SingleTickerProviderStateMixin {
  bool _recording = false;
  bool _hasRecording = false;
  int? _score;
  Word? _currentWord;
  bool _loading = true;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _loadWord();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWord() async {
    final repo = ref.read(wordRepositoryProvider);
    final words = repo.getAllWords();
    if (words.isNotEmpty) {
      setState(() {
        _currentWord = words[DateTime.now().millisecond % words.length];
        _loading = false;
      });
    }
  }

  void _toggleRecord() async {
    if (_recording) {
      // Stop recording → score
      setState(() {
        _recording = false;
        _hasRecording = true;
        // Mock score — replace with actual pronunciation API
        _score = 75 + (DateTime.now().millisecond % 25);
      });
    } else {
      setState(() {
        _recording = true;
        _hasRecording = false;
        _score = null;
      });
    }
  }

  void _next() async {
    setState(() { _score = null; _hasRecording = false; _recording = false; });
    await _loadWord();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Pronunciation'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  // Word card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sentenceCardPad),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    ),
                    child: Column(
                      children: [
                        Text(_currentWord!.korean,
                          style: const TextStyle(
                            fontFamily: 'NotoSansKR',
                            fontSize: 52, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 4)),
                        const SizedBox(height: 8),
                        if (_currentWord!.pronunciation.isNotEmpty)
                          Text('[${_currentWord!.pronunciation}]',
                            style: TextStyle(fontSize: 20, color: Colors.white.withOpacity(0.8))),
                        const SizedBox(height: 8),
                        Text(_currentWord!.english,
                          style: const TextStyle(fontSize: 18, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3l),

                  // Native audio button
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.volume_up_outlined),
                    label: const Text('Play Native Audio'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3l),

                  // Record button
                  GestureDetector(
                    onTap: _toggleRecord,
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) {
                        return Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _recording
                                ? AppColors.error
                                : AppColors.primary,
                            boxShadow: _recording ? [
                              BoxShadow(
                                color: AppColors.error.withOpacity(0.3 + _pulseCtrl.value * 0.3),
                                blurRadius: 20 + _pulseCtrl.value * 20,
                                spreadRadius: 4,
                              )
                            ] : AppColors.cardShadow,
                          ),
                          child: Icon(
                            _recording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white, size: 40),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _recording ? 'Recording…' : 'Tap to Record',
                    style: TextStyle(
                      fontSize: 14,
                      color: _recording ? AppColors.error : AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.x3l),

                  // Score
                  if (_score != null) ...[
                    _ScoreCard(score: _score!),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: _next,
                      child: const Text('Next Word'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;
  const _ScoreCard({required this.score});

  Color get _color {
    if (score >= 85) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String get _label {
    if (score >= 85) return 'Great job! 🎉';
    if (score >= 60) return 'Almost there!';
    return 'Keep practicing';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: _color.withOpacity(0.3)),
        boxShadow: AppColors.subtleShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60, height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: _color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(_color),
                ),
                Text('$score',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _color)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Score', style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(_label, style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _color)),
            ],
          )),
        ],
      ),
    );
  }
}
