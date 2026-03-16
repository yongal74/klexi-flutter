import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/daily_session_service.dart';

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});
  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  int _streak = 0;
  int _todayDone = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(dailySessionServiceProvider);
    final streak = await session.getCurrentStreak();
    final total  = await session.getTotalWordsStudied();
    if (mounted) setState(() { _streak = streak; _todayDone = total % 20; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Learn'),
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily progress
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPad),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's Progress",
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('$_todayDone', style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
                    const Text(' / 20 words', style: TextStyle(
                      fontSize: 18, color: Colors.white70)),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _todayDone / 20,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () => context.push(AppRoutes.dailySession),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      _todayDone == 0 ? 'Start Session' : 'Continue',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            const Text('Practice Modes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.md),

            _PracticeCard(
              icon: '📝',
              title: 'Sentence Cards',
              subtitle: 'Learn words in full context',
              color: AppColors.primary,
              onTap: () => context.push(AppRoutes.sentenceCard),
            ),
            const SizedBox(height: AppSpacing.listGap),
            _PracticeCard(
              icon: '🔤',
              title: 'Fill in the Blank',
              subtitle: 'Test your recall',
              color: AppColors.accent,
              onTap: () => context.push(AppRoutes.clozeQuiz),
            ),
            const SizedBox(height: AppSpacing.listGap),
            _PracticeCard(
              icon: '🎙️',
              title: 'Pronunciation',
              subtitle: 'AI scoring on your speech',
              color: AppColors.topik4,
              onTap: () => context.push(AppRoutes.pronunciation),
            ),
            const SizedBox(height: AppSpacing.listGap),
            _PracticeCard(
              icon: '✍️',
              title: 'Hangeul Writing',
              subtitle: 'Trace stroke order',
              color: AppColors.topik2,
              onTap: () => context.push(AppRoutes.hangeul),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PracticeCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap,
  });

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
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 26))),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(subtitle, style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary)),
          ],
        )),
        Icon(Icons.arrow_forward_ios, size: 14, color: color),
      ]),
    ),
  );
}
