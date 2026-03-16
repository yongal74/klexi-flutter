import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/daily_session_service.dart';
import '../../../data/repositories/word_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _streak = 0;
  int _totalLearned = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(dailySessionServiceProvider);
    await session.init();
    final streak = await session.getCurrentStreak();
    final total  = await session.getTotalWordsStudied();
    if (mounted) setState(() { _streak = streak; _totalLearned = total; });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

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
                onPressed: () {},
              ),
              if (user?.photoUrl != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(user!.photoUrl!),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      user?.displayName?.substring(0, 1).toUpperCase() ?? 'G',
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ── Stats row ──────────────────────────────
              _StatsRow(streak: _streak, learned: _totalLearned),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Today's session card ───────────────────
              _TodayCard(onStart: () => context.push(AppRoutes.dailySession)),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Quick actions ─────────────────────────
              const Text('Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.listGap,
                mainAxisSpacing: AppSpacing.listGap,
                childAspectRatio: 1.6,
                children: [
                  _QuickAction(icon: '🕸️', label: 'Word Network',   color: AppColors.primary,  onTap: () => context.push(AppRoutes.wordNetwork)),
                  _QuickAction(icon: '💬', label: 'Chat with Dalli', color: AppColors.accent,   onTap: () => context.push(AppRoutes.dalliChat)),
                  _QuickAction(icon: '✏️', label: 'Grammar',        color: AppColors.topik4,   onTap: () => context.push(AppRoutes.grammar)),
                  _QuickAction(icon: '🎬', label: 'Themes',         color: AppColors.topik5,   onTap: () => context.push(AppRoutes.themes)),
                  _QuickAction(icon: '🙉', label: 'Pronunciation',  color: AppColors.topik3,   onTap: () => context.push(AppRoutes.pronunciation)),
                  _QuickAction(icon: '✍️', label: 'Hangeul',        color: AppColors.topik2,   onTap: () => context.push(AppRoutes.hangeul)),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Sentence spotlight ─────────────────────
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
  const _StatsRow({required this.streak, required this.learned});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _StatCard(value: '$streak', label: 'Day Streak', icon: '🔥', color: AppColors.streak)),
    const SizedBox(width: AppSpacing.listGap),
    Expanded(child: _StatCard(value: '$learned', label: 'Words Learned', icon: '📚', color: AppColors.primary)),
    const SizedBox(width: AppSpacing.listGap),
    Expanded(child: _StatCard(value: '20', label: "Today's Goal", icon: '🎯', color: AppColors.success)),
  ]);
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
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's Session",
            style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('20 new words', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Sentence-first learning', style: TextStyle(
            fontSize: 13, color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: onStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
      )),
      const SizedBox(width: AppSpacing.md),
      const Text('📖', style: TextStyle(fontSize: 56)),
    ]),
  );
}

// ── Quick Action ──────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.subtleShadow,
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
          style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        Icon(Icons.arrow_forward_ios, size: 12, color: color),
      ]),
    ),
  );
}

// ── Sentence Spotlight ────────────────────────────────────
class _SentenceSpotlight extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sentence Spotlight',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.md),
        Container(
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
                    color: AppColors.topikBg(1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: const Text('TOPIK 1',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.topik1)),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              const Text('오늘도 열심히 공부했어요!',
                style: TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, height: 1.5)),
              const SizedBox(height: 6),
              const Text('I studied hard again today!',
                style: TextStyle(
                  fontSize: 15, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: 8, runSpacing: 8, children: const [
                _WordChip('오늘'), _WordChip('열심히'), _WordChip('공부했어요'),
              ]),
            ],
          ),
        ),
      ],
    );
  }
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
