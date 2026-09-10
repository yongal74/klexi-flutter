# ADR-010: Study Records Are Scoped per Firebase UID

**Date:** 2026-09-10
**Status:** Accepted — 구현은 build53 WP-03(트랙 B)
**Deciders:** Klexi PM 봇(claude-ad)
**관련 작업:** build53 WP-03, ADR-004 정정

---

## Context

`DailySessionService` 는 Hive 박스 `'study_records'` **하나**를 열었다. uid 가 붙지 않았다. 결과:

1. 한 기기에서 계정을 바꿔도 같은 학습기록을 본다 — 기기 내 사용자 간 데이터 공유.
2. `AuthService.deleteAccount()` 는 `study_records_$uid` 를, 게스트 마이그레이션은
   `study_records_<guest>` 를 지우려 했는데 **둘 다 존재하지 않는 박스**였다.
   즉 계정 삭제가 학습기록을 전혀 지우지 못했다(Play 계정삭제 정책 위반 소지).
3. 게스트 → 구글 업그레이드 경로(`upgradeGuestWithGoogle()`)는 호출된 적조차 없었다.

## Decision

- 박스명을 **`study_records_$uid`** 로 바꾼다. 게스트도 `study_records_guest_xxx` 형태로 자기 박스를 갖는다.
- 앱 시작 시 1회 마이그레이션: `Hive.boxExists('study_records')` 이면 현재 uid 박스로 복사한 뒤
  원본을 삭제한다. 실패하면 **원본을 남기고** Crashlytics 에 비치명 기록(데이터 손실 방지 우선).
- `AuthService` 가 `Stream<KlexiUser?>` 를 노출하고 `DailySessionService` 가 구독해 박스를 전환한다.
  화면은 `currentUserProvider` 만 본다.
- 계정 삭제 순서: RevenueCat `logOut` → FCM `deleteToken` → Hive 박스 `deleteFromDisk` →
  `prefs.clear()` → temp 파일 → `user.delete()`(필요 시 재인증) → 상태 초기화 → `/auth`.
  **서버(Firebase Auth) 삭제를 마지막에** 두어 도중 실패 시 재시도가 가능하게 한다.

## Consequences

- **Positive**: 계정 삭제가 실제로 로컬 학습기록을 지운다 — Play 정책 요구사항 충족.
- **Positive**: 기기 공유 시 계정별 진도가 분리된다.
- **Negative**: 기존 사용자의 `'study_records'` 는 **첫 로그인 사용자 한 명에게만** 승계된다.
  같은 기기를 두 사람이 써 왔다면 나중 사용자는 빈 상태로 시작한다. 서버 동기화가 없는 구조상
  더 나은 대안이 없다고 판단했다.
- **Watch**: 학습기록은 여전히 **로컬 전용**이다. 기기를 바꾸면 진도가 사라진다(백업 규칙으로
  app_flutter 를 백업 대상에 넣어 완화 — WP-05). 서버 동기화는 build54 이후 과제.
