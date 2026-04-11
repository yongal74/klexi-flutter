import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/daily_session_service.dart';
import '../../../core/services/purchase_service.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';
import '../../home/presentation/home_screen.dart' show userTopikLevelProvider;

class DailySessionScreen extends ConsumerStatefulWidget {
  const DailySessionScreen({super.key});
  @override
  ConsumerState<DailySessionScreen> createState() => _DailySessionScreenState();
}

class _DailySessionScreenState extends ConsumerState<DailySessionScreen> {
  List<Word> _words = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(wordRepositoryProvider);
    final session = ref.read(dailySessionServiceProvider);
    final isPremium = ref.read(isPremiumProvider);
    final userLevel = ref.read(userTopikLevelProvider);
    final ids = await session.getTodayWordIds(isPremium: isPremium, userLevel: userLevel);
    final all = repo.getAllWords();
    setState(() {
      // 비프리미엄 사용자는 Level 1 단어만 허용
      _words = all
          .where((w) => ids.contains(w.id) && (isPremium || w.level == 1))
          .take(20)
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("Today's Session"),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? _emptyState()
              : _sessionList(),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🎉', style: TextStyle(fontSize: 64)),
        const SizedBox(height: AppSpacing.lg),
        Text("All done for today!",
          style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text("Come back tomorrow for new words",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary)),
      ],
    ),
  );

  Widget _sessionList() => Column(
    children: [
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _words.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.listGap),
          itemBuilder: (context, i) => _WordTile(
            word: _words[i],
            onTap: () => context.push('${AppRoutes.sentenceCard}?wordId=${_words[i].id}'),
          ),
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: ElevatedButton(
            onPressed: () => context.push(AppRoutes.sentenceCard),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Learning',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    ],
  );
}

class _WordTile extends StatelessWidget {
  final Word word;
  final VoidCallback onTap;
  const _WordTile({required this.word, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final levelColor = AppColors.topikColor(word.level);
    final levelBg    = AppColors.topikBg(word.level);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 컬러 상단 영역 (TOPIK 레벨 컬러) ──
            Container(
              color: levelBg,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPad, AppSpacing.md, AppSpacing.cardPad, AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Text('TOPIK ${word.level}',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: levelColor)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(word.korean,
                      style: TextStyle(
                        fontFamily: 'NotoSansKR', fontSize: 17,
                        fontWeight: FontWeight.w700, color: levelColor)),
                  ),
                  Icon(Icons.chevron_right, color: levelColor.withOpacity(0.6), size: 18),
                ],
              ),
            ),
            // ── 흰색 하단 영역 (영어) ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPad, AppSpacing.sm, AppSpacing.cardPad, AppSpacing.sm),
              child: Text(word.english,
                style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
