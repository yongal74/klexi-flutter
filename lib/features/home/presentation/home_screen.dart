import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/user_level_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/daily_session_service.dart';
import '../../../core/services/purchase_service.dart';
import '../../../data/repositories/word_repository.dart';

export '../../../core/providers/user_level_provider.dart' show userTopikLevelProvider;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _streak = 0;
  int _totalLearned = 0;
  int _todayStudied = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(dailySessionServiceProvider);
    // 병렬 호출로 성능 최적화 — setState는 1회만
    final results = await Future.wait([
      session.getCurrentStreak(),
      session.getTotalWordsStudied(),
      session.getTodayStudiedCount(),
    ]);
    if (mounted) {
      setState(() {
        _streak = results[0];
        _totalLearned = results[1];
        _todayStudied = results[2];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    // Live-update today's count when words are studied
    final liveCount = ref.watch(todayStudiedCountProvider);
    final todayStudied = liveCount > 0 ? liveCount : _todayStudied;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8)),
                child: const Center(
                  child: Text('K', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)))),
              const SizedBox(width: 8),
              const Text('Klexi', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ]),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
                onPressed: () => context.push(AppRoutes.notifSettings),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.settings),
                  child: user?.photoUrl != null
                      ? CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(user!.photoUrl!),
                          onBackgroundImageError: (_, __) {},
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(
                            user?.displayName?.substring(0, 1).toUpperCase() ?? 'G',
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ── Stats row ──────────────────────────────
              _StatsRow(streak: _streak, learned: _totalLearned, todayStudied: todayStudied),
              const SizedBox(height: AppSpacing.sm),

              // ── TOPIK Level selector ───────────────────
              const _LevelSelector(),
              const SizedBox(height: AppSpacing.listGap),

              // ── Today's session card ───────────────────
              _TodayCard(onStart: () => context.push(AppRoutes.dailySession)),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Quick actions ─────────────────────────
              const Text('Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              _QuickActionsGrid(),

              // ── Sentence spotlight ─────────────────────
              const SizedBox(height: AppSpacing.sectionGap),
              _SentenceSpotlight(),
              const SizedBox(height: 32),
            ])),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int streak;
  final int learned;
  final int todayStudied;
  const _StatsRow({required this.streak, required this.learned, required this.todayStudied});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: _StatCard(value: '$streak', label: 'Day Streak', icon: '🔥', color: AppColors.streak)),
      const SizedBox(width: AppSpacing.listGap),
      Expanded(child: _StatCard(value: '$learned', label: 'Words Learned', icon: '📚', color: AppColors.primary)),
      const SizedBox(width: AppSpacing.listGap),
      Expanded(child: _StatCard(value: '$todayStudied/20', label: "Today's Goal", icon: '🎯', color: AppColors.success)),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.subtleShadow,
    ),
    child: Column(children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(
        fontSize: 10, color: AppColors.textSecondary)),
    ]),
  );
}

// ── Today Card ────────────────────────────────────────────
class _TodayCard extends StatelessWidget {
  final VoidCallback onStart;
  const _TodayCard({required this.onStart});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
    ),
    padding: const EdgeInsets.all(AppSpacing.cardPadLg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text("Today's Session",
          style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        const Text('Daily Session', style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Sentence-first learning', style: TextStyle(
          fontSize: 13, color: Colors.white.withOpacity(0.7))),
        const SizedBox(height: AppSpacing.lg),
        GestureDetector(
          onTap: onStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            child: const Text('Start Learning',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ),
      ],
    ),
  );
}

// ── Quick Actions Grid ────────────────────────────────────
class _QuickActionsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final actions = [
      (label: 'Word Network',   color: AppColors.primary,  route: AppRoutes.wordNetwork,  pro: false),
      (label: 'Chat with Dalli',color: AppColors.accent,   route: AppRoutes.dalliChat,    pro: true),
      (label: 'Grammar',        color: AppColors.topik4,   route: AppRoutes.grammar,      pro: true),
      (label: 'Themes',         color: AppColors.topik5,   route: AppRoutes.themes,       pro: true),
      (label: 'Pronunciation',  color: AppColors.topik3,   route: AppRoutes.pronunciation,pro: true),
      (label: 'Hangeul',        color: AppColors.topik2,   route: AppRoutes.hangeul,      pro: false),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.listGap,
      mainAxisSpacing: AppSpacing.listGap,
      childAspectRatio: 1.8,
      children: actions.map((a) {
        final locked = a.pro && !isPremium;
        return _QuickAction(
          label: a.label, color: a.color, locked: locked,
          onTap: () {
            if (locked) {
              context.push(AppRoutes.premium);
            } else {
              context.push(a.route);
            }
          },
        );
      }).toList(),
    );
  }
}

// ── Quick Action ──────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final String label;
  final Color color;
  final bool locked;
  final VoidCallback onTap;
  const _QuickAction({
    required this.label, required this.color,
    required this.onTap, this.locked = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: locked
              ? [AppColors.textMuted.withOpacity(0.3), AppColors.textMuted.withOpacity(0.4)]
              : [color.withOpacity(0.85), color],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: [
          BoxShadow(
            color: (locked ? AppColors.textMuted : color).withOpacity(0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: locked ? Colors.white54 : Colors.white),
            maxLines: 1))),
        locked
            ? const Icon(Icons.lock_rounded, size: 14, color: Colors.white38)
            : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
      ]),
    ),
  );
}

// ── TOPIK Level Selector ─────────────────────────────────
class _LevelSelector extends ConsumerWidget {
  const _LevelSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLevel = ref.watch(userTopikLevelProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(6, (i) {
          final lvl = i + 1;
          final locked = lvl > 1 && !isPremium;
          final selected = lvl == currentLevel;
          return GestureDetector(
            onTap: () {
              if (locked) {
                context.push(AppRoutes.premium);
              } else {
                ref.read(userTopikLevelProvider.notifier).setLevel(lvl);
                AnalyticsService.instance.logLevelChanged(level: lvl);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TOPIK $lvl',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : (locked ? AppColors.textMuted : AppColors.textSecondary),
                    )),
                  if (locked) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_rounded, size: 10, color: AppColors.textMuted),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Sentence Spotlight ────────────────────────────────────
class _SentenceSpotlight extends ConsumerStatefulWidget {
  const _SentenceSpotlight();

  @override
  ConsumerState<_SentenceSpotlight> createState() => _SentenceSpotlightState();
}

class _SentenceSpotlightState extends ConsumerState<_SentenceSpotlight> {
  late final PageController _pageCtrl;
  int _page = 0;
  int? _cachedLevel;
  List<dynamic> _cachedWords = [];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// From a level's 1200 words, batch into groups of 20 per day.
  /// Each day show 7 evenly-spaced words from that day's batch.
  /// Full cycle: 1200 / 20 = 60 days.
  List<dynamic> _todayWords(List<dynamic> levelWords) {
    if (levelWords.isEmpty) return [];
    const batchSize = 20;
    final groupCount = (levelWords.length / batchSize).ceil();
    final dayIndex = AppConfig.daySeed;
    final groupIdx = dayIndex % groupCount;
    final start = groupIdx * batchSize;
    final end = (start + batchSize).clamp(0, levelWords.length);
    final batch = levelWords.sublist(start, end);
    // Pick 7 evenly-spaced indices from batch
    const picks = [0, 3, 6, 9, 12, 15, 18];
    return picks.where((p) => p < batch.length).map((p) => batch[p]).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userLevel = ref.watch(userTopikLevelProvider);
    if (_cachedLevel != userLevel) {
      final repo = ref.read(wordRepositoryProvider);
      final levelWords = repo.getAllWords().where((w) => w.level == userLevel).toList();
      _cachedWords = _todayWords(levelWords);
      _cachedLevel = userLevel;
    }
    final words = _cachedWords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sentence Spotlight',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 175,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: words.isEmpty ? 1 : words.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              if (words.isEmpty) {
                return _buildEmptyCard();
              }
              return _buildWordCard(words[i]);
            },
          ),
        ),
        if (words.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(child: _buildDots(words.length)),
          ),
      ],
    );
  }

  Widget _buildWordCard(dynamic word) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.topikBg(word.level),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
              child: Text('TOPIK ${word.level}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.topikColor(word.level))),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Text(word.example,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'NotoSansKR',
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary, height: 1.5)),
          ),
          const SizedBox(height: 4),
          Text(word.exampleTranslation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: AppSpacing.sm),
          _WordChip(word.korean),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 2),
    padding: const EdgeInsets.all(AppSpacing.cardPad),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      border: Border.all(color: AppColors.border),
    ),
    child: const Center(
      child: Text('Start a study session to see sentences here.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
    ),
  );

  Widget _buildDots(int count) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(count, (i) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: i == _page ? 14 : 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: i == _page ? AppColors.primary : AppColors.border,
        borderRadius: BorderRadius.circular(3),
      ),
    )),
  );
}

class _WordChip extends StatelessWidget {
  final String text;
  const _WordChip(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.chipPadH, vertical: AppSpacing.chipPadV),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
    ),
    child: Text(text, style: const TextStyle(
      fontFamily: 'NotoSansKR',
      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
  );
}
