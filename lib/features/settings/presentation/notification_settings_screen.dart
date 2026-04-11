import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/notification_service.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _enabled = true;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('notif_enabled') ?? true;
      final h = prefs.getInt('notif_hour') ?? 9;
      final m = prefs.getInt('notif_minute') ?? 0;
      _time = TimeOfDay(hour: h, minute: m);
    });
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_enabled', _enabled);
      await prefs.setInt('notif_hour', _time.hour);
      await prefs.setInt('notif_minute', _time.minute);

      final svc = ref.read(notificationServiceProvider);
      if (_enabled) {
        await svc.scheduleDailyReminder(_time);
      } else {
        await svc.cancelAll();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      debugPrint('[NotifSettings] save error: $e');
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _save();
      },
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
                      onChanged: (v) => setState(() => _enabled = v),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _enabled
                              ? AppColors.primary.withOpacity(0.1)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: Text(
                          _time.format(context),
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: _enabled ? AppColors.primary : AppColors.textMuted),
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
