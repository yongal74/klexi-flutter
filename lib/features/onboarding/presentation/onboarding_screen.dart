// lib/features/onboarding/presentation/onboarding_screen.dart
// 첫 로그인 직후 한 번만 보여주는 안내. 마지막 장에서 매일 학습 알림을 켠다.
// (알림은 설정 화면에 들어가야만 예약됐기 때문에 대부분의 사용자가 받지 못했다.)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/services/notification_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  final String emoji;
  final String title;
  final String body;
  const _Page(this.emoji, this.title, this.body);
}

const _pages = [
  _Page(
      '📖',
      AppStrings.onboardingTitle1,
      'Every day you get 20 words, each inside a real Korean sentence. '
          'Tap Start on the Home tab to begin.'),
  _Page('🔁', 'Review at the\nright time',
      'Words you find hard come back sooner. A few minutes a day is enough.'),
  _Page('🕸️', AppStrings.onboardingTitle2, AppStrings.onboardingBody2),
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _ctrl = PageController();
  int _index = 0;
  bool _busy = false;

  bool get _onReminderPage => _index == _pages.length;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    _ctrl.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _finish({required bool reminder}) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (reminder) {
      const time = TimeOfDay(hour: 9, minute: 0);
      try {
        await ref.read(notificationServiceProvider).scheduleDailyReminder(time);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notif_enabled', true);
        await prefs.setInt('notif_hour', time.hour);
        await prefs.setInt('notif_minute', time.minute);
      } on Exception catch (_) {
        // 권한 거부 등 — 온보딩은 막지 않는다. 설정에서 다시 켤 수 있다.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Reminders are off. You can turn them on anytime in Settings.')));
        }
      }
    }
    if (!mounted) return;
    await markOnboardingDone(ref);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _onReminderPage
                  ? const SizedBox(height: 48)
                  : TextButton(
                      onPressed: () => _ctrl.animateToPage(_pages.length,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut),
                      child: const Text(AppStrings.skip),
                    ),
            ),
            Expanded(
              child: PageView(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final p in _pages)
                    _InfoPage(emoji: p.emoji, title: p.title, body: p.body),
                  const _InfoPage(
                    emoji: '⏰',
                    title: 'A daily nudge',
                    body:
                        'Learners who study a little every day remember far more. '
                        'Want a reminder at 9:00 AM? You can change the time in Settings.',
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length + 1,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : _onReminderPage
                              ? () => _finish(reminder: true)
                              : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                          _onReminderPage ? 'Remind me daily' : AppStrings.next,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: _onReminderPage
                        ? TextButton(
                            onPressed:
                                _busy ? null : () => _finish(reminder: false),
                            child: const Text('Not now'),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  const _InfoPage(
      {required this.emoji, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 32),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, height: 1.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
