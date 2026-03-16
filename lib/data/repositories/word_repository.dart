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
  static final List<Word> _all = [
    ...level1_part1Words,
    ...level1_part2Words,
    ...level1_part3Words,
    ...level2_part1Words,
    ...level2_part2Words,
    ...level2_part3Words,
    ...level3_part1Words,
    ...level3_part2Words,
    ...level3_part3Words,
    ...level4_part1Words,
    ...level4_part2Words,
    ...level4_part3Words,
    ...level5_part1Words,
    ...level5_part2Words,
    ...level5_part3Words,
    ...level6_part1Words,
    ...level6_part2Words,
    ...level6_part3Words,
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
