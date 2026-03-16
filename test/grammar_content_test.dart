// test/grammar_content_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klexi_flutter/data/content/grammar/grammar_patterns.dart';

void main() {
  group('Grammar patterns content', () {
    test('returns non-empty list', () {
      expect(grammarPatterns, isNotEmpty);
    });

    test('all patterns have required fields', () {
      for (final p in grammarPatterns) {
        expect(p.id, isNotEmpty, reason: 'Pattern missing id');
        expect(p.title, isNotEmpty, reason: 'Pattern missing title: ${p.id}');
        expect(p.meaning, isNotEmpty,
            reason: 'Pattern missing meaning: ${p.id}');
        expect(p.level, inInclusiveRange(1, 6),
            reason: 'Invalid level: ${p.id}');
        expect(p.examples, isNotEmpty,
            reason: 'Pattern needs examples: ${p.id}');
      }
    });

    test('all TOPIK levels 1-2 are represented', () {
      final levels = grammarPatterns.map((p) => p.level).toSet();
      for (var lvl = 1; lvl <= 2; lvl++) {
        expect(levels.contains(lvl), true,
            reason: 'No grammar patterns for level $lvl');
      }
    });

    test('pattern ids are unique', () {
      final ids = grammarPatterns.map((p) => p.id).toList();
      final unique = ids.toSet();
      expect(unique.length, ids.length, reason: 'Duplicate pattern ids');
    });

    test('each example has Korean and English', () {
      for (final p in grammarPatterns) {
        for (final ex in p.examples) {
          expect(ex.korean, isNotEmpty,
              reason: 'Example missing Korean in pattern ${p.id}');
          expect(ex.english, isNotEmpty,
              reason: 'Example missing English in pattern ${p.id}');
        }
      }
    });

    test('level 1 patterns include basic particles', () {
      final level1 = grammarPatterns.where((p) => p.level == 1).toList();
      expect(level1.length, greaterThanOrEqualTo(5));
    });

    test('has at least 20 total patterns', () {
      expect(grammarPatterns.length, greaterThanOrEqualTo(20));
    });

    test('all patterns have non-empty category', () {
      for (final p in grammarPatterns) {
        expect(p.category, isNotEmpty,
            reason: 'Pattern missing category: ${p.id}');
      }
    });

    test('all patterns have explanation text', () {
      for (final p in grammarPatterns) {
        expect(p.explanation, isNotEmpty,
            reason: 'Pattern missing explanation: ${p.id}');
        expect(p.explanation.length, greaterThan(10),
            reason: 'Explanation too short for pattern: ${p.id}');
      }
    });
  });
}
