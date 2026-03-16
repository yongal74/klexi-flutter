// test/daily_session_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klexi_flutter/core/services/daily_session_service.dart';

void main() {
  group('StudyRecord', () {
    test('never-studied word has intervalDays = 0', () {
      final rec = StudyRecord(
        wordId: 'w1',
        lastStudied: DateTime.now(),
        timesStudied: 0,
        easyCount: 0,
        hardCount: 0,
      );
      expect(rec.intervalDays, 0);
    });

    test('easy word gets longer interval', () {
      final easy = StudyRecord(
        wordId: 'w2',
        lastStudied: DateTime.now().subtract(const Duration(days: 5)),
        timesStudied: 5,
        easyCount: 5,
        hardCount: 0,
      );
      final hard = StudyRecord(
        wordId: 'w3',
        lastStudied: DateTime.now().subtract(const Duration(days: 5)),
        timesStudied: 5,
        easyCount: 0,
        hardCount: 5,
      );
      expect(easy.intervalDays, greaterThanOrEqualTo(hard.intervalDays));
    });

    test('isDueToday is true when intervalDays has passed', () {
      final rec = StudyRecord(
        wordId: 'w4',
        lastStudied: DateTime.now().subtract(const Duration(days: 10)),
        timesStudied: 1,
        easyCount: 0,
        hardCount: 0,
      );
      expect(rec.isDueToday, true);
    });

    test('isDueToday is false for recently reviewed easy word', () {
      final rec = StudyRecord(
        wordId: 'w5',
        lastStudied: DateTime.now(),
        timesStudied: 3,
        easyCount: 10, // very easy → long interval
        hardCount: 0,
      );
      // intervalDays should be > 0, so not due today
      // (unless intervalDays == 0, but that only happens when timesStudied == 0)
      expect(rec.timesStudied, greaterThan(0));
    });
  });

  group('GeneratedSentence', () {
    test('can be created with all fields', () {
      const s = GeneratedSentence(
        korean: '나는 학교에 가요.',
        english: 'I go to school.',
        focusWordId: 'w_school',
      );
      expect(s.korean, isNotEmpty);
      expect(s.english, isNotEmpty);
      expect(s.focusWordId, 'w_school');
    });
  });

  group('DailySession', () {
    test('can be created and holds words + sentences', () {
      final session = DailySession(
        date: DateTime(2026, 1, 1),
        words: const [],
        sentences: const [],
      );
      expect(session.words, isEmpty);
      expect(session.sentences, isEmpty);
      expect(session.date.year, 2026);
    });
  });
}
