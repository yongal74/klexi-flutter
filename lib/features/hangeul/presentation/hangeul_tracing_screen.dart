import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

class _HangeulChar {
  final String character;
  final String romanization;
  final String type; // consonant / vowel
  final String strokeHint;
  const _HangeulChar({required this.character, required this.romanization,
    required this.type, required this.strokeHint});
}

const _consonants = [
  _HangeulChar(character: 'ㄱ', romanization: 'g/k', type: 'consonant', strokeHint: 'Right then down'),
  _HangeulChar(character: 'ㄴ', romanization: 'n',   type: 'consonant', strokeHint: 'Down then right'),
  _HangeulChar(character: 'ㄷ', romanization: 'd/t', type: 'consonant', strokeHint: 'Top, middle, bottom'),
  _HangeulChar(character: 'ㄹ', romanization: 'r/l', type: 'consonant', strokeHint: 'Down, right, up, right, down'),
  _HangeulChar(character: 'ㅁ', romanization: 'm',   type: 'consonant', strokeHint: 'Top, left, right, bottom'),
  _HangeulChar(character: 'ㅂ', romanization: 'b/p', type: 'consonant', strokeHint: 'Sides then top'),
  _HangeulChar(character: 'ㅅ', romanization: 's',   type: 'consonant', strokeHint: 'Left down, right down from center'),
  _HangeulChar(character: 'ㅇ', romanization: 'ng',  type: 'consonant', strokeHint: 'Circle counterclockwise'),
  _HangeulChar(character: 'ㅈ', romanization: 'j',   type: 'consonant', strokeHint: 'Horizontal, then V shape'),
  _HangeulChar(character: 'ㅎ', romanization: 'h',   type: 'consonant', strokeHint: 'Horizontal, circle below'),
];

const _vowels = [
  _HangeulChar(character: 'ㅏ', romanization: 'a',   type: 'vowel', strokeHint: 'Vertical, then horizontal right'),
  _HangeulChar(character: 'ㅓ', romanization: 'eo',  type: 'vowel', strokeHint: 'Vertical, then horizontal left'),
  _HangeulChar(character: 'ㅗ', romanization: 'o',   type: 'vowel', strokeHint: 'Horizontal, vertical up'),
  _HangeulChar(character: 'ㅜ', romanization: 'u',   type: 'vowel', strokeHint: 'Horizontal, vertical down'),
  _HangeulChar(character: 'ㅡ', romanization: 'eu',  type: 'vowel', strokeHint: 'Single horizontal stroke'),
  _HangeulChar(character: 'ㅣ', romanization: 'i',   type: 'vowel', strokeHint: 'Single vertical stroke'),
  _HangeulChar(character: 'ㅐ', romanization: 'ae',  type: 'vowel', strokeHint: 'Vertical with two horizontals'),
  _HangeulChar(character: 'ㅔ', romanization: 'e',   type: 'vowel', strokeHint: 'Vertical with horizontal left + right'),
];

class HangeulTracingScreen extends ConsumerStatefulWidget {
  const HangeulTracingScreen({super.key});
  @override
  ConsumerState<HangeulTracingScreen> createState() => _HangeulTracingScreenState();
}

class _HangeulTracingScreenState extends ConsumerState<HangeulTracingScreen> {
  bool _showConsonants = true;
  int _index = 0;
  List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  List<_HangeulChar> get _chars => _showConsonants ? _consonants : _vowels;
  _HangeulChar get _current => _chars[_index];

  void _next() {
    if (_index + 1 >= _chars.length) {
      setState(() {
        _index = 0;
        _strokes = [];
        _currentStroke = [];
      });
    } else {
      setState(() {
        _index++;
        _strokes = [];
        _currentStroke = [];
      });
    }
  }

  void _clear() => setState(() { _strokes = []; _currentStroke = []; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Hangeul Writing'),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: _clear,
            child: const Text('Clear', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Consonant / Vowel toggle
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                _TypeTab(label: 'Consonants', active: _showConsonants,
                  onTap: () => setState(() { _showConsonants = true; _index = 0; _strokes = []; })),
                _TypeTab(label: 'Vowels', active: !_showConsonants,
                  onTap: () => setState(() { _showConsonants = false; _index = 0; _strokes = []; })),
              ]),
            ),
          ),

          // Character indicator
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _chars.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() { _index = i; _strokes = []; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.primary
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: i == _index ? AppColors.primary : AppColors.border),
                  ),
                  child: Center(child: Text(_chars[i].character,
                    style: TextStyle(
                      fontFamily: 'NotoSansKR',
                      fontSize: 18,
                      color: i == _index ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ))),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Current char info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(children: [
              Text(_current.character,
                style: const TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(width: AppSpacing.md),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('[${_current.romanization}]',
                  style: const TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.w600)),
                Text(_current.strokeHint,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Drawing canvas
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  child: Stack(children: [
                    // Guide character (faded)
                    Center(child: Text(_current.character,
                      style: TextStyle(
                        fontFamily: 'NotoSansKR',
                        fontSize: 200,
                        color: AppColors.primary.withOpacity(0.06),
                        fontWeight: FontWeight.w700,
                      ))),
                    // Drawing
                    GestureDetector(
                      onPanStart: (d) => setState(() => _currentStroke = [d.localPosition]),
                      onPanUpdate: (d) => setState(() => _currentStroke.add(d.localPosition)),
                      onPanEnd: (_) => setState(() {
                        _strokes.add(List.from(_currentStroke));
                        _currentStroke = [];
                      }),
                      child: CustomPaint(
                        painter: _StrokePainter(
                          strokes: _strokes,
                          currentStroke: _currentStroke,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          // Buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg,
              AppSpacing.lg + MediaQuery.of(context).padding.bottom),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_index + 1 >= _chars.length ? 'Restart' : 'Next'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: active ? Colors.white : AppColors.textSecondary))),
      ),
    ),
  );
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  const _StrokePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in [...strokes, currentStroke]) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (final pt in stroke.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}
