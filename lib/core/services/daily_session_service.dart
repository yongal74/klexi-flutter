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
    // 새 단어는 사용자가 고른 레벨부터. 예전엔 저장소 순서(레벨 1 먼저)라
    // TOPIK 4 를 고른 유료 사용자도 레벨 1 기초 단어만 받았다.
    final preferredLevel = isPremium ? userLevel : 1;

    for (final w in all) {
      final rec = records[w.id];
      if (rec == null) {
        if (isPremium || w.level == 1) newWords.add(w);
      } else if (rec.isDueToday) {
        dueWords.add(w);
      }
    }
    newWords.sort((a, b) {
      final da = (a.level - preferredLevel).abs() +
          (a.level < preferredLevel ? 10 : 0);
      final db = (b.level - preferredLevel).abs() +
          (b.level < preferredLevel ? 10 : 0);
      return da.compareTo(db);
    });

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
    final nowDt = DateTime.now();
    final now = nowDt.millisecondsSinceEpoch;
    final today = _dayKey(nowDt);

    // 학습한 날짜 목록을 단어별로 남긴다. lastStudied 는 복습할 때마다 덮어써져서,
    // 예전엔 어제 단어를 오늘 복습하면 어제 기록이 사라져 연속학습일·주간 그래프가 깨졌다.
    final days = <int>[
      ...((existing?['days'] as List?)?.cast<int>() ?? const <int>[]),
    ];
    if (!days.contains(today)) days.add(today);
    if (days.length > 120) days.removeRange(0, days.length - 120);

    if (existing == null) {
      await box.put(wordId, {
        'lastStudied': now,
        'timesStudied': 1,
        'easyCount': wasEasy ? 1 : 0,
        'hardCount': wasEasy ? 0 : 1,
        'days': days,
      });
    } else {
      await box.put(wordId, {
        'lastStudied': now,
        // "Again"(어려움)이면 간격 사다리를 처음으로 되돌려 내일 다시 나오게 한다
        'timesStudied':
            wasEasy ? ((existing['timesStudied'] as int?) ?? 0) + 1 : 1,
        'easyCount': ((existing['easyCount'] as int?) ?? 0) + (wasEasy ? 1 : 0),
        'hardCount': ((existing['hardCount'] as int?) ?? 0) + (wasEasy ? 0 : 1),
        'days': days,
      });
    }
  }

  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static DateTime _fromDayKey(int k) =>
      DateTime(k ~/ 10000, (k ~/ 100) % 100, k % 100);

  /// 모든 단어 기록에서 "공부한 날" 집합을 모은다. build54 이전 기록은
  /// 날짜 목록이 없으므로 lastStudied 하루만 쓴다.
  Set<DateTime> _studiedDays() {
    final box = _box;
    final result = <DateTime>{};
    if (box == null) return result;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final days = (raw['days'] as List?)?.cast<int>();
      if (days != null && days.isNotEmpty) {
        result.addAll(days.map(_fromDayKey));
      } else {
        final ms = (raw['lastStudied'] as int?) ?? 0;
        if (ms == 0) continue;
        final d = DateTime.fromMillisecondsSinceEpoch(ms);
        result.add(DateTime(d.year, d.month, d.day));
      }
    }
    return result;
  }

  /// 오늘 공부한 단어 id. 퀴즈·복습은 이 단어로 낸다(안 본 단어로 퀴즈 내지 않도록).
  List<String> getTodayStudiedIds() {
    final box = _box;
    if (box == null) return const [];
    final today = DateTime.now();
    final ids = <String>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(
          (raw['lastStudied'] as int?) ?? 0);
      if (d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
        ids.add(key as String);
      }
    }
    return ids;
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

  /// Records a review (1=Again, 3=Good, 5=Easy).
  /// 예전엔 quality >= 4 만 "쉬움"이라 "Good"(3)도 어려움으로 기록됐다.
  Future<void> recordReview(String wordId, int quality) =>
      recordStudy(wordId: wordId, wasEasy: quality >= 3);

  /// Returns the total number of distinct words ever studied.
  Future<int> getTotalWordsStudied() async {
    return _box?.keys.length ?? 0;
  }

  /// Returns the count of words studied per day for the last 7 days (Mon→Sun of current week).
  Future<List<int>> getWeekActivity() async {
    final box = _box;
    if (box == null) return List.filled(7, 0);

    // Map: date → number of words studied that day (날짜 목록 기준)
    final dayCounts = <DateTime, int>{};
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      final days = (raw['days'] as List?)?.cast<int>();
      if (days != null && days.isNotEmpty) {
        for (final k in days) {
          final day = _fromDayKey(k);
          dayCounts[day] = (dayCounts[day] ?? 0) + 1;
        }
      } else {
        final ms = (raw['lastStudied'] as int?) ?? 0;
        if (ms == 0) continue;
        final d = DateTime.fromMillisecondsSinceEpoch(ms);
        final day = DateTime(d.year, d.month, d.day);
        dayCounts[day] = (dayCounts[day] ?? 0) + 1;
      }
    }

    // Mon(0)→Sun(6) of the current week. 날짜 생성자로 계산해 서머타임 경계에서
    // 하루 밀리던 문제를 피한다.
    final today = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(
          today.year, today.month, today.day - (today.weekday - 1) + i);
      return dayCounts[day] ?? 0;
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
    final studiedDates = _studiedDays();
    if (studiedDates.isEmpty) return 0;

    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);
    // 오늘 아직 공부 전이면 어제부터 센다. 예전엔 30일 연속이어도
    // 매일 아침 첫 카드 전까지 0 으로 보였다.
    if (!studiedDates.contains(checkDate)) {
      checkDate = DateTime(now.year, now.month, now.day - 1);
    }

    int streak = 0;
    while (studiedDates.contains(checkDate)) {
      streak++;
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
    }
    return streak;
  }
}
