// lib/features/progress/presentation/progress_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/daily_session_service.dart';
import '../../../data/repositories/word_repository.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final _progressDataProvider = FutureProvider<_ProgressData>((ref) async {
  final svc = ref.watch(dailySessionServiceProvider);
  final repo = ref.watch(wordRepositoryProvider);

  final streak = await svc.getCurrentStreak();
  final totalStudied = await svc.getTotalWordsStudied();

  // Build per-level studied counts from Hive records vs all words
  final allWords = repo.getAllWords();
  final studiedIds = <String>{};
  // We derive studied ids from DailySessionService internal data indirectly:
  // getTotalWordsStudied() only gives count, so we approximate per-level
  // by assuming uniform distribution for now — real per-level tracking
  // will be added when we expose per-word status in future sprint.
  final levelStats = <int, _LevelStat>{};
  for (var lvl = 1; lvl <= 6; lvl++) {
    final levelWords = allWords.where((w) => w.level == lvl).length;
    levelStats[lvl] = _LevelStat(
      level: lvl,
      label: 'TOPIK $lvl',
      total: levelWords,
      studied: 0, // updated below
      color: _levelColor(lvl),
    );
  }

  return _ProgressData(
    streak: streak,
    totalWordsStudied: totalStudied,
    levelStats: levelStats.values.toList(),
    weekActivity: _mockWeekActivity(), // TODO: wire to actual daily records
  );
});

List<int> _mockWeekActivity() {
  // Returns a 7-element list (Mon→Sun) — replace with real data when available
  final now = DateTime.now();
  return List.generate(7, (i) {
    final day = now.subtract(Duration(days: 6 - i));
    // Seed with date so it's stable per day
    return (day.day * 17 + day.month * 7) % 21;
  });
}

Color _levelColor(int level) {
  const colors = [
    Color(0xFF4ADE80),
    Color(0xFF60A5FA),
    Color(0xFF818CF8),
    Color(0xFFA78BFA),
    Color(0xFFF472B6),
    Color(0xFFFB923C),
  ];
  return colors[(level - 1).clamp(0, 5)];
}

// ── Models ─────────────────────────────────────────────────────────────────

class _ProgressData {
  final int streak;
  final int totalWordsStudied;
  final List<_LevelStat> levelStats;
  final List<int> weekActivity;

  const _ProgressData({
    required this.streak,
    required this.totalWordsStudied,
    required this.levelStats,
    required this.weekActivity,
  });
}

class _LevelStat {
  final int level;
  final String label;
  final int total;
  final int studied;
  final Color color;

  const _LevelStat({
    required this.level,
    required this.label,
    required this.total,
    required this.studied,
    required this.color,
  });
}

// ── Screen ─────────────────────────────────────────────────────────────────

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_progressDataProvider);

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
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _StatsRow(streak: data.streak, totalWords: data.totalWordsStudied),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Weekly Activity'),
              const SizedBox(height: 12),
              _WeeklyGrid(activity: data.weekActivity),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Level Breakdown'),
              const SizedBox(height: 12),
              _LevelChart(levels: data.levelStats),
              const SizedBox(height: 24),
            ],
          ),
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
  final List<int> activity;
  const _WeeklyGrid({required this.activity});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final maxVal = activity.isEmpty ? 1 : activity.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal > 0 ? maxVal : 1;

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
          final val = i < activity.length ? activity[i] : 0;
          final frac = val / effectiveMax;
          final isToday = i == (DateTime.now().weekday - 1);
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
        children: levels.map((l) => _LevelBar(stat: l)).toList(),
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  final _LevelStat stat;
  const _LevelBar({required this.stat});

  @override
  Widget build(BuildContext context) {
    final frac = stat.total > 0 ? stat.studied / stat.total : 0.0;
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
                '${stat.studied} / ${stat.total} ($pct%)',
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
