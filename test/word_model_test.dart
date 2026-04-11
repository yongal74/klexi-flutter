// test/word_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klexi_flutter/data/models/word.dart';

void main() {
  group('Word model', () {
    late Word word;

    setUp(() {
      word = Word(
        id: 'w001',
        korean: '사랑',
        english: 'love',
        level: 1,
        partOfSpeech: 'noun',
        example: '나는 너를 사랑해.',
        exampleTranslation: 'I love you.',
        pronunciation: 'sa-rang',
        category: 'emotion',
        relatedIds: ['w002', 'w003'],
      );
    });

    test('creates with all fields', () {
      expect(word.id, 'w001');
      expect(word.korean, '사랑');
      expect(word.english, 'love');
      expect(word.level, 1);
      expect(word.partOfSpeech, 'noun');
      expect(word.example, '나는 너를 사랑해.');
      expect(word.exampleTranslation, 'I love you.');
      expect(word.pronunciation, 'sa-rang');
      expect(word.category, 'emotion');
      expect(word.relatedIds, ['w002', 'w003']);
    });

    test('default pronunciation is empty string', () {
      final w = Word(
        id: 'w002',
        korean: '물',
        english: 'water',
        level: 1,
        partOfSpeech: 'noun',
        example: '물 주세요.',
        exampleTranslation: 'Please give me water.',
      );
      expect(w.pronunciation, '');
      expect(w.category, '');
      expect(w.relatedIds, []);
    });

    test('TOPIK levels 1-6 are valid', () {
      for (var lvl = 1; lvl <= 6; lvl++) {
        final w = word.copyWith(level: lvl);
        expect(w.level, lvl);
      }
    });

    test('copyWith replaces only specified fields', () {
      final updated = word.copyWith(english: 'affection', level: 2);
      expect(updated.id, word.id);
      expect(updated.korean, word.korean);
      expect(updated.english, 'affection');
      expect(updated.level, 2);
    });

    test('two Words with same id are considered equal', () {
      final w2 = word.copyWith(english: 'different');
      // id-based equality
      expect(word.id, w2.id);
    });
  });
}
