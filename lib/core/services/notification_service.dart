import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'analytics_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _setLocalTimezone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// tz.local 기본값은 UTC 다. 기기 타임존으로 맞추지 않으면 예약 시각이
  /// 통째로 어긋나고, 서머타임 지역에서는 전환 후 1시간 밀린다.
  Future<void> _setLocalTimezone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } on Exception catch (e) {
      // 타임존을 못 읽어도 알림 자체는 동작해야 한다(UTC 기준으로 예약됨).
      debugPrint('[Notification] 로컬 타임존 설정 실패, UTC 사용: $e');
      AnalyticsService.instance.recordError(e, StackTrace.current);
    }
  }

  Future<bool> requestPermission() async {
    final iosResult = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    // Android 13+ requires an explicit runtime request or POST_NOTIFICATIONS
    // is silently denied and scheduled notifications never show.
    final androidResult = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return (iosResult ?? androidResult) ?? false;
  }

  /// 매일 [time] 에 리마인더를 예약한다.
  ///
  /// 실패는 삼키지 않는다 — build52 까지는 Android 12+ 에서
  /// `exact_alarms_not_permitted` 로 예약이 통째로 실패하는데도 호출부가
  /// 예외를 삼켜서, 사용자에게는 "Settings saved" 로만 보였다.
  /// 던지는 예외는 호출부가 사용자에게 표시해야 한다.
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await initialize();
    final granted = await requestPermission();
    if (!granted) {
      throw const NotificationScheduleException(
          'Notifications are turned off. Enable them in system settings.');
    }
    await cancelAll();

    final now = DateTime.now();
    var scheduledDate =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'klexi_daily',
      'Daily Reminder',
      channelDescription: 'Daily Korean learning reminder',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.zonedSchedule(
        0,
        'Time to learn Korean! 🇰🇷',
        "Today's 20 words are waiting for you",
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        // 학습 리마인더는 Android 의 정확알람(SCHEDULE_EXACT_ALARM) 자격이
        // 없다. exactAllowWhileIdle 로 두면 Android 12+ 에서 예약 자체가
        // 예외로 실패한다. 몇 분 오차는 리마인더에 무해하다.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on Exception catch (e, stack) {
      AnalyticsService.instance.recordError(e, stack);
      throw NotificationScheduleException(
          'Could not schedule the reminder: $e');
    }
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      'klexi_misc',
      'Klexi Notifications',
      channelDescription: 'App notifications',
      importance: Importance.defaultImportance,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(1, title, body, details);
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

/// 리마인더 예약 실패. 호출부가 사용자에게 표시할 책임을 진다.
class NotificationScheduleException implements Exception {
  final String message;
  const NotificationScheduleException(this.message);
  @override
  String toString() => message;
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
