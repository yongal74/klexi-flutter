// lib/core/services/daily_session_service.dart
// Picks 20 words for today's session using a simple SRS algorithm.
// Persists study history in Hive.

import 'package:flutter/foundation.dart';
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
    if (hardCount - easyCount > 2) {
      idx = (idx - 1).clamp(0, intervals.length - 1);
    }
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

  /// build52 이전에 쓰던 '기기 공용' 박스. uid 구분이 없어서 같은 기기의
  /// 서로 다른 사용자가 학습 기록을 공유했다. 첫 사용자에게 1회 이관 후 삭제한다.
  static const String _legacyBoxName = 'study_records';
  static const int _sessionSize = 20;

  static String boxNameFor(String uid) => 'study_records_$uid';

  Box<Map>? _box;
  String? _uid;

  /// 현재 박스가 열려 있는 사용자 id (없으면 null).
  String? get currentUid => _uid;

  // ── Lifecycle ──────────────────────────────────────────────

  /// [uid] 전용 학습기록 박스를 연다. 게스트는 `guest_...` id를 그대로 쓴다.
  /// 같은 uid로 다시 부르면 아무 일도 하지 않는다(idempotent).
  Future<void> init(String uid) async {
    if (_uid == uid && _box != null && _box!.isOpen) return;

    final previous = _box;
    final boxName = boxNameFor(uid);
    final box = await Hive.openBox<Map>(boxName);
    await _migrateLegacyBox(box);

    _box = box;
    _uid = uid;

    // 다른 사용자의 박스가 열려 있었으면 닫는다(삭제는 하지 않음).
    if (previous != null && previous.isOpen && previous.name != boxName) {
      await previous.close();
    }
  }

  /// 인증 상태가 바뀌었을 때 박스를 갈아끼운다.
  Future<void> switchUser(String uid) => init(uid);

  /// 로그아웃 시 호출 — 박스를 닫되 데이터는 남긴다.
  Future<void> closeForSignOut() async {
    final box = _box;
    _box = null;
    _uid = null;
    if (box != null && box.isOpen) await box.close();
  }

  /// 계정 삭제 시 호출 — [uid]의 박스를 디스크에서 지운다.
  Future<void> deleteDataForUser(String uid) async {
    final boxName = boxNameFor(uid);
    if (_uid == uid) {
      _box = null;
      _uid = null;
    }
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<Map>(boxName).deleteFromDisk();
    } else if (await Hive.boxExists(boxName)) {
      final box = await Hive.openBox<Map>(boxName);
      await box.deleteFromDisk();
    }
  }

  /// 게스트 → 정식 계정 업그레이드 시 학습기록을 옮긴다.
  /// 이관 후 [toUid] 박스가 현재 박스가 된다.
  Future<void> migrateUser({
    required String fromUid,
    required String toUid,
  }) async {
    if (fromUid == toUid) return;
    final fromName = boxNameFor(fromUid);
    try {
      if (!Hive.isBoxOpen(fromName) && !await Hive.boxExists(fromName)) {
        await init(toUid);
        return;
      }
      final from = Hive.isBoxOpen(fromName)
          ? Hive.box<Map>(fromName)
          : await Hive.openBox<Map>(fromName);
      final to = await Hive.openBox<Map>(boxNameFor(toUid));
      for (final key in from.keys) {
        final value = from.get(key);
        if (value == null) continue;
        await to.put(key, value);
      }
      await from.deleteFromDisk();
      _box = to;
      _uid = toUid;
      debugPrint('[DailySession] 게스트 기록 이관 완료: $fromUid → $toUid');
    } on Exception catch (e) {
      debugPrint('[DailySession] 게스트 기록 이관 실패: $e');
      await init(toUid);
    }
  }

  /// 공용 박스 `study_records`가 남아 있으면 [target]으로 1회 이관 후 삭제한다.
  /// 이미 [target]에 있는 키는 덮어쓰지 않는다(최신 기록 우선).
  Future<void> _migrateLegacyBox(Box<Map> target) async {
    try {
      if (!await Hive.boxExists(_legacyBoxName)) return;
      final legacy = Hive.isBoxOpen(_legacyBoxName)
          ? Hive.box<Map>(_legacyBoxName)
          : await Hive.openBox<Map>(_legacyBoxName);
      var moved = 0;
      for (final key in legacy.keys) {
        if (target.containsKey(key)) continue;
        final value = legacy.get(key);
        if (value == null) continue;
        await target.put(key, value);
        moved++;
      }
      await legacy.deleteFromDisk();
      debugPrint('[DailySession] 공용 박스 이관 완료: $moved건 → ${target.name}');
    } on Exception catch (e) {
      // 이관 실패 시 원본을 남겨 다음 실행에 재시도한다(데이터 손실 방지).
      debugPrint('[DailySession] 공용 박스 이관 실패(원본 유지): $e');
    }
  }

  // ── Session Building ───────────────────────────────────────

  /// Returns today's [DailySession] with [_sessionSize] words.
  /// Priority order:
  ///   1. Words due for SRS review today
  ///   2. New words that have never been studied
  ///   3. Filler from user's current level (프리미엄) or level 1 (무료)
  Future<DailySession> getTodaySession({
    required bool isPremium,
    required int userLevel,
  }) async {
    final box = _box;
    if (box == null) {
      throw StateError(
          'DailySessionService not initialised. Call init() first.');
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
      selected
          .addAll(dueWords.skip(dueSlots).take(_sessionSize - selected.length));
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
    final sentences = selected
        .map((w) => GeneratedSentence(
              korean: w.example,
              english: w.exampleTranslation,
              focusWordId: w.id,
            ))
        .toList();

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
  Future<List<String>> getTodayWordIds({
    required bool isPremium,
    required int userLevel,
  }) async {
    final session =
        await getTodaySession(isPremium: isPremium, userLevel: userLevel);
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
      if (d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
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
    var checkDate =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    while (studiedDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }
}
