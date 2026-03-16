import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

// Simple force-directed word network using CustomPainter
class WordNetworkScreen extends ConsumerStatefulWidget {
  const WordNetworkScreen({super.key});
  @override
  ConsumerState<WordNetworkScreen> createState() => _WordNetworkScreenState();
}

class _WordNetworkScreenState extends ConsumerState<WordNetworkScreen>
    with TickerProviderStateMixin {
  List<Word> _words = [];
  Word? _selected;
  bool _loading = true;
  int _levelFilter = 0; // 0 = all
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(wordRepositoryProvider);
    final words = await repo.getAllWords();
    setState(() {
      // Use representative sample for network (100 words max)
      _words = words.take(100).toList();
      _loading = false;
    });
  }

  List<Word> get _filtered => _levelFilter == 0
      ? _words
      : _words.where((w) => w.level == _levelFilter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B1E), // dark bg for network
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0B1E),
        foregroundColor: Colors.white,
        title: const Text('Word Network',
          style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white70),
            onPressed: _showLevelFilter,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                // Network canvas
                _NetworkCanvas(
                  words: _filtered,
                  selected: _selected,
                  pulseAnim: _pulseCtrl,
                  onTap: (w) => setState(() => _selected = _selected?.id == w.id ? null : w),
                ),

                // Level filter chips
                Positioned(
                  top: 12,
                  left: 0, right: 0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _LevelChip(label: 'All', value: 0, current: _levelFilter,
                          onTap: (v) => setState(() => _levelFilter = v)),
                        ...List.generate(6, (i) => _LevelChip(
                          label: 'L${i + 1}', value: i + 1, current: _levelFilter,
                          onTap: (v) => setState(() => _levelFilter = v),
                          color: AppColors.topikColor(i + 1),
                        )),
                      ],
                    ),
                  ),
                ),

                // Selected word panel
                if (_selected != null)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: _WordPanel(
                      word: _selected!,
                      onClose: () => setState(() => _selected = null),
                      onLearn: () => context.push(
                        '${AppRoutes.wordCard}?id=${_selected!.id}'),
                    ),
                  ),

                // Hint
                if (_selected == null)
                  Positioned(
                    bottom: 20,
                    left: 0, right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: const Text('Tap a word to explore',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _showLevelFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Filter by Level',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _FilterBtn(label: 'All', onTap: () {
                  setState(() => _levelFilter = 0);
                  Navigator.pop(context);
                }),
                ...List.generate(6, (i) => _FilterBtn(
                  label: 'TOPIK ${i + 1}',
                  color: AppColors.topikColor(i + 1),
                  onTap: () {
                    setState(() => _levelFilter = i + 1);
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkCanvas extends StatelessWidget {
  final List<Word> words;
  final Word? selected;
  final Animation<double> pulseAnim;
  final ValueChanged<Word> onTap;

  const _NetworkCanvas({
    required this.words,
    required this.selected,
    required this.pulseAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, _) {
        return CustomPaint(
          painter: _NetworkPainter(
            words: words,
            selected: selected,
            pulse: pulseAnim.value,
          ),
          child: GestureDetector(
            onTapUp: (details) => _handleTap(details.localPosition, context),
          ),
        );
      },
    );
  }

  void _handleTap(Offset pos, BuildContext context) {
    final size = context.size ?? Size.zero;
    final positions = _NetworkPainter.computePositions(words, size);
    for (int i = 0; i < words.length; i++) {
      final p = positions[i];
      if ((p - pos).distance < 28) {
        onTap(words[i]);
        return;
      }
    }
  }
}

class _NetworkPainter extends CustomPainter {
  final List<Word> words;
  final Word? selected;
  final double pulse;

  _NetworkPainter({required this.words, required this.selected, required this.pulse});

  static List<Offset> computePositions(List<Word> words, Size size) {
    if (words.isEmpty) return [];
    final positions = <Offset>[];
    final cx = size.width / 2;
    final cy = size.height / 2;
    final total = words.length;
    for (int i = 0; i < total; i++) {
      final angle = (i / total) * 2 * 3.14159;
      final radius = 60 + (i % 4) * 55.0;
      final spiralAngle = angle + (i * 0.3);
      positions.add(Offset(
        cx + radius * 1.2 * (spiralAngle % 3.14159 < 1.5 ? 1 : -1) * (0.3 + (i % 5) * 0.15),
        cy + radius * (spiralAngle % 3.14159 < 1.5 ? -1 : 1) * (0.3 + (i % 4) * 0.18),
      ));
    }
    return positions;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (words.isEmpty) return;
    final positions = computePositions(words, size);

    // Draw connections for selected word
    if (selected != null) {
      final selIdx = words.indexWhere((w) => w.id == selected!.id);
      if (selIdx >= 0) {
        for (int i = 0; i < words.length; i++) {
          if (i == selIdx) continue;
          if (words[i].level == selected!.level) {
            final paint = Paint()
              ..color = AppColors.topikColor(selected!.level).withOpacity(0.25)
              ..strokeWidth = 1
              ..style = PaintingStyle.stroke;
            canvas.drawLine(positions[selIdx], positions[i], paint);
          }
        }
      }
    } else {
      // Draw some connections between same-level nearby words
      final linePaint = Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < words.length; i++) {
        for (int j = i + 1; j < words.length; j++) {
          if (words[i].level == words[j].level &&
              (positions[i] - positions[j]).distance < 80) {
            canvas.drawLine(positions[i], positions[j], linePaint);
          }
        }
      }
    }

    // Draw nodes
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final p = positions[i];
      final isSelected = selected?.id == w.id;
      final isSameLevel = selected != null && w.level == selected!.level;
      final color = AppColors.topikColor(w.level);
      final radius = isSelected ? 22.0 + pulse * 4 : (isSameLevel ? 16.0 : 12.0);

      // Glow
      if (isSelected) {
        canvas.drawCircle(p, radius + 8 + pulse * 6,
          Paint()..color = color.withOpacity(0.15 + pulse * 0.1)..style = PaintingStyle.fill);
      }

      // Node circle
      canvas.drawCircle(p, radius,
        Paint()..color = isSelected ? color : color.withOpacity(0.7)..style = PaintingStyle.fill);

      // Text
      final tp = TextPainter(
        text: TextSpan(
          text: w.korean,
          style: TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: isSelected ? 11 : 9,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 60);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_NetworkPainter old) =>
      old.words != words || old.selected != selected || old.pulse != pulse;
}

class _LevelChip extends StatelessWidget {
  final String label;
  final int value;
  final int current;
  final ValueChanged<int> onTap;
  final Color? color;

  const _LevelChip({
    required this.label, required this.value,
    required this.current, required this.onTap, this.color,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c : c.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? Colors.white : c)),
      ),
    );
  }
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _FilterBtn({required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(label, style: TextStyle(
        color: color ?? Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
    ),
  );
}

class _WordPanel extends StatelessWidget {
  final Word word;
  final VoidCallback onClose;
  final VoidCallback onLearn;

  const _WordPanel({required this.word, required this.onClose, required this.onLearn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.topikColor(word.level).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text('TOPIK ${word.level}', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.topikColor(word.level))),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, color: Colors.white54, size: 20)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(word.korean,
                style: const TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(word.english,
                  style: const TextStyle(fontSize: 18, color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(word.example,
            style: const TextStyle(
              fontFamily: 'NotoSansKR',
              fontSize: 15, color: Colors.white60, height: 1.6)),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onLearn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                ),
                child: const Text('Learn Word'),
              ),
            ),
          ]),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
