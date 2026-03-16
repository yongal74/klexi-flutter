// lib/data/repositories/word_repository.dart
// Provides all 7200 words loaded from content/vocab/*.dart at startup.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../content/vocab/vocab_index.dart';

final wordRepositoryProvider = Provider<WordRepository>((_) => WordRepository.instance);

/// Central repository for all vocabulary words.
/// Call [WordRepository.instance] to access the singleton.
class WordRepository {
  WordRepository._();

  static final WordRepository instance = WordRepository._();

  // ── Internal data ──────────────────────────────────────────
  static const List<Word> _all = [
    ...level1Part1Words,
    ...level1Part2Words,
    ...level1Part3Words,
    ...level2Part1Words,
    ...level2Part2Words,
    ...level2Part3Words,
    ...level3Part1Words,
    ...level3Part2Words,
    ...level3Part3Words,
    ...level4Part1Words,
    ...level4Part2Words,
    ...level4Part3Words,
    ...level5Part1Words,
    ...level5Part2Words,
    ...level5Part3Words,
    ...level6Part1Words,
    ...level6Part2Words,
    ...level6Part3Words,
  ];

  // ── Public API ─────────────────────────────────────────────

  /// Returns all 7200 words.
  List<Word> getAllWords() => _all;

  /// Returns all words belonging to the given TOPIK [level] (1–6).
  List<Word> getWordsByLevel(int level) =>
      _all.where((w) => w.level == level).toList();

  /// Returns all words belonging to the given [category] string.
  List<Word> getWordsByCategory(String category) =>
      _all.where((w) => w.category == category).toList();

  /// Full-text search across [korean], [english], and [pronunciation].
  /// Case-insensitive. Returns words that contain [query].
  List<Word> searchWords(String query) {
    if (query.trim().isEmpty) return _all;
    final q = query.toLowerCase();
    return _all.where((w) =>
      w.korean.toLowerCase().contains(q) ||
      w.english.toLowerCase().contains(q) ||
      w.pronunciation.toLowerCase().contains(q),
    ).toList();
  }

  /// Returns [count] words for today's daily session.
  /// Words are distributed proportionally across levels 1–3 by default
  /// to keep early-learner content prominent.
  List<Word> getDailyWords({int count = 20}) {
    // Seed with current day so the set is stable for 24 h
    final daySeed = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    final shuffled = List<Word>.from(_all);
    // Deterministic shuffle based on date
    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = (daySeed * (i + 1)) % (i + 1);
      final tmp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = tmp;
    }
    return shuffled.take(count).toList();
  }

  /// Total number of words loaded.
  int get totalCount => _all.length;

  /// All distinct categories present in the word list.
  List<String> get categories =>
      _all.map((w) => w.category).toSet().toList()..sort();
}
