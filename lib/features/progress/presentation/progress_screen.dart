// lib/features/progress/presentation/progress_screen.dart

import 'package:flutter/material.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  // Mock data — replace with DailySessionService calls
  static const int _streak = 7;
  static const int _totalWords = 248;
  static const List<int> _weekActivity = [20, 20, 15, 20, 0, 20, 18]; // Mon→Sun
  static const List<_LevelStat> _levels = [
    _LevelStat(level: 1, label: 'TOPIK 1', words: 1200, studied: 1200, color: Color(0xFF4ADE80)),
    _LevelStat(level: 2, label: 'TOPIK 2', words: 1200, studied: 780, color: Color(0xFF60A5FA)),
    _LevelStat(level: 3, label: 'TOPIK 3', words: 1200, studied: 240, color: Color(0xFF818CF8)),
    _LevelStat(level: 4, label: 'TOPIK 4', words: 1200, studied: 48, color: Color(0xFFA78BFA)),
    _LevelStat(level: 5, label: 'TOPIK 5', words: 1200, studied: 0, color: Color(0xFFF472B6)),
    _LevelStat(level: 6, label: 'TOPIK 6', words: 1200, studied: 0, color: Color(0xFFFB923C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F8),
        elevation: 0,
        title: const Text(
          'Progress',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _StatsRow(streak: _streak, totalWords: _totalWords),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Weekly Activity'),
            const SizedBox(height: 12),
            _WeeklyGrid(activity: _weekActivity),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Level Breakdown'),
            const SizedBox(height: 12),
            _LevelChart(levels: _levels),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Stats Row ──────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int streak;
  final int totalWords;
  const _StatsRow({required this.streak, required this.totalWords});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            emoji: '🔥',
            value: '$streak',
            label: 'Day Streak',
            bgColor: const Color(0xFFFFF4E6),
            valueColor: const Color(0xFFFF8C42),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            emoji: '📚',
            value: '$totalWords',
            label: 'Words Learned',
            bgColor: const Color(0xFFEEF1FF),
            valueColor: const Color(0xFF667EEA),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color bgColor;
  final Color valueColor;

  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.bgColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly Activity Grid ───────────────────────────────────────

class _WeeklyGrid extends StatelessWidget {
  final List<int> activity; // 7 values, words studied per day
  const _WeeklyGrid({required this.activity});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final maxVal = activity.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final val = activity[i];
          final frac = maxVal > 0 ? val / maxVal : 0.0;
          final isToday = i == 6;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                val > 0 ? '$val' : '',
                style: TextStyle(
                  fontSize: 11,
                  color: isToday
                      ? const Color(0xFF667EEA)
                      : const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 28,
                height: 80 * frac + 4,
                decoration: BoxDecoration(
                  color: val > 0
                      ? (isToday
                          ? const Color(0xFF667EEA)
                          : const Color(0xFF667EEA).withOpacity(0.35))
                      : const Color(0xFFEEF0F6),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _days[i],
                style: TextStyle(
                  fontSize: 11,
                  color: isToday
                      ? const Color(0xFF667EEA)
                      : const Color(0xFF9CA3AF),
                  fontWeight:
                      isToday ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Level Breakdown Chart ──────────────────────────────────────

class _LevelChart extends StatelessWidget {
  final List<_LevelStat> levels;
  const _LevelChart({required this.levels});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: levels
            .map((l) => _LevelBar(stat: l))
            .toList(),
      ),
    );
  }
}

class _LevelStat {
  final int level;
  final String label;
  final int words;
  final int studied;
  final Color color;
  const _LevelStat({
    required this.level,
    required this.label,
    required this.words,
    required this.studied,
    required this.color,
  });
}

class _LevelBar extends StatelessWidget {
  final _LevelStat stat;
  const _LevelBar({required this.stat});

  @override
  Widget build(BuildContext context) {
    final frac = stat.words > 0 ? stat.studied / stat.words : 0.0;
    final pct = (frac * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stat.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                '${stat.studied} / ${stat.words} ($pct%)',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              backgroundColor: const Color(0xFFEEF0F6),
              valueColor: AlwaysStoppedAnimation<Color>(stat.color),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared section title ───────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A2E),
      ),
    );
  }
}
