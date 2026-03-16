// lib/features/word_network/presentation/word_network_screen.dart
// Obsidian-style Word Network — interactive force-directed graph
// Features: pan, pinch-to-zoom, spring physics, level/category clustering

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

// ── Node model ────────────────────────────────────────────────────────────

class _Node {
  final Word word;
  Offset pos;
  Offset vel;

  _Node({required this.word, required this.pos})
      : vel = Offset.zero;
}

// ── Physics tick provider ─────────────────────────────────────────────────

const int _kMaxNodes = 150; // cap for perf

// ── Screen ────────────────────────────────────────────────────────────────

class WordNetworkScreen extends ConsumerStatefulWidget {
  const WordNetworkScreen({super.key});

  @override
  ConsumerState<WordNetworkScreen> createState() => _WordNetworkScreenState();
}

class _WordNetworkScreenState extends ConsumerState<WordNetworkScreen>
    with TickerProviderStateMixin {
  // Graph
  List<_Node> _nodes = [];
  bool _loading = true;

  // Viewport
  double _scale = 1.0;
  Offset _pan = Offset.zero;
  Offset _focalPoint = Offset.zero;
  double _scaleStart = 1.0;
  Offset _panStart = Offset.zero;

  // Filter
  int _levelFilter = 0;       // 0 = all levels
  String _groupBy = 'level';  // 'level' | 'category'

  // Selection
  _Node? _selected;

  // Physics animation
  late AnimationController _physicsCtrl;
  int _settleTick = 0;

  // Search
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _physicsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..addListener(_tick);
    _loadWords();
  }

  @override
  void dispose() {
    _physicsCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadWords() {
    final repo = ref.read(wordRepositoryProvider);
    final all = repo.getAllWords();
    final rng = math.Random(42);

    // Sample words — use first N; distribute across levels
    final sampled = <Word>[];
    for (var lvl = 1; lvl <= 6; lvl++) {
      final lvlWords = all.where((w) => w.level == lvl).take(25).toList();
      sampled.addAll(lvlWords);
    }

    final initialNodes = sampled.take(_kMaxNodes).map((w) {
      // Place nodes in a circular initial layout
      final angle = rng.nextDouble() * 2 * math.pi;
      final r = 80.0 + rng.nextDouble() * 200;
      return _Node(
        word: w,
        pos: Offset(400 + r * math.cos(angle), 400 + r * math.sin(angle)),
      );
    }).toList();

    setState(() {
      _nodes = initialNodes;
      _loading = false;
    });

    // Start physics
    _physicsCtrl.forward();
  }

  List<_Node> get _visibleNodes {
    var nodes = _levelFilter == 0
        ? _nodes
        : _nodes.where((n) => n.word.level == _levelFilter).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      nodes = nodes.where((n) =>
          n.word.korean.contains(q) ||
          n.word.english.toLowerCase().contains(q)).toList();
    }

    return nodes;
  }

  // ── Force-directed physics ────────────────────────────────
  void _tick() {
    if (!mounted || _nodes.isEmpty) return;
    _settleTick++;

    // After 300 ticks, slow down physics
    final damping = _settleTick > 300 ? 0.92 : 0.85;
    const repulsion = 1800.0;
    const attraction = 0.012;
    const centerGravity = 0.008;
    const cx = 400.0, cy = 400.0;

    final visible = _visibleNodes;
    if (visible.isEmpty) return;

    setState(() {
      for (final n in visible) {
        var fx = 0.0, fy = 0.0;

        // Repulsion between all pairs
        for (final m in visible) {
          if (identical(n, m)) continue;
          final dx = n.pos.dx - m.pos.dx;
          final dy = n.pos.dy - m.pos.dy;
          final dist = math.sqrt(dx * dx + dy * dy).clamp(10.0, 300.0);
          final force = repulsion / (dist * dist);
          fx += (dx / dist) * force;
          fy += (dy / dist) * force;
        }

        // Group attraction (same level/category attract)
        for (final m in visible) {
          if (identical(n, m)) continue;
          final sameGroup = _groupBy == 'level'
              ? n.word.level == m.word.level
              : n.word.category == m.word.category;
          if (sameGroup) {
            final dx = m.pos.dx - n.pos.dx;
            final dy = m.pos.dy - n.pos.dy;
            final dist = math.sqrt(dx * dx + dy * dy).clamp(10.0, 500.0);
            fx += dx * attraction;
            fy += dy * attraction;
          }
        }

        // Related word attraction (very strong)
        if (n.word.relatedIds.isNotEmpty) {
          for (final relId in n.word.relatedIds) {
            final rel = visible.where((m) => m.word.id == relId).firstOrNull;
            if (rel != null) {
              final dx = rel.pos.dx - n.pos.dx;
              final dy = rel.pos.dy - n.pos.dy;
              fx += dx * 0.05;
              fy += dy * 0.05;
            }
          }
        }

        // Center gravity
        fx += (cx - n.pos.dx) * centerGravity;
        fy += (cy - n.pos.dy) * centerGravity;

        // Update velocity + position
        n.vel = Offset(
          (n.vel.dx + fx * 0.016) * damping,
          (n.vel.dy + fy * 0.016) * damping,
        );
        // Clamp velocity
        final speed = n.vel.distance;
        if (speed > 8) n.vel = n.vel * (8 / speed);

        n.pos = n.pos + n.vel;
      }
    });
  }

  // ── Gesture handlers ──────────────────────────────────────
  void _onScaleStart(ScaleStartDetails d) {
    _scaleStart = _scale;
    _panStart = d.focalPoint - _pan;
    _focalPoint = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _scale = (_scaleStart * d.scale).clamp(0.3, 4.0);
      _pan = d.focalPoint - _panStart;
    });
  }

  void _onTapUp(TapUpDetails d) {
    // Convert screen coords → graph coords
    final graphPos = _screenToGraph(d.localPosition);
    final hit = _visibleNodes.cast<_Node?>().firstWhere(
      (n) => (n!.pos - graphPos).distance < _nodeRadius(n.word) + 8,
      orElse: () => null,
    );
    setState(() => _selected = hit == _selected ? null : hit);
  }

  Offset _screenToGraph(Offset screen) {
    return (screen - _pan) / _scale;
  }

  double _nodeRadius(Word w) {
    if (_selected?.word.id == w.id) return 26.0;
    if (w.level == 1) return 18.0;
    if (w.level == 2) return 16.0;
    return 12.0 + (6 - w.level) * 1.5;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C1A),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(children: [
              // ── Graph canvas ─────────────────────────
              GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onTapUp: _onTapUp,
                child: CustomPaint(
                  painter: _GraphPainter(
                    nodes: _visibleNodes,
                    selected: _selected,
                    groupBy: _groupBy,
                    scale: _scale,
                    pan: _pan,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),

              // ── Filter chips ─────────────────────────
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
                left: 0, right: 0,
                child: _FilterBar(
                  levelFilter: _levelFilter,
                  groupBy: _groupBy,
                  onLevelChanged: (v) => setState(() { _levelFilter = v; _settleTick = 0; }),
                  onGroupChanged: (v) => setState(() { _groupBy = v; _settleTick = 0; }),
                ),
              ),

              // ── Stats overlay (top-right) ─────────────
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 56,
                right: 16,
                child: _StatsChip(nodeCount: _visibleNodes.length),
              ),

              // ── Selected word panel ───────────────────
              if (_selected != null)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _WordPanel(
                    node: _selected!,
                    allNodes: _visibleNodes,
                    onClose: () => setState(() => _selected = null),
                    onLearn: () {
                      final id = _selected!.word.id;
                      setState(() => _selected = null);
                      context.push('${AppRoutes.wordCard}?id=$id');
                    },
                    onSelectRelated: (n) => setState(() => _selected = n),
                  ),
                ),

              // ── Hint ─────────────────────────────────
              if (_selected == null)
                Positioned(
                  bottom: 20, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Pinch to zoom · Drag to pan · Tap a word',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  ),
                ),

              // ── Search panel ─────────────────────────
              if (_showSearch)
                Positioned(
                  top: kToolbarHeight + MediaQuery.of(context).padding.top + 4,
                  left: 16, right: 60,
                  child: Material(
                    color: const Color(0xFF1A1D2E),
                    borderRadius: BorderRadius.circular(12),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search Korean or English…',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: Colors.white38),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                        autofocus: true,
                      ),
                    ),
                  ),
                ),
            ]),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: Colors.white,
    title: const Text('Word Network',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    actions: [
      IconButton(
        icon: Icon(_showSearch ? Icons.close : Icons.search, color: Colors.white70),
        onPressed: () => setState(() {
          _showSearch = !_showSearch;
          if (!_showSearch) {
            _searchCtrl.clear();
            _searchQuery = '';
          }
        }),
      ),
      IconButton(
        icon: const Icon(Icons.center_focus_strong, color: Colors.white70),
        tooltip: 'Reset view',
        onPressed: () => setState(() { _scale = 1.0; _pan = Offset.zero; }),
      ),
    ],
  );
}

// ── Custom Painter ────────────────────────────────────────────────────────

class _GraphPainter extends CustomPainter {
  final List<_Node> nodes;
  final _Node? selected;
  final String groupBy;
  final double scale;
  final Offset pan;

  _GraphPainter({
    required this.nodes,
    required this.selected,
    required this.groupBy,
    required this.scale,
    required this.pan,
  });

  Offset _project(Offset graphPos) => graphPos * scale + pan;

  double _radius(Word w) {
    if (selected?.word.id == w.id) return 26.0;
    if (w.level == 1) return 18.0;
    if (w.level == 2) return 16.0;
    return 12.0 + (6 - w.level) * 1.5;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    // ── Draw edges ──────────────────────────────────────
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final np = _project(n.pos);

      // Only draw edges if node is on screen (perf optimisation)
      if (np.dx < -100 || np.dx > size.width + 100 ||
          np.dy < -100 || np.dy > size.height + 100) continue;

      for (int j = i + 1; j < nodes.length; j++) {
        final m = nodes[j];
        final mp = _project(m.pos);

        final sameGroup = groupBy == 'level'
            ? n.word.level == m.word.level
            : n.word.category == m.word.category;

        final isRelated = n.word.relatedIds.contains(m.word.id) ||
            m.word.relatedIds.contains(n.word.id);

        // Skip edges if too far apart on screen
        if ((np - mp).distance > 250) continue;

        if (isRelated) {
          edgePaint.color = AppColors.topikColor(n.word.level).withOpacity(0.55);
          edgePaint.strokeWidth = 1.5;
        } else if (sameGroup && (np - mp).distance < 160) {
          edgePaint.color = AppColors.topikColor(n.word.level).withOpacity(0.18);
          edgePaint.strokeWidth = 0.7;
        } else {
          continue;
        }

        // Animated dashed line for related words
        if (isRelated) {
          _drawDashedLine(canvas, np, mp, edgePaint);
        } else {
          canvas.drawLine(np, mp, edgePaint);
        }
      }

      // Edges for selected word — highlight connections
      if (selected != null && n.word.id == selected!.word.id) {
        final sp = _project(selected!.pos);
        for (final m in nodes) {
          if (m.word.id == n.word.id) continue;
          final sameLevel = m.word.level == n.word.level;
          if (!sameLevel) continue;
          final mp2 = _project(m.pos);
          final highlightPaint = Paint()
            ..color = AppColors.topikColor(n.word.level).withOpacity(0.35)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke;
          canvas.drawLine(sp, mp2, highlightPaint);
        }
      }
    }

    // ── Draw nodes ──────────────────────────────────────
    for (final n in nodes) {
      final p = _project(n.pos);
      if (p.dx < -50 || p.dx > size.width + 50 ||
          p.dy < -50 || p.dy > size.height + 50) continue;

      final color = AppColors.topikColor(n.word.level);
      final r = _radius(n.word);
      final isSelected = selected?.word.id == n.word.id;

      // Outer glow for selected
      if (isSelected) {
        for (final glowR in [r + 14.0, r + 8.0]) {
          canvas.drawCircle(
            p, glowR,
            Paint()
              ..color = color.withOpacity(0.15)
              ..style = PaintingStyle.fill,
          );
        }
      }

      // Node background
      canvas.drawCircle(
        p, r,
        Paint()
          ..color = isSelected
              ? color
              : color.withOpacity(0.75)
          ..style = PaintingStyle.fill,
      );

      // Node border
      canvas.drawCircle(
        p, r,
        Paint()
          ..color = isSelected
              ? Colors.white.withOpacity(0.4)
              : color.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Text label
      final fontSize = isSelected ? 12.0 : (scale > 1.2 ? 9.0 : 8.0);
      final tp = TextPainter(
        text: TextSpan(
          text: n.word.korean,
          style: TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: fontSize,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 2.5);

      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));

      // English below (only when selected or zoomed in)
      if (isSelected || scale > 1.8) {
        final engTp = TextPainter(
          text: TextSpan(
            text: n.word.english,
            style: TextStyle(
              fontSize: isSelected ? 9.0 : 7.0,
              color: Colors.white.withOpacity(0.65),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: r * 3);
        engTp.paint(canvas, p + Offset(-engTp.width / 2, r + 2));
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    const dashLen = 5.0, gapLen = 4.0;
    var drawn = 0.0;
    var drawing = true;
    final ux = dx / dist, uy = dy / dist;
    var cx = p1.dx, cy = p1.dy;

    while (drawn < dist) {
      final segLen = (drawing ? dashLen : gapLen).clamp(0.0, dist - drawn);
      if (drawing) {
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + ux * segLen, cy + uy * segLen),
          paint,
        );
      }
      cx += ux * segLen;
      cy += uy * segLen;
      drawn += segLen;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}

// ── Filter Bar ────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final int levelFilter;
  final String groupBy;
  final ValueChanged<int> onLevelChanged;
  final ValueChanged<String> onGroupChanged;

  const _FilterBar({
    required this.levelFilter,
    required this.groupBy,
    required this.onLevelChanged,
    required this.onGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        // Group toggle
        _ToggleChip(
          label: 'By Level',
          active: groupBy == 'level',
          onTap: () => onGroupChanged('level'),
          color: const Color(0xFF667EEA),
        ),
        const SizedBox(width: 6),
        _ToggleChip(
          label: 'By Topic',
          active: groupBy == 'category',
          onTap: () => onGroupChanged('category'),
          color: const Color(0xFFFF8C42),
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 20, color: Colors.white12),
        const SizedBox(width: 12),
        // Level filters
        _ToggleChip(label: 'All', active: levelFilter == 0,
          onTap: () => onLevelChanged(0), color: Colors.white54),
        ...List.generate(6, (i) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: _ToggleChip(
            label: 'L${i + 1}',
            active: levelFilter == i + 1,
            onTap: () => onLevelChanged(i + 1),
            color: AppColors.topikColor(i + 1),
          ),
        )),
      ]),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color color;

  const _ToggleChip({
    required this.label, required this.active,
    required this.onTap, required this.color,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? color : color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: active ? Colors.white : color)),
    ),
  );
}

// ── Stats Chip ────────────────────────────────────────────────────────────

class _StatsChip extends StatelessWidget {
  final int nodeCount;
  const _StatsChip({required this.nodeCount});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Text('$nodeCount words',
      style: const TextStyle(
        color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

// ── Word Panel ────────────────────────────────────────────────────────────

class _WordPanel extends StatelessWidget {
  final _Node node;
  final List<_Node> allNodes;
  final VoidCallback onClose;
  final VoidCallback onLearn;
  final ValueChanged<_Node> onSelectRelated;

  const _WordPanel({
    required this.node,
    required this.allNodes,
    required this.onClose,
    required this.onLearn,
    required this.onSelectRelated,
  });

  @override
  Widget build(BuildContext context) {
    final w = node.word;
    final color = AppColors.topikColor(w.level);

    // Related words visible in current graph
    final related = allNodes
        .where((n) => w.relatedIds.contains(n.word.id))
        .toList();

    // Same level words (limited for display)
    final sameLevel = allNodes
        .where((n) => n.word.id != w.id && n.word.level == w.level)
        .take(6)
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF12152A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: color.withOpacity(0.3), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('TOPIK ${w.level} · ${w.partOfSpeech}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, color: Colors.white38, size: 20)),
          ]),
          const SizedBox(height: 12),

          // Korean + English
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(w.korean,
              style: const TextStyle(
                fontFamily: 'NotoSansKR',
                fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(w.english,
                style: const TextStyle(fontSize: 18, color: Colors.white60))),
          ]),
          if (w.pronunciation.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('[${w.pronunciation}]',
              style: TextStyle(fontSize: 14, color: color.withOpacity(0.8))),
          ],
          const SizedBox(height: 8),

          // Example sentence
          Text(w.example,
            style: const TextStyle(
              fontFamily: 'NotoSansKR',
              fontSize: 14, color: Colors.white54, height: 1.6)),

          // Related words
          if (related.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Related', style: TextStyle(
              fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: related.map((n) =>
              GestureDetector(
                onTap: () => onSelectRelated(n),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.topikColor(n.word.level).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(n.word.korean,
                    style: TextStyle(
                      fontFamily: 'NotoSansKR',
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.topikColor(n.word.level))),
                ),
              )).toList(),
            ),
          ],

          // Same level cluster
          if (sameLevel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Same level (TOPIK ${w.level})', style: const TextStyle(
              fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: sameLevel.map((n) =>
              GestureDetector(
                onTap: () => onSelectRelated(n),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(n.word.korean,
                    style: const TextStyle(
                      fontFamily: 'NotoSansKR',
                      fontSize: 12, color: Colors.white54)),
                ),
              )).toList(),
            ),
          ],

          const SizedBox(height: 16),

          // CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onLearn,
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text('Learn this word'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
