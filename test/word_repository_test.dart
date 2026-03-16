// test/word_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klexi_flutter/data/repositories/word_repository.dart';

void main() {
  group('WordRepository', () {
    final repo = WordRepository.instance;

    // ── Basic loading ────────────────────────────────────────
    test('getAllWords returns non-empty list', () {
      expect(repo.getAllWords(), isNotEmpty);
    });

    test('all words have non-empty id, korean, english', () {
      for (final w in repo.getAllWords()) {
        expect(w.id, isNotEmpty, reason: 'Word missing id');
        expect(w.korean, isNotEmpty, reason: 'Word missing korean: ${w.id}');
        expect(w.english, isNotEmpty, reason: 'Word missing english: ${w.id}');
      }
    });

    test('all word levels are between 1 and 6', () {
      for (final w in repo.getAllWords()) {
        expect(w.level, inInclusiveRange(1, 6),
            reason: 'Invalid level for word: ${w.id}');
      }
    });

    test('word ids are unique', () {
      final words = repo.getAllWords();
      final ids = words.map((w) => w.id).toSet();
      expect(ids.length, words.length, reason: 'Duplicate word ids found');
    });

    test('covers all TOPIK levels 1-6', () {
      final levels = repo.getAllWords().map((w) => w.level).toSet();
      for (var lvl = 1; lvl <= 6; lvl++) {
        expect(levels.contains(lvl), true,
            reason: 'No words for TOPIK level $lvl');
      }
    });

    test('has at least 100 words', () {
      expect(repo.totalCount, greaterThanOrEqualTo(100));
    });

    // ── getWordsByLevel ─────────────────────────────────────
    test('getWordsByLevel filters correctly', () {
      final level1 = repo.getWordsByLevel(1);
      expect(level1, isNotEmpty);
      expect(level1.every((w) => w.level == 1), true);
    });

    test('getWordsByLevel with invalid level returns empty', () {
      final result = repo.getWordsByLevel(99);
      expect(result, isEmpty);
    });

    // ── searchWords ─────────────────────────────────────────
    test('searchWords empty query returns all words', () {
      final all = repo.searchWords('');
      expect(all.length, repo.totalCount);
    });

    test('searchWords finds Korean word', () {
      // Find a word that exists, search for its Korean
      final first = repo.getAllWords().first;
      final results = repo.searchWords(first.korean.substring(0, 1));
      expect(results, isNotEmpty);
    });

    test('searchWords finds English word case-insensitive', () {
      final first = repo.getAllWords().first;
      final results = repo.searchWords(first.english.toUpperCase());
      expect(results, isNotEmpty);
    });

    test('searchWords returns empty for nonsense query', () {
      final results = repo.searchWords('zzzzqqqq99999xyz');
      expect(results, isEmpty);
    });

    // ── getDailyWords ───────────────────────────────────────
    test('getDailyWords returns exactly 20 words by default', () {
      final daily = repo.getDailyWords();
      expect(daily.length, 20);
    });

    test('getDailyWords respects custom count', () {
      final daily = repo.getDailyWords(count: 10);
      expect(daily.length, 10);
    });

    test('getDailyWords is stable within same day', () {
      final a = repo.getDailyWords();
      final b = repo.getDailyWords();
      expect(a.map((w) => w.id).toList(), b.map((w) => w.id).toList());
    });

    // ── categories ──────────────────────────────────────────
    test('categories is non-empty', () {
      expect(repo.categories, isNotEmpty);
    });

    test('categories are sorted', () {
      final cats = repo.categories;
      final sorted = [...cats]..sort();
      expect(cats, sorted);
    });

    test('getWordsByCategory returns correct words', () {
      final cat = repo.categories.first;
      final words = repo.getWordsByCategory(cat);
      expect(words.every((w) => w.category == cat), true);
    });
  });
}
