// test/sm2_algorithm_test.dart
// Tests for SM-2 Spaced Repetition Algorithm
import 'package:flutter_test/flutter_test.dart';

// SM-2 logic (inline for testability — matches daily_session_service.dart)
const int _minInterval = 1;

double _updateEaseFactor(double ef, int quality) {
  final newEf = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  return newEf < 1.3 ? 1.3 : newEf;
}

int _nextInterval(int interval, int repetitions, double ef, int quality) {
  if (quality < 3) return _minInterval; // reset
  if (repetitions == 0) return 1;
  if (repetitions == 1) return 6;
  return (interval * ef).round();
}

void main() {
  group('SM-2 algorithm', () {
    test('quality < 3 resets interval to 1', () {
      final next = _nextInterval(10, 3, 2.5, 2);
      expect(next, 1);
    });

    test('first correct review → interval 1', () {
      final next = _nextInterval(0, 0, 2.5, 4);
      expect(next, 1);
    });

    test('second correct review → interval 6', () {
      final next = _nextInterval(1, 1, 2.5, 4);
      expect(next, 6);
    });

    test('subsequent interval = prev * EF', () {
      final ef = 2.5;
      final next = _nextInterval(6, 2, ef, 4);
      expect(next, (6 * ef).round());
    });

    test('ease factor increases with quality 5', () {
      final newEf = _updateEaseFactor(2.5, 5);
      expect(newEf, greaterThan(2.5));
    });

    test('ease factor decreases with quality 3', () {
      final newEf = _updateEaseFactor(2.5, 3);
      expect(newEf, lessThan(2.5));
    });

    test('ease factor never drops below 1.3', () {
      var ef = 2.5;
      for (var i = 0; i < 20; i++) {
        ef = _updateEaseFactor(ef, 0);
      }
      expect(ef, greaterThanOrEqualTo(1.3));
    });

    test('quality 5 series grows interval exponentially', () {
      var interval = 0;
      var reps = 0;
      var ef = 2.5;
      final intervals = <int>[];
      for (var i = 0; i < 5; i++) {
        interval = _nextInterval(interval, reps, ef, 5);
        ef = _updateEaseFactor(ef, 5);
        intervals.add(interval);
        reps++;
      }
      // Should grow: 1, 6, ~16, ~44, ~121
      expect(intervals[0], 1);
      expect(intervals[1], 6);
      expect(intervals[2], greaterThan(10));
    });
  });
}
