// lib/core/services/daily_session_service.dart
// Picks 20 words for today's session using a simple SRS algorithm.
// Persists study history in Hive.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/word.dart';
import '../../data/repositories/word_repository.dart';

final dailySessionServiceProvider =
    Provider<DailySessionService>((_) => DailySessionService.instance);

/// IDs of the last completed session's words — used by Quiz / Review / Practice
final lastSessionWordsProvider = StateProvider<List<String>>((ref) => []);

/// Number of words studied today — updated by SentenceCardScreen after each review
final todayStudiedCountProvider = StateProvider<int>((ref) => 0);

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
  /// Interval grows with each study: 1 → 3 → 7 → 14 → 30 → 60 days.
  /// Hard answers (Again) reset to a shorter interval.
  int get intervalDays {
    if (timesStudied == 0) return 0;
    const intervals = [1, 3, 7, 14, 30, 60];
    int idx = (timesStudied - 1).clamp(0, intervals.length - 1);
    // If user pressed Again more than twice, step back one level
    if (hardCount - easyCount > 2) idx = (idx - 1).clamp(0, intervals.length - 1);
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
  ///   3. Filler from user's current level (프리미엄) or level 1 (무료)
  Future<DailySession> getTodaySession({bool isPremium = false, int userLevel = 1}) async {
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
    // Always reserve at least 5 slots for new words so the user sees new content daily
    const minNew = 5;
    final dueSlots = (_sessionSize - minNew).clamp(0, dueWords.length);
    selected.addAll(dueWords.take(dueSlots));

    if (selected.length < _sessionSize) {
      selected.addAll(newWords.take(_sessionSize - selected.length));
    }

    // Fill any remaining slots with extra due words
    if (selected.length < _sessionSize) {
      selected.addAll(dueWords.skip(dueSlots).take(_sessionSize - selected.length));
    }

    // 부족 시 filler: 프리미엄 유저는 현재 레벨, 무료 유저는 level 1
    if (selected.length < _sessionSize) {
      final existing = selected.map((w) => w.id).toSet();
      final fillerLevel = isPremium ? userLevel : 1;
      final filler = all
          .where((w) => !existing.contains(w.id) && w.level == fillerLevel)
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
  Future<List<String>> getTodayWordIds({bool isPremium = false, int userLevel = 1}) async {
    final session = await getTodaySession(isPremium: isPremium, userLevel: userLevel);
    return session.words.map((w) => w.id).toList();
  }

  /// Records a review with SM-2 quality score (1=hard, 3=ok, 5=easy).
  Future<void> recordReview(String wordId, int quality) =>
      recordStudy(wordId: wordId, wasEasy: quality >= 4);

  /// Returns the total number of distinct words ever studied.
  Future<int> getTotalWordsStudied() async {
    return _box?.keys.length ?? 0;
  }

  /// Returns the count of words studied per day for the last 7 days (Mon→Sun of current week).
  Future<List<int>> getWeekActivity() async {
    final box = _box;
    if (box == null) return List.filled(7, 0);

    // Map: date → set of word IDs studied that day
    final dayWords = <DateTime, Set<String>>{};
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final ms = (raw['lastStudied'] as int?) ?? 0;
      if (ms == 0) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      final day = DateTime(d.year, d.month, d.day);
      dayWords.putIfAbsent(day, () => <String>{}).add(key as String);
    }

    // Build 7-element list for Mon(0)→Sun(6) of the current week
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      return dayWords[day]?.length ?? 0;
    });
  }

  /// Returns studied word IDs per TOPIK level (1-6).
  Future<Map<int, Set<String>>> getStudiedWordIdsByLevel() async {
    final box = _box;
    if (box == null) return {};

    final studiedIds = box.keys.cast<String>().toSet();
    final repo = WordRepository.instance;
    final allWords = repo.getAllWords();

    final result = <int, Set<String>>{};
    for (final word in allWords) {
      if (studiedIds.contains(word.id)) {
        result.putIfAbsent(word.level, () => <String>{}).add(word.id);
      }
    }
    return result;
  }

  /// Returns the number of words studied today.
  Future<int> getTodayStudiedCount() async {
    final box = _box;
    if (box == null) return 0;
    final today = DateTime.now();
    int count = 0;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final ms = (raw['lastStudied'] as int?) ?? 0;
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        count++;
      }
    }
    return count;
  }

  /// Clears all study records — resets the session so new words are served.
  Future<void> resetSession() async {
    final box = _box;
    if (box == null) return;
    await box.clear();
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
