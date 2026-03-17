// lib/features/word_network/presentation/word_network_screen.dart
// Word Network v3 — spatial-grid physics, Ticker animation, ambient motion,
// topic color coding, 1200-node default / full level on filter

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

// ── Node ───────────────────────────────────────────────────────────────────

class _Node {
  final Word word;
  final Offset basePos; // immutable sunflower position
  Offset pos;          // current pos (basePos + ambient wobble or drag)
  bool pinned;

  _Node({required this.word, required Offset pos})
      : basePos = pos,
        pos = pos,
        pinned = false;
}

// ── Topic color palette (cycles through 12 colors) ───────────────────────

const List<Color> _kTopicColors = [
  Color(0xFF667EEA), Color(0xFFFF8C42), Color(0xFF48C774), Color(0xFFFF3860),
  Color(0xFF00B4D8), Color(0xFFFFD166), Color(0xFFEF476F), Color(0xFF06D6A0),
  Color(0xFF118AB2), Color(0xFFFF6B6B), Color(0xFF8338EC), Color(0xFFFF9F1C),
];

// ── Screen ─────────────────────────────────────────────────────────────────

class WordNetworkScreen extends ConsumerStatefulWidget {
  const WordNetworkScreen({super.key});

  @override
  ConsumerState<WordNetworkScreen> createState() =>
      _WordNetworkScreenState();
}

class _WordNetworkScreenState extends ConsumerState<WordNetworkScreen>
    with SingleTickerProviderStateMixin {
  // All nodes in memory
  List<_Node> _nodes = [];
  bool _loading = true;

  // Viewport
  double _scale = 1.0;
  Offset _pan = Offset.zero;
  double _scaleStart = 1.0;
  Offset _panStart = Offset.zero;

  // Filter state
  int _levelFilter = 0;
  String _groupBy = 'level';
  String _topicFilter = '';
  List<String> _allCategories = [];
  Map<String, Color> _topicColorMap = {};

  // Selection / drag
  _Node? _selected;
  _Node? _draggedNode;
  Offset? _hoverPos;

  // Physics ticker (replaces AnimationController.addListener)
  late Ticker _ticker;
  int _tick = 0;
  final math.Random _rng = math.Random(42);

  // Search
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;

  // Stats — always show total, not just visible
  int _totalWordCount = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadWords();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────

  void _loadWords() {
    final repo = ref.read(wordRepositoryProvider);
    final all = repo.getAllWords();
    _totalWordCount = all.length;

    // Build category → color map
    final cats = all.map((w) => w.category).where((c) => c.isNotEmpty)
        .toSet().toList()..sort();
    _allCategories = cats;
    _topicColorMap = {
      for (var i = 0; i < cats.length; i++)
        cats[i]: _kTopicColors[i % _kTopicColors.length]
    };

    _buildNodes(all);
  }

  void _buildNodes(List<Word> all) {
    // All levels: 1200 per level = 7200 total. Single level: all words.
    final sampled = <Word>[];
    for (var lvl = 1; lvl <= 6; lvl++) {
      if (_levelFilter != 0 && lvl != _levelFilter) continue;
      final lvlWords = all.where((w) => w.level == lvl).toList()
        ..shuffle(_rng);
      sampled.addAll(_levelFilter == 0
          ? lvlWords.take(1200)
          : lvlWords);
    }

    // Shuffle so levels are interspersed throughout the sphere
    sampled.shuffle(_rng);

    // ── Sunflower phyllotaxis — single disc, radius 1100px ──
    const center = Offset(2000, 2000);
    const goldenAngle = 2.399963;
    final total = sampled.length;

    final nodes = List.generate(total, (i) {
      final r = 30.0 + 1100.0 * math.sqrt(i / total);
      final angle = i * goldenAngle;
      return _Node(
        word: sampled[i],
        pos: center + Offset(r * math.cos(angle), r * math.sin(angle)),
      );
    });

    setState(() {
      _nodes = nodes;
      _loading = false;
      _tick = 0;
    });

    _resetView();
  }

  void _resetView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      setState(() {
        // fit 2200px sphere into screen with some margin
        _scale = (_levelFilter == 0
            ? (size.shortestSide * 0.9) / 2200.0
            : (size.shortestSide * 0.9) / 2400.0).clamp(0.08, 1.0);
        _pan = Offset(
          size.width / 2 - 2000.0 * _scale,
          size.height / 2 - 2000.0 * _scale,
        );
      });
    });
  }

  // ── Ambient tick — pure sine wobble, no physics ───────────
  // O(n) simple math: each node oscillates gently around its basePos

  void _onTick(Duration elapsed) {
    if (!mounted || _nodes.isEmpty) return;
    _tick++;
    // Only repaint every 3rd frame to save CPU with 7200 nodes
    if (_tick % 3 != 0) return;

    final t = elapsed.inMilliseconds / 1000.0;
    setState(() {
      for (final n in _nodes) {
        if (n.pinned) continue;
        final h = n.word.id.hashCode;
        // Each node drifts on its own phase — ±4px gentle oscillation
        final dx = math.sin(t * 0.25 + h * 0.009) * 4.0;
        final dy = math.cos(t * 0.30 + h * 0.011) * 4.0;
        n.pos = n.basePos + Offset(dx, dy);
      }
    });
  }

  // ── Filtered view ─────────────────────────────────────────

  List<_Node> get _visibleNodes {
    var nodes = _levelFilter == 0
        ? _nodes
        : _nodes.where((n) => n.word.level == _levelFilter).toList();

    if (_topicFilter.isNotEmpty) {
      nodes = nodes.where((n) => n.word.category == _topicFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      nodes = nodes
          .where((n) =>
              n.word.korean.contains(q) ||
              n.word.english.toLowerCase().contains(q))
          .toList();
    }
    return nodes;
  }

  // ── Gestures ──────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    final graphPos = _screenToGraph(d.focalPoint);
    // Hit radius: at least 24 screen-pixels converted to graph space
    final extraHit = math.max(24.0 / _scale, 12.0);
    final hit = _visibleNodes.cast<_Node?>().firstWhere(
      (n) => (n!.pos - graphPos).distance < _nodeRadius(n.word) + extraHit,
      orElse: () => null,
    );
    if (hit != null) {
      _draggedNode = hit;
      hit.pinned = true;
    } else {
      _draggedNode = null;
      _scaleStart = _scale;
      _panStart = d.focalPoint - _pan;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_draggedNode != null) {
      setState(() {
        _draggedNode!.pos = _screenToGraph(d.focalPoint);
      });
    } else {
      setState(() {
        _scale = (_scaleStart * d.scale).clamp(0.08, 6.0);
        _pan = d.focalPoint - _panStart;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _draggedNode?.pinned = false;
    _draggedNode = null;
  }


  void _onTapUp(TapUpDetails d) {
    if (_draggedNode != null) return;
    final graphPos = _screenToGraph(d.localPosition);
    final extraHit = math.max(24.0 / _scale, 12.0);
    final hit = _visibleNodes.cast<_Node?>().firstWhere(
      (n) => (n!.pos - graphPos).distance < _nodeRadius(n.word) + extraHit,
      orElse: () => null,
    );
    setState(() => _selected = hit == _selected ? null : hit);
  }

  // Mouse wheel zoom — zoom towards cursor position
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
      final newScale = (_scale * zoomFactor).clamp(0.08, 6.0);
      // Zoom towards cursor
      final focalGraph = _screenToGraph(event.localPosition);
      setState(() {
        _scale = newScale;
        _pan = event.localPosition - focalGraph * _scale;
      });
    }
  }

  Offset _screenToGraph(Offset screen) => (screen - _pan) / _scale;

  double _nodeRadius(Word w) {
    if (_selected?.word.id == w.id) return 18.0;
    // Obsidian-style: small dots, size by level importance
    if (w.level == 1) return 6.0;
    if (w.level == 2) return 5.5;
    return 4.0 + (6 - w.level) * 0.3;
  }

  Color _nodeColor(_Node n) {
    if (_groupBy == 'category' && n.word.category.isNotEmpty) {
      return _topicColorMap[n.word.category] ?? AppColors.topikColor(n.word.level);
    }
    return AppColors.topikColor(n.word.level);
  }

  // ── Level change: reload nodes ────────────────────────────

  void _changeLevel(int lvl) {
    final repo = ref.read(wordRepositoryProvider);
    setState(() { _levelFilter = lvl; _topicFilter = ''; _tick = 0; });
    _buildNodes(repo.getAllWords());
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A18),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(children: [
              // Canvas
              Listener(
                onPointerSignal: _onPointerSignal,
                child: MouseRegion(
                onHover: (e) => setState(() => _hoverPos = e.localPosition),
                onExit: (_) => setState(() => _hoverPos = null),
                child: GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  onTapUp: _onTapUp,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GraphPainter(
                        nodes: _visibleNodes,
                        selected: _selected,
                        dragged: _draggedNode,
                        groupBy: _groupBy,
                        scale: _scale,
                        pan: _pan,
                        hoverPos: _hoverPos,
                        nodeColorFn: _nodeColor,
                        nodeRadiusFn: _nodeRadius,
                        topicColorMap: _topicColorMap,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              ),

              // Filter bar
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
                left: 0, right: 0,
                child: _FilterBar(
                  levelFilter: _levelFilter,
                  groupBy: _groupBy,
                  topicFilter: _topicFilter,
                  categories: _allCategories,
                  topicColorMap: _topicColorMap,
                  onLevelChanged: _changeLevel,
                  onGroupChanged: (v) => setState(() {
                    _groupBy = v;
                    _topicFilter = '';
                    _tick = 0;
                  }),
                  onTopicChanged: (v) => setState(() {
                    _topicFilter = v;
                    _tick = 0;
                  }),
                ),
              ),

              // Stats
              Positioned(
                top: kToolbarHeight +
                    MediaQuery.of(context).padding.top +
                    (_groupBy == 'category' ? 96 : 52),
                right: 16,
                child: _StatsChip(
                  visible: _visibleNodes.length,
                  total: _totalWordCount,
                ),
              ),

              // Word detail panel
              if (_selected != null)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _WordPanel(
                    node: _selected!,
                    allNodes: _visibleNodes,
                    nodeColorFn: _nodeColor,
                    onClose: () => setState(() => _selected = null),
                    onLearn: () {
                      final id = _selected!.word.id;
                      setState(() => _selected = null);
                      context.push('${AppRoutes.wordCard}?id=$id');
                    },
                    onSelectRelated: (n) => setState(() => _selected = n),
                  ),
                ),

              // Hint
              if (_selected == null)
                Positioned(
                  bottom: 20, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                          'Scroll/pinch to zoom · Drag to pan · Drag nodes · Tap to select',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ),
                  ),
                ),

              // Search panel
              if (_showSearch)
                Positioned(
                  top: kToolbarHeight +
                      MediaQuery.of(context).padding.top + 4,
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
                          prefixIcon: Icon(Icons.search,
                              color: Colors.white38),
                        ),
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
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
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search,
                color: Colors.white70),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchCtrl.clear();
                _searchQuery = '';
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong,
                color: Colors.white70),
            tooltip: 'Reset view',
            onPressed: () {
              setState(() { _scale = 1.0; _pan = Offset.zero; });
              _resetView();
            },
          ),
        ],
      );
}

// ── Painter ─────────────────────────────────────────────────────────────────

class _GraphPainter extends CustomPainter {
  final List<_Node> nodes;
  final _Node? selected;
  final _Node? dragged;
  final String groupBy;
  final double scale;
  final Offset pan;
  final Offset? hoverPos;
  final Color Function(_Node) nodeColorFn;
  final double Function(Word) nodeRadiusFn;
  final Map<String, Color> topicColorMap;

  _GraphPainter({
    required this.nodes,
    required this.selected,
    required this.dragged,
    required this.groupBy,
    required this.scale,
    required this.pan,
    required this.hoverPos,
    required this.nodeColorFn,
    required this.nodeRadiusFn,
    required this.topicColorMap,
  });

  Offset _proj(Offset p) => p * scale + pan;

  _Node? get _hovered {
    if (hoverPos == null) return null;
    final gp = (hoverPos! - pan) / scale;
    final extraHit = math.max(20.0 / scale, 10.0);
    return nodes.cast<_Node?>().firstWhere(
      (n) => (n!.pos - gp).distance < nodeRadiusFn(n.word) + extraHit,
      orElse: () => null,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;
    final hov = _hovered;
    final ep = Paint()..style = PaintingStyle.stroke;

    // Edges
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final np = _proj(n.pos);
      if (np.dx < -120 || np.dx > size.width + 120 ||
          np.dy < -120 || np.dy > size.height + 120) continue;

      for (int j = i + 1; j < nodes.length; j++) {
        final m = nodes[j];
        final mp = _proj(m.pos);
        if ((np - mp).distance > 280) continue;

        final isRelated = n.word.relatedIds.contains(m.word.id) ||
            m.word.relatedIds.contains(n.word.id);
        final nc = nodeColorFn(n);
        final sameGroup = groupBy == 'level'
            ? n.word.level == m.word.level
            : n.word.category == m.word.category;

        if (isRelated) {
          ep
            ..color = nc.withOpacity(0.70)
            ..strokeWidth = 1.2;
          _dashed(canvas, np, mp, ep);
        } else if (sameGroup && (np - mp).distance < 200) {
          ep
            ..color = nc.withOpacity(0.22)
            ..strokeWidth = 0.7;
          canvas.drawLine(np, mp, ep);
        }
      }
    }

    // Nodes
    for (final n in nodes) {
      final p = _proj(n.pos);
      if (p.dx < -60 || p.dx > size.width + 60 ||
          p.dy < -60 || p.dy > size.height + 60) continue;

      final color = nodeColorFn(n);
      final r = nodeRadiusFn(n.word);
      final isSel = selected?.word.id == n.word.id;
      final isHov = hov?.word.id == n.word.id;
      final isDrag = dragged?.word.id == n.word.id;
      final highlight = isSel || isHov || isDrag;

      if (highlight) {
        canvas.drawCircle(p, r + 14,
            Paint()..color = color.withOpacity(0.14));
        canvas.drawCircle(p, r + 7,
            Paint()..color = color.withOpacity(0.22));
      }

      canvas.drawCircle(
        p, r,
        Paint()..color = (isSel || isDrag) ? color : color.withOpacity(isHov ? 0.88 : 0.68),
      );
      canvas.drawCircle(
        p, r,
        Paint()
          ..color = highlight
              ? Colors.white.withOpacity(0.45)
              : color.withOpacity(0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );

      // Obsidian style: show Korean label only when selected, hovered, or zoomed in
      final showLabel = isSel || isHov || isDrag || scale > 2.5;
      if (showLabel) {
        final fs = isSel ? 13.0 : (scale > 4.0 ? 11.0 : 9.0);
        final tp = TextPainter(
          text: TextSpan(
            text: n.word.korean,
            style: TextStyle(
              fontFamily: 'NotoSansKR',
              fontSize: fs,
              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 80);
        // Draw label below dot (not inside — dot is small)
        tp.paint(canvas, p + Offset(-tp.width / 2, r + 2));
      }

      if (isSel || (isHov && scale > 1.0)) {
        final et = TextPainter(
          text: TextSpan(
            text: n.word.english,
            style: TextStyle(
                fontSize: 8.0, color: Colors.white.withOpacity(0.55)),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 90);
        final labelOffset = showLabel ? 14.0 : r + 2;
        et.paint(canvas, p + Offset(-et.width / 2, r + labelOffset));
      }
    }
  }

  void _dashed(Canvas c, Offset p1, Offset p2, Paint paint) {
    final d = (p2 - p1).distance;
    if (d < 1) return;
    final u = (p2 - p1) / d;
    var done = 0.0;
    var draw = true;
    var cur = p1;
    while (done < d) {
      final seg = (draw ? 5.0 : 4.0).clamp(0.0, d - done);
      if (draw) c.drawLine(cur, cur + u * seg, paint);
      cur += u * seg;
      done += seg;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}

// ── Filter Bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final int levelFilter;
  final String groupBy;
  final String topicFilter;
  final List<String> categories;
  final Map<String, Color> topicColorMap;
  final ValueChanged<int> onLevelChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onTopicChanged;

  const _FilterBar({
    required this.levelFilter,
    required this.groupBy,
    required this.topicFilter,
    required this.categories,
    required this.topicColorMap,
    required this.onLevelChanged,
    required this.onGroupChanged,
    required this.onTopicChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1 — group + level
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _Chip('By Level', groupBy == 'level',
                () => onGroupChanged('level'), const Color(0xFF667EEA)),
            const SizedBox(width: 6),
            _Chip('By Topic', groupBy == 'category',
                () => onGroupChanged('category'), const Color(0xFFFF8C42)),
            const SizedBox(width: 10),
            Container(width: 1, height: 18, color: Colors.white12),
            const SizedBox(width: 10),
            _Chip('All', levelFilter == 0,
                () => onLevelChanged(0), Colors.white54),
            ...List.generate(6, (i) {
              final c = AppColors.topikColor(i + 1);
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _Chip('L${i + 1}', levelFilter == i + 1,
                    () => onLevelChanged(i + 1), c),
              );
            }),
          ]),
        ),

        // Row 2 — topic chips (when By Topic selected)
        if (groupBy == 'category' && categories.isNotEmpty) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              _Chip('All Topics', topicFilter.isEmpty,
                  () => onTopicChanged(''), const Color(0xFFFF8C42)),
              ...categories.map((cat) {
                final color =
                    topicColorMap[cat] ?? const Color(0xFFFF8C42);
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _Chip(
                    cat,
                    topicFilter == cat,
                    () => onTopicChanged(topicFilter == cat ? '' : cat),
                    color,
                  ),
                );
              }),
            ]),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color color;
  const _Chip(this.label, this.active, this.onTap, this.color);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: active ? color : color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? color : color.withOpacity(0.25)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : color)),
        ),
      );
}

// ── Stats Chip ──────────────────────────────────────────────────────────────

class _StatsChip extends StatelessWidget {
  final int visible;
  final int total;
  const _StatsChip({required this.visible, required this.total});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          visible == total ? '$total words' : '$visible / $total',
          style: const TextStyle(
              color: Colors.white54, fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
      );
}

// ── Word Panel ──────────────────────────────────────────────────────────────

class _WordPanel extends StatelessWidget {
  final _Node node;
  final List<_Node> allNodes;
  final Color Function(_Node) nodeColorFn;
  final VoidCallback onClose;
  final VoidCallback onLearn;
  final ValueChanged<_Node> onSelectRelated;

  const _WordPanel({
    required this.node,
    required this.allNodes,
    required this.nodeColorFn,
    required this.onClose,
    required this.onLearn,
    required this.onSelectRelated,
  });

  @override
  Widget build(BuildContext context) {
    final w = node.word;
    final color = nodeColorFn(node);
    final related =
        allNodes.where((n) => w.relatedIds.contains(n.word.id)).toList();
    final sameLevel = allNodes
        .where((n) => n.word.id != w.id && n.word.level == w.level)
        .take(6)
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF10132A),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            top: BorderSide(color: color.withOpacity(0.35), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _tag('TOPIK ${w.level}', AppColors.topikColor(w.level)),
            if (w.category.isNotEmpty) ...[
              const SizedBox(width: 6),
              _tag(w.category, color),
            ],
            const Spacer(),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, color: Colors.white38, size: 20)),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(w.korean,
                style: const TextStyle(
                    fontFamily: 'NotoSansKR',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(w.english,
                    style: const TextStyle(
                        fontSize: 16, color: Colors.white60)),
              ),
            ),
          ]),
          if (w.pronunciation.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('[${w.pronunciation}]',
                style: TextStyle(
                    fontSize: 13, color: color.withOpacity(0.8))),
          ],
          const SizedBox(height: 8),
          Text(w.example,
              style: TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                  height: 1.6)),

          if (related.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Related',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            Wrap(
                spacing: 7, runSpacing: 5,
                children: related
                    .map((n) => GestureDetector(
                          onTap: () => onSelectRelated(n),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  nodeColorFn(n).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(n.word.korean,
                                style: TextStyle(
                                    fontFamily: 'NotoSansKR',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: nodeColorFn(n))),
                          ),
                        ))
                    .toList()),
          ],

          if (sameLevel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Same TOPIK ${w.level}',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            Wrap(
                spacing: 5, runSpacing: 5,
                children: sameLevel
                    .map((n) => GestureDetector(
                          onTap: () => onSelectRelated(n),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(n.word.korean,
                                style: TextStyle(
                                    fontFamily: 'NotoSansKR',
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.5))),
                          ),
                        ))
                    .toList()),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onLearn,
              icon: const Icon(Icons.menu_book_rounded, size: 15),
              label: const Text('Learn this word'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 14),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
      );
}
