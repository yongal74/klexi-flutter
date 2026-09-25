import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/notification_service.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  // 기본값은 꺼짐 — 실제로 예약된 적이 없는데 "켜짐"으로 보이면 안 된다
  bool _enabled = false;
  bool _busy = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.getBool('notif_enabled') ?? false;
      final h = prefs.getInt('notif_hour') ?? 9;
      final m = prefs.getInt('notif_minute') ?? 0;
      _time = TimeOfDay(hour: h, minute: m);
    });
  }

  /// 바꾼 즉시 적용한다. 예전엔 화면을 나갈 때(뒤로가기) 저장해서, 보기만 해도
  /// 권한 요청·예약이 일어났고 실패 알림은 화면이 닫힌 뒤라 보이지 않았다.
  Future<void> _apply({required bool enabled, required TimeOfDay time}) async {
    if (_busy) return;
    final prevEnabled = _enabled;
    final prevTime = _time;
    setState(() {
      _busy = true;
      _enabled = enabled;
      _time = time;
    });
    try {
      final svc = ref.read(notificationServiceProvider);
      if (enabled) {
        await svc.scheduleDailyReminder(time);
      } else {
        await svc.cancelAll();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_enabled', enabled);
      await prefs.setInt('notif_hour', time.hour);
      await prefs.setInt('notif_minute', time.minute);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(enabled
                ? 'Daily reminder set for ${time.format(context)}'
                : 'Daily reminders turned off')));
      }
    } on NotificationScheduleException catch (e) {
      _revert(prevEnabled, prevTime);
      _showError(e.message);
    } on Exception catch (e, stack) {
      AnalyticsService.instance.recordError(e, stack);
      _revert(prevEnabled, prevTime);
      _showError("Couldn't update reminders. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _revert(bool enabled, TimeOfDay time) {
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _time = time;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 5),
    ));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) await _apply(enabled: true, time: picked);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        child: Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Enable toggle
                  ListTile(
                    title: const Text('Daily Reminder',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Get reminded to practice every day'),
                    trailing: Switch(
                      value: _enabled,
                      onChanged:
                          _busy ? null : (v) => _apply(enabled: v, time: _time),
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Time picker
                  ListTile(
                    enabled: _enabled,
                    title: const Text('Reminder Time'),
                    trailing: GestureDetector(
                      onTap: _enabled ? _pickTime : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _enabled
                              ? AppColors.primary.withOpacity(0.1)
                              : AppColors.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: Text(
                          _time.format(context),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _enabled
                                  ? AppColors.primary
                                  : AppColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
