import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/daily_session_service.dart';
import '../../../data/models/word.dart';
import '../../../data/repositories/word_repository.dart';

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
    final ids = await session.getTodayWordIds();
    final all = repo.getAllWords();
    setState(() {
      _words = all.where((w) => ids.contains(w.id)).take(20).toList();
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
          itemBuilder: (context, i) => _WordTile(_words[i]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: ElevatedButton(
          onPressed: () => context.push(AppRoutes.sentenceCard),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Start Learning', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    ],
  );
}

class _WordTile extends StatelessWidget {
  final Word word;
  const _WordTile(this.word);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.topikBg(word.level),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Center(
              child: Text('${word.level}',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.topikColor(word.level)),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word.korean,
                  style: const TextStyle(
                    fontFamily: 'NotoSansKR', fontSize: 18,
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(word.english,
                  style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
