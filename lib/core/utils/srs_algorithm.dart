/// SM-2 기반 간격 반복 학습 알고리즘
/// 기존 lib/srs.ts 로직을 Dart로 포팅
class SrsAlgorithm {
  static const double _initialEaseFactor = 2.5;
  static const double _minEaseFactor = 1.3;

  /// quality: 0~5 (0~2 = 오답, 3~5 = 정답)
  static SrsCard update(SrsCard card, int quality) {
    assert(quality >= 0 && quality <= 5);

    double easeFactor = card.easeFactor;
    int interval = card.interval;
    int repetitions = card.repetitions;

    if (quality >= 3) {
      // 정답
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * easeFactor).round();
      }
      repetitions++;
    } else {
      // 오답 — 처음부터 다시
      repetitions = 0;
      interval = 1;
    }

    // Ease factor 조정
    easeFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (easeFactor < _minEaseFactor) easeFactor = _minEaseFactor;

    final nextReview = DateTime.now().add(Duration(days: interval));

    return SrsCard(
      wordId: card.wordId,
      easeFactor: easeFactor,
      interval: interval,
      repetitions: repetitions,
      nextReview: nextReview,
      lastReview: DateTime.now(),
    );
  }

  static SrsCard createNew(String wordId) => SrsCard(
    wordId: wordId,
    easeFactor: _initialEaseFactor,
    interval: 1,
    repetitions: 0,
    nextReview: DateTime.now().add(const Duration(days: 1)),
    lastReview: DateTime.now(),
  );

  static bool isDue(SrsCard card) =>
      DateTime.now().isAfter(card.nextReview) ||
      DateTime.now().isAtSameMomentAs(card.nextReview);
}

class SrsCard {
  final String wordId;
  final double easeFactor;
  final int interval;       // days
  final int repetitions;
  final DateTime nextReview;
  final DateTime lastReview;

  const SrsCard({
    required this.wordId,
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
    required this.nextReview,
    required this.lastReview,
  });

  Map<String, dynamic> toJson() => {
    'wordId': wordId,
    'easeFactor': easeFactor,
    'interval': interval,
    'repetitions': repetitions,
    'nextReview': nextReview.toIso8601String(),
    'lastReview': lastReview.toIso8601String(),
  };

  factory SrsCard.fromJson(Map<String, dynamic> json) => SrsCard(
    wordId: json['wordId'] as String,
    easeFactor: (json['easeFactor'] as num).toDouble(),
    interval: json['interval'] as int,
    repetitions: json['repetitions'] as int,
    nextReview: DateTime.parse(json['nextReview'] as String),
    lastReview: DateTime.parse(json['lastReview'] as String),
  );
}
