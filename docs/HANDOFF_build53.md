# build53 인수인계 — 2026-09-10 세션

> 작성: 구현 봇(트랙 B, `claude-84`). PM 봇 `claude-ad`, 트랙 A 서브에이전트와 병렬 진행.
> 기준 커밋: `master` = `1e0c3e3` (GitHub `yongal74/klexi-flutter` 푸시 완료).
> 계획서: [`UPGRADE_PLAN_build53.md`](./UPGRADE_PLAN_build53.md)

---

## 1. 한 줄 요약

**P0(WP-00~05) 코드 전부 완료, CI 완전 초록.** 백엔드 배포와 릴리즈 빌드는 미실행 — 다음 세션.

---

## 2. 현재 상태 스냅샷

| 항목 | 상태 |
|---|---|
| 라이브 버전 | build52 (1.0.6+52), 2026-09-02 Play 게시 |
| 작업 중 버전 | **1.0.6+53** (`pubspec.yaml` 반영됨) |
| `flutter analyze --no-fatal-infos` | ✅ 에러 0 / 경고 0 (info 128) |
| `dart format lib/ test/` | ✅ 클린 |
| GitHub Actions CI | ✅ **Analyze & Test 통과 / Build Android AAB 통과** |
| `flutter test` | ✅ CI(ubuntu)에서 92건 전부 통과 · ❌ Windows 로컬은 여전히 무응답 |
| debug APK 빌드 | ✅ 성공 (Gradle 298초) |
| 에뮬레이터 스모크 | ❌ **미완** — 3절 참조 |
| Firebase 배포 | ❌ 미실행 — **형님 승인만 남음**(백엔드는 현재 정상 가동 중, 09-10 11:59Z `/api/health` 200) |
| 릴리즈 AAB | ❌ 미실행 |

---

## 3. 🔴 다음 세션에서 **가장 먼저** 할 일

### 3-1. 에뮬레이터 스모크 (이번 세션 미완, 최우선)

`Medium_Phone_API_36.1` 이 40분 넘게 `adb devices` 에서 `offline` 에 머물러 부팅을
끝내지 못했다. 강제 종료 후 `-no-snapshot -gpu swiftshader_indirect` 로 콜드 부팅을
재시도했으나 이 세션 안에 확인하지 못했다. **코드는 컴파일·정적분석·CI 테스트를
모두 통과했지만, 아래 4가지는 실행으로 확인된 적이 없다.**

확인할 항목:

| # | 항목 | 기대 동작 | 근거 코드 |
|---|---|---|---|
| (a) | 세션 복원 | 로그인 후 앱 종료 → 재실행 시 **로그인 화면 없이 홈 직행** | `main.dart` 의 `runApp` 전 `restoreSession()` + `currentUserProvider` 시드 |
| (b) | 계정 삭제 | 삭제 후 Hive 박스·prefs·temp 파일이 실제로 사라짐 | `auth_service.dart` `_wipeLocalData()` |
| (c) | 게스트 업그레이드 | 게스트 학습기록이 구글 계정으로 이관됨 | `daily_session_service.dart` `migrateUser()` |
| (d) | 박스 초기화 누락 여부 | 게스트 로그인 / 구글 로그인 / 게스트→구글 세 경로 모두에서 첫 학습 진입 시 `StateError('not initialised')` 가 **안 터짐** | `auth_screen.dart` 의 `context.go` 직전 `await init(uid)`, `upgradeGuestWithGoogle()` |

(d)는 코드를 읽어 세 경로 모두 `init(uid)` 가 걸린 것을 확인했으나 **실행 확인은 못 했다.**

검증 명령:
```powershell
& "C:\androidsdk\platform-tools\adb.exe" devices
flutter run -d emulator-5554
& "C:\androidsdk\platform-tools\adb.exe" shell dumpsys alarm | Select-String twentykorean   # WP-04 리마인더 예약
& "C:\androidsdk\platform-tools\adb.exe" reboot                                             # 재부팅 후 알람 생존
```
에뮬레이터가 계속 안 뜨면 `Pixel_7` AVD 로 바꾸거나 형님 실기기로 대체한다.

### 3-2. 백엔드 배포 (형님 결정 대기)

**선결 조건 없음 — 형님 승인만 남았다.**
2026-09-10 11:59Z 직접 확인: `GET /api/health` → **200** (`{"status":"ok"}`),
`GET /` → 200. 즉 Blaze 결제는 활성이고 `api` 함수도 살아 있다.
(2026-09-01 오전 기록의 `billing is disabled` 는 같은 날 오후에 해소됐다.
이 세션에서 그 옛 기록을 근거로 "배포 실패 가능"이라고 보고한 것은 오류였다.)

```powershell
firebase deploy --only functions,hosting --project klexi-30ab5
```
`firebase.json` 에 predeploy 훅(`npm ci` + `npm run build`)이 들어가 있으므로
빌드는 자동으로 선행된다.

배포 후 증빙(계획서 D-13):
```
/api/health                                  -> 200
/api/ai-chat  토큰 없이 POST(구 클라 형식)     -> soft 모드이므로 SSE 응답 (401 아님)
/api/ai-chat  Authorization: Bearer garbage   -> 401
1MB 본문                                      -> 400
https://klexi-30ab5.web.app/                 -> 랜딩 페이지
https://klexi-30ab5.web.app/privacy          -> 200
```

### 3-3. 🔴 `AUTH_MODE` 전환 — 잊으면 보안 구멍이 남는다

현재 서버 인증은 **`soft`** 로 배포된다(`functions/src/auth.ts` 의 `defineString("AUTH_MODE", { default: "soft" })`).

- `soft` = 토큰이 **아예 없으면 통과**(`console.warn` 으로 계수), 토큰이 **있는데 무효면 401**
- `hard` = 토큰이 없어도 401

soft 인 이유: 라이브 build52 앱은 `Authorization` 헤더를 보내지 않는다. 곧바로 hard 로
배포하면 **배포 즉시 기존 사용자 전원의 AI 채팅·발음 채점이 401 로 죽는다.**

**hard 전환 조건** (둘 중 먼저 오는 시점, PM 결정으로 실행):
1. Play Console 버전 분포에서 **build53 이 90% 이상**, 또는
2. **build53 프로덕션 출시 후 14일 경과**

전환 방법: 코드 수정 없이 배포 파라미터로 `AUTH_MODE=hard` 지정 후 재배포.
전환 전까지는 무인증 요청이 계속 통과하므로 **비용 방어가 절반만 걸려 있는 상태**다.
(입력 검증·16KB 상한·maxInstances 5·캐시키 mode 분리·SSE abort 는 soft 에서도 즉시 효력.)

### 3-4. 릴리즈 빌드 (P1 일부 반영 후)

```powershell
flutter build appbundle --release
& "C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe" -verify -verbose:summary -certs build\app\outputs\bundle\release\app-release.aab
```
서명 확인 문자열: `7EDE361C` (build51/52 와 동일해야 한다).
산출물은 `KlexiDev\releases\klexi-v1.0.6-build53.aab` 로 저장.

---

## 4. 이번 세션에 완료한 것

### 트랙 B (`lib/**`, `test/**`, `pubspec.yaml`, `.github/**`)

| 커밋 | WP | 내용 |
|---|---|---|
| `992d93b` | WP-00 | `dart format lib/ test/` — 85파일, 형식만(단독 커밋) |
| `b619eee` | WP-00 | CI 복구: Flutter 핀 3.41.4, `firebase_options.dart` placeholder 생성, 키스토어 경로 정정, 서명 시크릿 없으면 릴리즈 단계 skip, 없는 asset 디렉토리 제거 |
| `8eec651` | WP-03+07a | 세션 복원 / uid별 학습기록 박스 / 계정삭제 실제 정리 / RC logIn·logOut / 게스트 업그레이드 배선 / 세션 선택 인자 `required` 화 |
| `3c51a6d` | WP-04 | 리마인더 `inexactAllowWhileIdle` 전환, `flutter_timezone`, 예약 실패 표면화, 가짜 스위치 제거, Slow TTS 실연결, `1.0.6+53` |
| `baff556` | WP-02 | 프리미엄 TTS 를 실존 라우트 `/api/ai-tts` 로 통일, `api_client.dart` + ID 토큰 인터셉터, TTS 캐시 SHA-1·50MB LRU, `fcm_token` prefs 제거 |
| `216e470` | WP-01b | `firebase.json` predeploy 훅 + `hosting.public` → `web`, `AUTH_MODE` soft/hard |
| `6bd778f` | WP-00b | CI placeholder 들여쓰기 정정 (검증 환경 오류 수정 — 7절 참조) |
| `1e0c3e3` | WP-07b | 문법 예문 영어 번역 74건 + 누락 `meaning` 1건 |

### 트랙 A (`functions/**`, `web/**`, 매니페스트·gradle·proguard, `docs/**`, `README.md`)

| 커밋 | WP | 내용 |
|---|---|---|
| `9e5774d` | WP-01 | 백엔드 ID 토큰 인증 + 입력 검증(role 화이트리스트·길이·개수·16KB) + `maxInstances: 5` + SSE abort + 캐시키에 mode |
| `fb9ccac` | WP-12 | `functions/src/polar.ts` 삭제, `@polar-sh/sdk` 제거 |
| `84ba8d8` | WP-05 | privacy/delete-account 문서 현행화, 매니페스트(리시버·`RECEIVE_BOOT_COMPLETED`·`enableOnBackInvokedCallback`), 백업 규칙 2종, `useLegacyPackaging` 제거, proguard keep |
| `5b7c887` | WP-16 | 호스팅 루트를 정적 랜딩 페이지로 교체 |
| `0d86dbe` | WP-15 | `docs/` 저장소 편입, ADR-004 정정, ADR-009·010 신설, CHANGELOG·README 갱신 |
| `d2eb7c4` | — | 트랙 A → master 병합 (`--no-ff`, **충돌 0건**) |

---

## 5. 미완 — 다음 세션 대상 (P1)

계획서 순서 그대로. 형님 토큰 예산 때문에 이번 세션에서 의도적으로 넘겼다.

| WP | 내용 | 비고 |
|---|---|---|
| WP-06 | 결제 UX — `_PremiumSheet` 가 구매 없이 `Navigator.pop`, offerings 실패 시 스피너 무한, 트라이얼 문구 하드코딩 | 수익 직결. **P1 중 1순위** |
| WP-07 (나머지) | 테마 팩 단어 카드가 항상 엉뚱한 단어, cloze 게이트 없음, 퀴즈 옵션 2~3개, `SessionSelector` 추출 | 07a(required 인자)·07b(번역)만 완료 |
| WP-08 | 발음 코치 — 오프라인 결과가 0점으로 표시, 빈 세션 로딩 무한, 한국어 스낵바 | 파일명·contentType 은 WP-02 에서 선반영 완료 |
| WP-09 | 온보딩 3페이지, 설정 버전이 '1.0.0' 고정, 한국어 UI 문자열 영어화, 대비·터치타깃 |  |
| WP-10 | 채팅 오류 표시·히스토리 컨텍스트 복원·온라인 점, 알림 딥링크(`consumePendingRoute` 호출 0건) |  |
| WP-11 | 성능 — 워드네트워크 프레임, 세션 메모이즈, `Word` 의 `HiveObject` 제거, 폰트 번들 |  |
| WP-12 (lib) | `polar_service.dart` import 5곳 교체 후 삭제, `srs_algorithm.dart` 삭제 | 트랙 A 가 functions 쪽만 처리 |
| WP-13 | `withOpacity`→`withValues` (info 128건의 대부분), `Color(0x…)` 토큰화, `TopikBadge` 추출, `flutter_markdown` 단종 대응 |  |
| WP-14 | 테스트 — **6절 주의사항 반드시 읽을 것** |  |

### WP-05 중 `lib/` 몫 (트랙 A 가 넘긴 것, 미착수)
- `notification_settings_screen` 의 `PopScope` 저장 동작을 **제스처 백으로 검증** — 트랙 A 가 `enableOnBackInvokedCallback="true"` 를 켰으므로 Android 13+ 예측형 뒤로가기가 활성화됐다.
- `main.dart` 에 `SystemChrome.setSystemUIOverlayStyle` 전역 설정 + 다크 배경 화면에 `AnnotatedRegion`.
- RECORD_AUDIO 최초 요청 전 rationale 다이얼로그.

---

## 6. ⚠️ WP-14(테스트) 할 때 반드시 볼 것

계획서 §5 는 "가짜 테스트 6개를 삭제"하라고 적혀 있다. **일괄 삭제하지 말 것.**

이번 세션에 CI 를 살리자마자 `flutter test` 가 **진짜 결함 2건**을 잡았다:
`grammar_data.dart` 의 예문 324개 중 **74개(23%)에 영어 번역이 비어 있었고**,
패턴 `g2-11` 은 `meaning` 이 빈 문자열이었다. Grammar Coach 는 `PaywallGate` 가
걸린 **유료 기능**이므로, 유료 사용자가 한국어 예문만 보고 번역은 빈칸을 보고 있었다.

즉 "콘텐츠 불변식 테스트"는 이 프로젝트에서 실제로 값을 한다.
삭제 대상 6개도 **한 건씩 무엇을 검증하는지 읽고 판단**해야 한다.

또한 **`flutter test` 는 CI(ubuntu)에서 정상 동작한다** — 92건이 2분 23초에 끝난다.
멈추는 것은 Windows 로컬뿐이므로, 계획서 §5 의 "이 머신 이슈면 CI 에서만 test 실행"
쪽으로 확정하고 원인 규명은 우선순위를 낮춰도 된다.

---

## 7. 이번 세션의 교훈 (같은 실수 방지)

1. **포맷·린트 검증은 실제 패키지 컨텍스트에서 돌린다.**
   CI placeholder 의 포맷을 스크래치 디렉토리(최소 pubspec, `.dart_tool` 없음)에서
   확인했더니, dart 가 패키지 언어 버전(`sdk: ^3.6.0`)을 못 읽고 최신 tall style 을
   적용했다. 그 결과를 정본으로 믿고 **원래 맞던 들여쓰기를 틀린 쪽으로 고쳤다.**
   격리 디렉토리는 언어 버전이 달라져 결과가 뒤집힌다.

2. **`x ?? ref.read(provider)` 는 좌변이 nullable 이면 `read<T>` 의 `T` 까지
   nullable 로 하향 추론된다.** `TtsSpeed?`·`bool?` 두 번 실제 컴파일 에러가 났다.
   좌변에 명시적 타입을 붙이면 해결된다.

3. **provider 파일이 서비스 파일을 import 하면 순환이 생겨 타입 추론이 깨진다.**
   `tts_speed_provider` 가 `TtsSpeed` 를 쓰려고 `tts_service` 를 import 했더니
   추론이 nullable 로 무너졌다. enum 참조를 없애 순환을 끊었다.

4. **`required` 로 바꾸면 컴파일러가 호출처를 전부 잡아준다.**
   `getTodaySession`/`getTodayWordIds` 의 선택 인자를 `required` 로 바꾸자
   계획서가 지목한 4개 화면이 에러 8건으로 정확히 드러났다. 선택 인자에 기본값을
   두는 것이 회귀(build48 #19)를 되살린 원인이었다.

5. **계정 삭제는 서버 삭제를 먼저 확정한 뒤 로컬을 지운다.**
   계획서 §6.3 의 순서(로컬 먼저)는 재인증 창을 사용자가 닫았을 때
   **학습기록만 날아가고 계정은 살아남는** 비대칭 실패를 만든다. PM 이 D-10 으로
   개정을 승인했다.

6. **트랙 분리(파일 경계)는 실제로 작동했다.** 트랙 A/B 를 git worktree 로 나눠
   병렬 진행했고 병합 충돌이 0건이었다. 다만 **병렬은 시간을 줄이지 토큰을 줄이지
   않는다**(각 트랙이 따로 읽고 검증하므로 총 사용량은 오히려 늘어난다).

---

## 8. 형님 몫 (PM 이 시점에 맞춰 요청)

| # | 항목 | 시점 |
|---|---|---|
| 1 | ~~Firebase Blaze 결제 확인~~ — **이미 활성, 조치 불필요**(09-10 11:59Z `/api/health` 200 확인) | — |
| 2 | OpenAI 대시보드 월 사용 **하드캡** 설정 | 백엔드 배포 전 |
| 3 | Play Console 데이터 보안 양식에 **광고ID·음성녹음(제3자 OpenAI)** 반영 | build53 제출 전 |
| 4 | GitHub Actions 시크릿 `KEYSTORE_BASE64`·`KEY_PROPERTIES` 등록 | 급하지 않음(릴리즈는 로컬 빌드, 없으면 CI 가 자동 skip) |
| 5 | RC 빌드 실기기 테스트 — 구글 로그인·복원, 구독(라이선스 테스터), 푸시 수신, 마이크 채점 | 릴리즈 빌드 후 |
| 6 | build53 Play 업로드·단계적 출시 | 마지막 |
| 7 | klexi.app 도메인 등록대행업체 확인 (DNS 안 뜸) | 별건 |

---

## 9. 참고 — 파일 경계 (트랙 병렬 시 재사용)

| 트랙 | 담당 경로 |
|---|---|
| A | `functions/**`, `web/**`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/**`, `android/app/build.gradle.kts`, `android/app/proguard-rules.pro`, `docs/**`, `README.md` |
| B | `lib/**`, `test/**`, `pubspec.yaml`, `.github/**` |
| 어느 쪽도 아님 | `firebase.json` — PM 이 그때그때 지정 (D-12 에서 B 로 지정됨) |

**절대 커밋·수정 금지**: `android/klexi-release.jks`, `android/key.properties`,
`android/app/google-services.json`, `lib/firebase_options.dart`, `functions/.env`
