# ADR-004: Spaced Repetition — Fixed Interval Ladder (not SM-2)

**Date:** 2026-03 (2026-09-10 정정)
**Status:** Accepted — **2026-09-10 정정판**. 원문은 SM-2 를 채택했다고 기술했으나 코드에 그런 구현은 없었다.
**Deciders:** Klexi dev team

---

## Context

Klexi's core value proposition is efficient vocabulary retention. A spaced repetition system (SRS)
schedules reviews at optimal intervals to maximize long-term retention with minimal study time.

## Decision

`DailySessionService` 는 **고정 간격 사다리(fixed interval ladder)** 를 쓴다. SM-2 가 아니다.

### Review intervals — `StudyRecord.intervalDays`

```dart
const intervals = [1, 3, 7, 14, 30, 60];          // 일 단위
int idx = (timesStudied - 1).clamp(0, 5);         // 학습 횟수로만 결정
if (hardCount - easyCount > 2) idx = (idx - 1).clamp(0, 5);  // 어려워하면 한 단계 후퇴
```

- 간격을 정하는 입력은 `timesStudied`, `easyCount`, `hardCount` 세 개뿐이다.
- **ease factor(EF)는 존재하지 않는다.** 저장 필드에도 없고 계산하지도 않는다.
- 품질 점수는 `recordReview(wordId, quality)` 가 `wasEasy: quality >= 4` 로 **이진화**해서 버린다.

### StudyRecord 실제 필드

```dart
StudyRecord { wordId, lastStudied, timesStudied, easyCount, hardCount }
```

### Session composition (20 words/day)

1. **Due reviews** — `lastStudied + intervalDays` 가 지난 단어
2. **New words** — 학습 이력이 없는 단어
3. **Filler** — 사용자 레벨의 나머지 단어

### Storage

build52 까지: Hive box `'study_records'` — **uid 가 붙지 않은 단일 박스**라 한 기기의 여러 계정이
학습기록을 공유했다. build53(WP-03)에서 `study_records_$uid` 로 분리한다 → ADR-010.

## 왜 정정했는가

`lib/core/utils/srs_algorithm.dart` 에 SM-2 구현이 있었지만 **어디서도 import 되지 않았다.**
문서는 그 파일을 보고 쓰였고, 실제로 돌아간 코드는 위 사다리였다. build53(WP-12)에서 죽은
`srs_algorithm.dart` 를 삭제하면서 문서도 실물에 맞춘다.

## Consequences

- **Positive**: 단순하고 예측 가능. 오프라인 동작, 저장 용량 작음.
- **Negative**: 개인별 난이도 적응이 없다. 같은 단어를 모두가 같은 간격으로 본다.
- **Watch**: FSRS/SM-2 로 올릴 경우 `StudyRecord` 스키마 변경 + Hive 마이그레이션이 필요하다.
- **Lesson**: "구현 파일이 있다" ≠ "그 코드가 실행된다". ADR 을 쓸 때 import 그래프를 확인할 것.
