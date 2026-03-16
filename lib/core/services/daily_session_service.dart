// lib/core/services/daily_session_service.dart
// Picks 20 words for today's session using a simple SRS algorithm.
// Persists study history in Hive.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/word.dart';
import '../../data/repositories/word_repository.dart';

final dailySessionServiceProvider =
    Provider<DailySessionService>((_) => DailySessionService.instance);

// ── Data Classes ───────────────────────────────────────────────────────────────

class StudyRecord {
  final String wordId;
  final DateTime lastStudied;
  final int timesStudied;
  final int easyCount;
  final int hardCount;

  const StudyRecord({
    required this.wordId,
    required this.lastStudied,
    required this.timesStudied,
    required this.easyCount,
    required this.hardCount,
  });

  /// Returns the number of days until this word should be reviewed again.
  /// Simple SRS formula based on ease history.
  int get intervalDays {
    if (timesStudied == 0) return 0;
    final easeFactor = (easyCount - hardCount).clamp(0, 10);
    // 1 → 3 → 7 → 14 → 30 days
    const intervals = [1, 3, 7, 14, 30];
    final idx = easeFactor.clamp(0, intervals.length - 1);
    return intervals[idx];
  }

  bool get isDueToday {
    final dueDate = lastStudied.add(Duration(days: intervalDays));
    return DateTime.now().isAfter(dueDate);
  }
}

class GeneratedSentence {
  final String korean;
  final String english;
  final String focusWordId;

  const GeneratedSentence({
    required this.korean,
    required this.english,
    required this.focusWordId,
  });
}

class DailySession {
  final DateTime date;
  final List<Word> words;
  final List<GeneratedSentence> sentences;

  const DailySession({
    required this.date,
    required this.words,
    required this.sentences,
  });
}

// ── Provider ─────────────────────────────────────────────────────────────────
// (import flutter_riverpod needed below)

// ── Service ────────────────────────────────────────────────────────────────────

class DailySessionService {
  DailySessionService._();
  static final DailySessionService instance = DailySessionService._();

  static const String _boxName = 'study_records';
  static const int _sessionSize = 20;

  Box<Map>? _box;

  // ── Lifecycle ──────────────────────────────────────────────

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return; // idempotent
    _box = await Hive.openBox<Map>(_boxName);
  }

  // ── Session Building ───────────────────────────────────────

  /// Returns today's [DailySession] with [_sessionSize] words.
  /// Priority order:
  ///   1. Words due for SRS review today
  ///   2. New words that have never been studied
  ///   3. Filler from recent words if needed
  Future<DailySession> getTodaySession() async {
    final box = _box;
    if (box == null) {
      throw StateError('DailySessionService not initialised. Call init() first.');
    }

    final repo = WordRepository.instance;
    final all = repo.getAllWords();

    // Load study records from Hive
    final records = <String, StudyRecord>{};
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      records[key as String] = StudyRecord(
        wordId: key,
        lastStudied: DateTime.fromMillisecondsSinceEpoch(
            (raw['lastStudied'] as int?) ?? 0),
        timesStudied: (raw['timesStudied'] as int?) ?? 0,
        easyCount: (raw['easyCount'] as int?) ?? 0,
        hardCount: (raw['hardCount'] as int?) ?? 0,
      );
    }

    // Split words into due, new, and studied
    final dueWords = <Word>[];
    final newWords = <Word>[];

    for (final w in all) {
      final rec = records[w.id];
      if (rec == null) {
        newWords.add(w);
      } else if (rec.isDueToday) {
        dueWords.add(w);
      }
    }

    final selected = <Word>[];
    selected.addAll(dueWords.take(_sessionSize));

    if (selected.length < _sessionSize) {
      selected.addAll(
          newWords.take(_sessionSize - selected.length));
    }

    // If still short, top up with random low-level words
    if (selected.length < _sessionSize) {
      final existing = selected.map((w) => w.id).toSet();
      final filler = all
          .where((w) => !existing.contains(w.id) && w.level <= 2)
          .take(_sessionSize - selected.length);
      selected.addAll(filler);
    }

    // Build contextual sentences from word examples
    final sentences = selected.map((w) => GeneratedSentence(
      korean: w.example,
      english: w.exampleTranslation,
      focusWordId: w.id,
    )).toList();

    return DailySession(
      date: DateTime.now(),
      words: selected,
      sentences: sentences,
    );
  }

  // ── Recording Progress ─────────────────────────────────────

  /// Records that the user studied [wordId].
  /// [wasEasy] indicates whether they found it easy (true) or hard (false).
  Future<void> recordStudy({
    required String wordId,
    required bool wasEasy,
  }) async {
    final box = _box;
    if (box == null) return;

    final existing = box.get(wordId);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (existing == null) {
      await box.put(wordId, {
        'lastStudied': now,
        'timesStudied': 1,
        'easyCount': wasEasy ? 1 : 0,
        'hardCount': wasEasy ? 0 : 1,
      });
    } else {
      await box.put(wordId, {
        'lastStudied': now,
        'timesStudied': ((existing['timesStudied'] as int?) ?? 0) + 1,
        'easyCount': ((existing['easyCount'] as int?) ?? 0) + (wasEasy ? 1 : 0),
        'hardCount': ((existing['hardCount'] as int?) ?? 0) + (wasEasy ? 0 : 1),
      });
    }
  }

  // ── Statistics ─────────────────────────────────────────────

  /// Returns today's 20 word IDs for the session.
  Future<List<String>> getTodayWordIds() async {
    final session = await getTodaySession();
    return session.words.map((w) => w.id).toList();
  }

  /// Records a review with SM-2 quality score (1=hard, 3=ok, 5=easy).
  Future<void> recordReview(String wordId, int quality) =>
      recordStudy(wordId: wordId, wasEasy: quality >= 4);

  /// Returns the total number of distinct words ever studied.
  Future<int> getTotalWordsStudied() async {
    return _box?.keys.length ?? 0;
  }

  /// Returns the current streak in consecutive days studied.
  Future<int> getCurrentStreak() async {
    final box = _box;
    if (box == null) return 0;

    // Collect unique study dates
    final studiedDates = <DateTime>{};
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final ms = (raw['lastStudied'] as int?) ?? 0;
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      studiedDates.add(DateTime(d.year, d.month, d.day));
    }

    if (studiedDates.isEmpty) return 0;

    int streak = 0;
    var checkDate = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);

    while (studiedDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }
}
