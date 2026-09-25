import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/daily_session_service.dart';
import '../../../core/services/polar_service.dart';
import '../../../core/services/pronunciation_service.dart';
import '../../../core/utils/tts_service.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';
import '../../../core/providers/user_level_provider.dart';

class PronunciationScreen extends ConsumerStatefulWidget {
  const PronunciationScreen({super.key});
  @override
  ConsumerState<PronunciationScreen> createState() =>
      _PronunciationScreenState();
}

class _PronunciationScreenState extends ConsumerState<PronunciationScreen>
    with SingleTickerProviderStateMixin {
  bool _recording = false;
  bool _scoring = false;
  int? _score;
  String? _feedback;
  String? _transcript;
  String? _error;
  Word? _currentWord;
  bool _loading = true;
  late AnimationController _pulseCtrl;
  // Audio recorder
  final _recorder = AudioRecorder();
  String? _lastRecordingPath;

  // 오늘 세션 단어 목록
  List<Word> _sessionWords = [];
  int _wordIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _loadWord();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadWord() async {
    if (_sessionWords.isEmpty) {
      final repo = ref.read(wordRepositoryProvider);
      final session = ref.read(dailySessionServiceProvider);
      final isPremium = ref.read(isPremiumProvider);
      final userLevel = ref.read(userTopikLevelProvider);
      List<Word> words = [];
      try {
        final ids = await session.getTodayWordIds(
          isPremium: isPremium,
          userLevel: userLevel,
        );
        final idSet = ids.toSet();
        words = repo
            .getAllWords()
            .where((w) => idSet.contains(w.id) && (isPremium || w.level == 1))
            .take(20)
            .toList();
      } catch (e) {
        debugPrint('[Pronunciation] session load failed: $e');
      }
      // 오늘 세션이 비어도(첫 실행 등) 연습할 단어가 없으면 안 된다
      if (words.isEmpty) {
        words = (List.of(repo.getWordsByLevel(isPremium ? userLevel : 1))
              ..shuffle())
            .take(20)
            .toList();
      }
      _sessionWords = words;
      _wordIndex = 0;
    }
    if (!mounted) return;
    setState(() {
      _currentWord = _sessionWords.isEmpty
          ? null
          : _sessionWords[_wordIndex % _sessionWords.length];
      _loading = false;
    });
  }

  Future<bool> _ensureMicPermission() async {
    if (await _recorder.hasPermission()) return true;
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Microphone needed'),
        content: const Text(
            'Klexi needs the microphone to hear your pronunciation. '
            'Please allow microphone access for Klexi in your phone Settings, then try again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    return false;
  }

  void _toggleRecord() async {
    if (_scoring) return;
    if (_recording) {
      setState(() {
        _recording = false;
        _scoring = true;
        _score = null;
        _feedback = null;
        _transcript = null;
        _error = null;
      });

      String? path;
      try {
        path = await _recorder.stop();
      } catch (e) {
        debugPrint('[Pronunciation] stop failed: $e');
      }
      path ??= _lastRecordingPath;

      if (path == null || _currentWord == null) {
        if (mounted) {
          setState(() {
            _scoring = false;
            _error = "Recording didn't start. Please try again.";
          });
        }
        return;
      }

      final result = await ref.read(pronunciationServiceProvider).score(
            audioFile: File(path),
            expectedText: _currentWord!.korean,
          );
      if (!mounted) return;
      setState(() {
        _scoring = false;
        if (result.isError) {
          _error = result.error;
        } else {
          _score = result.score;
          _transcript = result.transcript;
        }
      });
    } else {
      if (!await _ensureMicPermission()) return;
      try {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/klexi_pronunciation.m4a';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        _lastRecordingPath = path;
        if (!mounted) return;
        setState(() {
          _recording = true;
          _score = null;
          _feedback = null;
          _transcript = null;
          _error = null;
        });
      } catch (e) {
        debugPrint('[Pronunciation] Recorder error: $e');
        if (mounted) {
          setState(() =>
              _error = "Couldn't start the microphone. Please try again.");
        }
      }
    }
  }

  void _playNative() {
    if (_currentWord == null) return;
    ref.read(ttsServiceProvider).speak(_currentWord!.korean);
  }

  void _next() async {
    if (_recording) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _score = null;
      _error = null;
      _transcript = null;
      _recording = false;
      _wordIndex++;
    });
    await _loadWord();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_sessionWords.isEmpty
            ? 'Pronunciation'
            : 'Pronunciation  ${(_wordIndex % _sessionWords.length) + 1}/${_sessionWords.length}'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _currentWord == null
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(AppSpacing.x2l),
                  child: Text('No words available to practice right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary)),
                ))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      // Word card
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(AppSpacing.sentenceCardPad),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusXl),
                        ),
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_currentWord!.korean,
                                  style: const TextStyle(
                                      fontFamily: 'NotoSansKR',
                                      fontSize: 52,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 4)),
                            ),
                            const SizedBox(height: 8),
                            if (_currentWord!.pronunciation.isNotEmpty)
                              Text('[${_currentWord!.pronunciation}]',
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.white.withOpacity(0.8))),
                            const SizedBox(height: 8),
                            Text(_currentWord!.english,
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.white70)),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x3l),

                      // Native audio button
                      OutlinedButton.icon(
                        onPressed: _playNative,
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('Play Native Audio'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
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
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _recording
                                    ? AppColors.error
                                    : AppColors.primary,
                                boxShadow: _recording
                                    ? [
                                        BoxShadow(
                                          color: AppColors.error.withOpacity(
                                              0.3 + _pulseCtrl.value * 0.3),
                                          blurRadius:
                                              20 + _pulseCtrl.value * 20,
                                          spreadRadius: 4,
                                        )
                                      ]
                                    : AppColors.cardShadow,
                              ),
                              child: Icon(
                                  _recording
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 40),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(_recording ? 'Recording…' : 'Tap to Record',
                          style: TextStyle(
                              fontSize: 14,
                              color: _recording
                                  ? AppColors.error
                                  : AppColors.textMuted)),
                      const SizedBox(height: AppSpacing.x3l),

                      // Scoring spinner
                      if (_scoring)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: CircularProgressIndicator(),
                        ),

                      // Error (채점 실패는 0점이 아니라 오류로 보여준다)
                      if (_error != null && !_scoring) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.cardPad),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusCard),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.warning),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary))),
                          ]),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                            onPressed: _next, child: const Text('Skip word')),
                      ],

                      // Score
                      if (_score != null && !_scoring) ...[
                        _ScoreCard(
                          score: _score!,
                          feedback: _feedback,
                          transcript: _transcript,
                        ),
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
  final String? feedback;
  final String? transcript;
  const _ScoreCard({required this.score, this.feedback, this.transcript});

  Color get _color {
    if (score >= 85) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String get _label =>
      feedback ??
      (score >= 85
          ? 'Great job! 🎉'
          : score >= 60
              ? 'Almost there!'
              : 'Keep practicing');

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
            width: 60,
            height: 60,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _color)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Score',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(_label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _color)),
              if (transcript != null && transcript!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Heard: "$transcript"',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ],
          )),
        ],
      ),
    );
  }
}
