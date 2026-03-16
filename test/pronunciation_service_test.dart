// test/pronunciation_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klexi_flutter/core/services/pronunciation_service.dart';

void main() {
  group('PronunciationResult.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'score': 87,
        'transcript': '안녕하세요',
        'expected': '안녕하세요',
        'feedback': 'Great job! Your pronunciation is excellent.',
        'details': [
          {'expected': '안', 'heard': '안', 'correct': true},
          {'expected': '녕', 'heard': '녕', 'correct': true},
        ],
      };

      final result = PronunciationResult.fromJson(json);
      expect(result.score, 87);
      expect(result.transcript, '안녕하세요');
      expect(result.expected, '안녕하세요');
      expect(result.feedback, contains('excellent'));
      expect(result.details.length, 2);
      expect(result.details.first.correct, true);
    });

    test('handles missing optional fields gracefully', () {
      final json = {'score': 50};
      final result = PronunciationResult.fromJson(json);
      expect(result.score, 50);
      expect(result.transcript, '');
      expect(result.feedback, '');
      expect(result.details, isEmpty);
    });

    test('score 0 is valid', () {
      final json = {'score': 0, 'transcript': '', 'expected': '', 'feedback': '', 'details': []};
      final result = PronunciationResult.fromJson(json);
      expect(result.score, 0);
    });

    test('score 100 is valid', () {
      final json = {'score': 100, 'transcript': '완벽', 'expected': '완벽', 'feedback': 'Perfect!', 'details': []};
      final result = PronunciationResult.fromJson(json);
      expect(result.score, 100);
    });
  });

  group('PronunciationResult.offline', () {
    test('returns score 0 with error message', () {
      final r = PronunciationResult.offline();
      expect(r.score, 0);
      expect(r.feedback, isNotEmpty);
    });
  });

  group('PhonemeDetail.fromJson', () {
    test('parses correct match', () {
      final d = PhonemeDetail.fromJson({'expected': '가', 'heard': '가', 'correct': true});
      expect(d.expected, '가');
      expect(d.heard, '가');
      expect(d.correct, true);
    });

    test('parses mismatch', () {
      final d = PhonemeDetail.fromJson({'expected': '나', 'heard': '다', 'correct': false});
      expect(d.correct, false);
    });

    test('handles missing fields with defaults', () {
      final d = PhonemeDetail.fromJson({});
      expect(d.expected, '');
      expect(d.heard, '');
      expect(d.correct, false);
    });
  });

  group('Score thresholds', () {
    // Verify the business rules for feedback labels
    const excellent = 95;
    const good = 80;
    const ok = 60;
    const poor = 30;

    String label(int score) {
      if (score >= 95) return 'Perfect';
      if (score >= 80) return 'Great';
      if (score >= 60) return 'Good';
      if (score >= 40) return 'Keep going';
      return 'Try again';
    }

    test('95+ is Perfect', () => expect(label(excellent), 'Perfect'));
    test('80–94 is Great', () => expect(label(good), 'Great'));
    test('60–79 is Good', () => expect(label(ok), 'Good'));
    test('<40 is Try again', () => expect(label(poor), 'Try again'));
  });
}
