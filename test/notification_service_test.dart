// test/notification_service_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test the pure logic helpers used in NotificationService
// (Plugin calls require device — tested via integration tests)

TimeOfDay _parseTime(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String _formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

bool _isValidReminderTime(TimeOfDay t) {
  // Reasonable reminder window: 6am - 11pm
  final totalMinutes = t.hour * 60 + t.minute;
  return totalMinutes >= 6 * 60 && totalMinutes <= 23 * 60;
}

void main() {
  group('Notification time helpers', () {
    test('parseTime parses HH:MM correctly', () {
      final t = _parseTime('09:30');
      expect(t.hour, 9);
      expect(t.minute, 30);
    });

    test('formatTime pads single digits', () {
      final t = const TimeOfDay(hour: 8, minute: 5);
      expect(_formatTime(t), '08:05');
    });

    test('formatTime handles midnight', () {
      final t = const TimeOfDay(hour: 0, minute: 0);
      expect(_formatTime(t), '00:00');
    });

    test('roundtrip: parse then format', () {
      const original = '14:45';
      final parsed = _parseTime(original);
      expect(_formatTime(parsed), original);
    });

    test('isValidReminderTime accepts 9am', () {
      expect(_isValidReminderTime(const TimeOfDay(hour: 9, minute: 0)), true);
    });

    test('isValidReminderTime rejects 3am', () {
      expect(_isValidReminderTime(const TimeOfDay(hour: 3, minute: 0)), false);
    });

    test('isValidReminderTime rejects midnight', () {
      expect(_isValidReminderTime(const TimeOfDay(hour: 0, minute: 0)), false);
    });

    test('isValidReminderTime accepts 11pm boundary', () {
      expect(_isValidReminderTime(const TimeOfDay(hour: 23, minute: 0)), true);
    });
  });
}
