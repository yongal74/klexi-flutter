# Changelog — Klexi

All notable changes to Klexi are documented here.

---

## [1.0.6+54] — 2026-09-25

> build53 을 건너뛰고 Play 에 올리는 버전. 서버는 09-25 23:40 KST 배포 완료
> (OpenAI 키 교체 · Secret Manager). 상세는 `docs/HANDOFF_build54.md`.

### Fixed — 운영
- **AI 기능 전면 장애 해소** — OpenAI 키 무효(401)로 Dalli·AI 음성·발음 채점이 모두 500 이었다.
  새 키를 Secret Manager 에 등록하고 재배포. 운영 스모크 통과(채팅 SSE 200, TTS audio/mpeg,
  발음 채점 200·score 100, 가짜 토큰 401, `/api/health?deep=1` ok).
- **발음 채점 업로드** — Cloud Functions 가 본문을 미리 읽어 multer 가 파일을 받지 못했다.
  busboy + `req.rawBody` 로 교체, 파일 머리로 형식 판별(build52 호환).

### Fixed — 앱
- 결제 동선: 설정의 가짜 체험 시트 제거→실제 결제 화면, 가격 실패 Retry, 트라이얼·할인 문구를
  스토어 상품에서 계산, 게스트는 결제 전 Google 로그인, 라우터 1회 생성(로그인 시 스택 유실).
- 학습 데이터: 연속학습일, 평가 매핑, Again 재등장, 퀴즈·복습 대상, 통계 즉시 갱신,
  로그아웃 시 사용자 상태 초기화, 게스트 재진입 시 기록 복구.
- 기능: 테마 단어카드, 발음 오류 표시(0점 대신), Dalli 오류·스트림 처리·맥락 복원,
  빈칸퀴즈 레벨, 보기 중복.
- UX: 온보딩 + 알림 옵트인(실행 시 권한 팝업 제거), 알림 설정 즉시 적용, 영어 사용자용 문구.

### Added — 서버
- 경로별 본문 크기 상한·사용자/IP 호출 제한, `/api/health?deep=1`, `AUTH_MODE=soft` 고정,
  CI 에 functions 빌드.

---

## [1.0.6+53] — 2026-09-10 (미출시 — 54 로 대체)

> build53 은 2트랙 병렬 작업이었다(트랙 A = 백엔드·정책·문서, 트랙 B = 앱 코어).
> 두 트랙 모두 병합 완료. 미출시 — 에뮬레이터/실기기 검증과 백엔드 배포가 남아 있다.

### Fixed — 한 번도 동작한 적 없던 기능들 (트랙 B)

리뷰가 드러낸 공통 성격: 코드는 존재하는데 호출되지 않거나, 존재하지 않는 것을
호출하고 있었다. 정적 분석으로는 잡히지 않고 실행해야 드러나는 부류다.

- **프리미엄 TTS (WP-02)** — `tts_service.dart` 가 `/api/tts/clova`, `/api/tts/google` 를
  호출했으나 서버에 그런 라우트가 존재한 적이 없다. 항상 404 → 기기 TTS 로 폴백했고,
  즉 **유료 음성이 한 번도 나온 적이 없다**. 실존 라우트 `/api/ai-tts`(OpenAI TTS,
  voice=nova) 하나로 통일. `app_strings` 의 "Naver CLOVA / Google Neural2" 허위 문구를
  'AI voice (premium)' 로 정정.
- **세션 복원 (WP-03)** — `AuthService.restoreSession()` 을 호출하는 곳이 0건이라
  앱을 켤 때마다 로그인 화면이 떴다. `main.dart` 에서 `runApp` 전에 복원하고
  `currentUserProvider` 를 시드한다. 게스트도 prefs 의 `guest_` id 로 복원.
- **데일리 리마인더 (WP-04)** — `exactAllowWhileIdle` + 정확알람 권한 미선언 조합이라
  Android 12+ 에서 `exact_alarms_not_permitted` 로 **예약 자체가 실패**했고, 호출부가
  예외를 삼켜 화면에는 "Settings saved" 만 떴다. `inexactAllowWhileIdle` 로 전환
  (학습 리마인더는 Play 의 정확알람 사용 자격이 없다), 실패를
  `NotificationScheduleException` 으로 던져 스낵바로 표시.
- **로컬 타임존 (WP-04)** — `tz.setLocalLocation` 미호출로 `tz.local` 이 UTC 였다.
  예약 시각이 통째로 어긋나고 서머타임 전환 후 1시간 밀렸다. `flutter_timezone` 도입.
- **계정 삭제 (WP-03)** — 삭제 대상 박스명이 `study_records_$uid` 였는데 실제 박스는
  `study_records` 하나였다. 즉 학습기록이 지워지지 않았다. 박스를 uid 별로 나누고,
  RevenueCat 로그아웃·FCM 토큰 삭제·prefs·임시파일(`klexi_pronunciation.m4a`,
  `tts_cache/`)까지 정리한다. 각 단계는 독립적으로 실패를 삼켜 하나가 실패해도
  나머지를 시도한다.
- **게스트 → Google 업그레이드 (WP-03)** — `upgradeGuestWithGoogle()` 호출처가 0건이었다.
  설정 프로필 카드에 "Sign in with Google to back up progress" 버튼으로 연결.
- **구독이 계정이 아니라 기기에 묶여 있던 문제 (WP-03)** — `Purchases.logIn/logOut`
  호출이 0건이라 로그아웃·계정삭제 후에도 premium 이 유지됐다.

### Fixed — 유료 사용자에게만 나타나던 결함 (트랙 B)

- **레벨 필터 회귀 (WP-07a)** — `getTodaySession`/`getTodayWordIds` 의
  `isPremium`·`userLevel` 이 **선택 인자**라 `quiz_screen`, `review_screen`,
  `sentence_practice_screen`, `pronunciation_screen` 네 곳이 인자 없이 호출했다.
  유료 사용자가 이 화면들에서 레벨 1 필러 단어만 받았다(build48 #19 의 회귀).
  두 인자를 `required` 로 바꿔 컴파일러가 호출처를 전부 잡게 했다.
- **Grammar Coach 번역 누락 (WP-07b)** — `grammar_data.dart` 예문 324개 중
  **74개(23%)에 `english` 가 빈 문자열**, 패턴 `g2-11` 은 `meaning` 이 빈 문자열이었다.
  Grammar Coach 는 `PaywallGate` 가 걸린 유료 기능이므로, 유료 사용자가 한국어 예문만
  보고 영어 번역은 빈칸을 보고 있었다. 74건 전부 각 문법 패턴의 뉘앙스에 맞춰 번역.
  CI 를 복구한 직후 `flutter test` 가 잡아낸 결함이다.

### Security — 클라이언트 측 (WP-02, 트랙 B)

- `lib/core/network/api_client.dart` 신설 — 백엔드 호출 단일 창구.
  `AuthInterceptor` 가 모든 `/api` 요청에 `Authorization: Bearer <ID 토큰>` 을 붙이고,
  토큰이 없으면(게스트) 왕복 없이 `AuthRequiredException` 으로 거절, 401 응답도
  같은 예외로 변환한다. `tts_service`·`pronunciation_service` 가 각자 갖고 있던
  Dio 정의 2개를 이 클라이언트로 통일. 채팅 SSE(`http.Request`)에도 Bearer 부착.
- `AUTH_MODE` 단계 전환 (WP-01b) — 서버 인증을 `soft`(토큰 없으면 통과 + 경고 로그,
  있는데 무효면 401)로 먼저 배포한다. 라이브 build52 는 `Authorization` 헤더를 보내지
  않으므로 곧바로 `hard` 로 가면 **기존 사용자 전원의 AI 기능이 401 로 죽는다.**
  `hard` 전환은 build53 이 90% 보급되거나 출시 14일 경과 시점에 재배포로 수행한다.
- FCM 토큰의 `SharedPreferences` 저장 제거 — prefs 는 Android 자동 백업 대상이라
  기기 교체 후 복원하면 옛 기기 토큰이 살아나 푸시가 조용히 죽는다.

### Changed — 데이터 모델·초기화 (트랙 B)

- 학습기록 Hive 박스를 `study_records` 하나에서 **`study_records_$uid`** 로 분리.
  기존 공용 박스는 첫 사용자에게 1회 이관 후 삭제하고, 이관 실패 시 원본을 남겨
  다음 실행에 재시도한다. 같은 기기의 서로 다른 사용자가 기록을 공유하던 문제가 해소된다.
- 콜드스타트에서 `PurchaseService.initialize()`·`FcmService().initialize()` 를
  `runApp` 이후로 이동. 이전에는 RevenueCat 네트워크 왕복이 첫 프레임을 막았다.
- 설정의 가짜 "Daily Reminders" 스위치 제거(화면 로컬 state 만 바꾸고 실제 예약과
  무관했다). "Slow TTS Speed" 를 `slowTtsProvider`+prefs 로 실연결 — 기존 발음 호출부
  6곳을 수정하지 않고도 설정이 반영된다.
- TTS 캐시 키를 `text.hashCode` → `SHA-1(text|voice|isSlow)` 로 교체. hashCode 는
  실행 간 안정성이 보장되지 않고 충돌하면 엉뚱한 음성이 재생된다.
  임시 디렉토리 조회를 1회만 캐시하고, 실행당 1회 50MB LRU 정리.
- 발음 업로드 파일명 `recording.webm` → `recording.m4a` + `contentType audio/mp4`.
  실제 녹음 포맷은 aacLc/.m4a 라 Whisper 가 포맷을 오인할 수 있었다.
- `pubspec.yaml` `1.0.6+52` → `1.0.6+53`. `flutter_timezone`·`crypto`·`http_parser` 추가.

### Security (WP-01) — 백엔드가 무인증이던 문제
- `functions/src/auth.ts` 신설. `/api/ai-chat`, `/api/ai-tts`, `/api/pronunciation` 에
  Firebase ID 토큰 검증(`admin.auth().verifyIdToken`)을 강제. `/api/health` 만 무인증 유지.
  이전에는 URL 만 알면 누구나 OpenAI 비용을 태울 수 있었다.
- `ai-chat`: `role` 을 user/assistant 로 제한해 `role:"system"` 프롬프트 주입 차단.
  content 1~1,000자, messages 1~8개, mode·userLevel 검증.
- 응답 캐시 키에 `mode` 추가 — 모드 간 캐시 오염 차단.
- 클라이언트가 연결을 끊으면 OpenAI 스트림을 `abort()` — 낭비되는 토큰 과금 제거.
- `ai-tts`: `voice` 화이트리스트 검증.
- `pronunciation`: 업로드 상한 10MB → 2MB, mimetype 화이트리스트, `text` 200자 상한
  (Levenshtein O(m·n) CPU DoS 차단). multer 오류를 500 대신 400 으로 변환.
- `express.json({ limit: "16kb" })` + 본문 파싱 오류 400 처리, `onRequest` `maxInstances: 5`.

### Policy / Android (WP-05)
- `web/privacy.html`: 광고 ID(AAID), 발음 코치 음성 → OpenAI Whisper(서버 미보관),
  AI 음성(OpenAI TTS) 항목 추가. AI 기능 인증 필요·모델 학습 미사용·아동 관련 절 추가.
- `web/delete-account.html`: 삭제 대상을 실동작 기준으로 정정(학습기록·채팅 히스토리·설정·
  캐시 오디오·FCM 토큰·RevenueCat 로그아웃).
- `res/xml/data_extraction_rules.xml`·`backup_rules.xml` 신설 — 백업 대상을
  `app_flutter`(Hive) + sharedpref 로 명시. 캐시 디렉토리는 Android 가 기본 제외.
- `AndroidManifest.xml`: `enableOnBackInvokedCallback="true"`(Android 13+ 예측형 뒤로가기),
  백업 규칙 연결, `RECEIVE_BOOT_COMPLETED`, flutter_local_notifications 의
  `ScheduledNotificationReceiver`/`ScheduledNotificationBootReceiver` 선언
  (플러그인 18.0.1 자체 매니페스트에 없어 재부팅 후 리마인더가 소멸하던 원인).
- `build.gradle.kts`: `packagingOptions.jniLibs.useLegacyPackaging` 제거 — 16KB 페이지 크기
  대응 및 설치 크기 축소.
- `proguard-rules.pro`: RevenueCat, flutter_local_notifications keep 규칙 추가.

### Removed (WP-12)
- `functions/src/polar.ts` 삭제(등록되지 않은 죽은 라우트, `POLAR_ACCESS_TOKEN`/`POLAR_ENV` 참조 포함).
- `@polar-sh/sdk` 의존성 제거, `@types/multer` 를 devDependencies 로 이동.
- `functions/package.json` description 을 실제 기능으로 정정.
- `functions/lib/`(빌드 산출물) git 추적 해제 — `.gitignore` 대상인데 일부만 커밋돼 src 와 불일치였다.

### Changed (WP-16)
- 호스팅 루트를 Flutter 웹 부트스트랩(purchases_flutter 미지원으로 빈 화면)에서
  정적 랜딩 페이지로 교체. `web/manifest.json` 의 Flutter 템플릿 잔재 정정.

### Docs (WP-15)
- `docs/` 를 저장소 안으로 편입(이전에는 `KlexiDev/docs/` 에만 있어 버전 관리 밖이었다).
- ADR-004 정정: 구현은 SM-2 가 아니라 **고정 간격 사다리** `[1,3,7,14,30,60]` 이다.
  SM-2 코드(`srs_algorithm.dart`)는 존재했지만 import 0건이었다.
- ADR-009(백엔드 ID 토큰 인증), ADR-010(학습기록 uid 분리) 추가.
- `README.md` 를 Flutter 템플릿 설명에서 실제 프로젝트 문서로 교체.

### CI (WP-00)
- `.github/workflows/ci.yml` Flutter 핀 3.29.0 → 3.41.4(`pubspec.lock` 이 ≥3.38.4 요구),
  키스토어 복원 경로 정정(`android/keystore/` 는 존재하지 않는 디렉토리였다),
  존재하지 않는 asset 디렉토리 항목 제거, `dart format lib/ test/` 적용.
- gitignore 대상인 `lib/firebase_options.dart` 를 워크플로 안에서 placeholder 로 생성.
  이 파일이 없으면 `main.dart:15` 에서 analyze 가 실패한다. Firebase **클라이언트**
  설정(공개 값)이므로 시크릿 대신 placeholder 를 쓴다.
- `KEYSTORE_BASE64`/`KEY_PROPERTIES` 시크릿이 없으면 서명·릴리즈 빌드 단계를 조건부
  skip. 시크릿 등록 전까지 CI 를 초록으로 유지한다.
- **결과: 이 저장소에서 CI 가 처음으로 전부 통과했다**(Analyze & Test ✓ /
  Build Android AAB ✓). `flutter test` 는 CI(ubuntu)에서 92건 전부 통과한다 —
  멈추는 것은 Windows 로컬뿐이다.

### Deploy (WP-01b)
- `firebase.json` 에 `functions.predeploy`(`npm ci` + `npm run build`) 추가.
  `functions/lib/` 는 git 추적 대상이 아니므로, 훅이 없으면 배포가 로컬에 남은 옛 빌드를
  올린다 — WP-01 의 인증이 빠진 코드가 배포될 수 있었다.
- `hosting.public` `"build/web"` → `"web"`. `build/` 는 gitignore 대상이라
  WP-16 의 랜딩 페이지가 실제로 서비스되지 않는 상태였다.

---

## [1.0.6+52] — 2026-09-01

> build51 의 versionCode 는 Play 에 이미 올라가 있으나 **그 소스가 커밋된 적이 없어**
> build50 이 REJECT 된 근본 원인이었다. build52 는 +51 을 건너뛴다.

### Added — Play 정책 준수 복원
- 계정 삭제 전 구간 구현: `AuthService.deleteAccount()` + `requires-recent-login` 재인증,
  설정 화면의 삭제 플로우(게스트/로그인 분기), 로컬 Hive 정리.
- 정적 `/privacy`, `/terms`, `/delete-account` 페이지 + 호스팅 rewrite 추가.
  (설정 화면의 Privacy/Terms 링크는 그때까지 빈 `onTap` 이었다.)

### Fixed — 감사 중 발견된 실동작 버그
- `FcmService.initialize()` 가 구현돼 있으나 `main.dart` 에서 **호출된 적이 없어**
  프로덕션에서 푸시 알림이 죽어 있었다.
- 로컬 알림 권한 요청이 iOS 만 처리 → Android 13+ 사용자는 `POST_NOTIFICATIONS` 를
  요청받은 적이 없어 데일리 리마인더가 OS 에서 조용히 폐기됐다.
- TTS 폴백 실패가 `catch (_) {}` 로 삼켜지던 것을 Crashlytics 기록으로 전환.

### Changed
- `AndroidManifest.xml` 에 INTERNET / RECORD_AUDIO / POST_NOTIFICATIONS 명시
  (플러그인 매니페스트 병합에 의존하지 않도록).
- functions: Node 20 → 22, 프로덕션 CORS 허용 목록에서 localhost 제거.
- functions: `npm audit fix` — 취약점 22건(critical 2 포함) → moderate 9건.

---

## [1.0.6+50] — 2026-04-15

### Changed
- versionCode 만 50 으로 상향(코드 변경 없음). Play 업로드용.

---

## [1.0.6+49] — 2026-04-15

### Changed
- versionCode 만 49 로 상향(코드 변경 없음). Play 업로드용.

---

## [1.0.6+48] — 2026-04-11

### Fixed (Critical)
- **tts_service.dart**: Premium TTS completely broken — `dioProvider` baseUrl was hardcoded placeholder `'https://your-server.com'` instead of `AppConfig.backendUrl`. CLOVA Voice and Google Neural2 TTS were silently failing for all premium users.
- **sentence_card_screen.dart**: `getTodayWordIds()` called without `isPremium` / `userLevel` parameters — premium users were receiving TOPIK level 1 words only in study sessions.
- **word_repository.dart**: Bidirectional `buildRelatedIdsMap()` could add duplicate entries to relationship lists (List instead of Set used for deduplication).

### Fixed (Import)
- **sentence_card_screen.dart**: Changed `polar_service.dart` import → `purchase_service.dart`

### Performance
- **WordRepository**: Added caching for `getWordsByLevel()`, `categories`, `buildRelatedIdsMap()` — previously recomputed on every call across 7,200 words.
- **LearnScreen**: Level word count display now O(1) via cached `getWordsByLevel()` (was 6 × O(n) per build).

### Architecture
- Extracted `userTopikLevelProvider` from `home_screen.dart` → `lib/core/providers/user_level_provider.dart`. Three feature files (dalli_chat, daily_session, sentence_card) now import directly from core, eliminating cross-feature dependencies.
- Added `AppConfig.daySeed` getter — replaced magic number `86400000` in 3 locations.

### CI/CD
- Added `.github/workflows/ci.yml` — analyze + test + Android AAB build on push to master.
- Tightened `analysis_options.yaml` — added `curly_braces_in_flow_control_structures` and `avoid_catches_without_on_clauses` lint rules.
- Added all project source files to git tracking with proper `.gitignore` (excludes `functions/node_modules/`, `functions/lib/`, build artifacts, keystore).

---

## [1.0.6+47] — 2026-04-11

### Fixed
- **premium_screen.dart**: Currency price overflow — wrapped price text with `FittedBox(fit: BoxFit.scaleDown)` to handle long currency strings (e.g., Korean Won, Japanese Yen).
- **home_screen.dart**: `NetworkImage` missing `onBackgroundImageError` handler causing unhandled exceptions on avatar load failure.
- **home_screen.dart**: `_SentenceSpotlight` was filtering 7,200 words on every widget rebuild — added `_cachedLevel` / `_cachedWords` to recompute only when level changes.
- **dalli_chat_screen.dart**: Missing `if (!mounted) return` guard before first `setState`; removed artificial 800ms delay in error path; improved SSE parse error logging.
- **fcm_service.dart**: `StreamSubscription` leak — added subscription list, idempotent guard, and `dispose()` method.
- **word_network_screen.dart**: Removed unused `_tick` field and all increment/reset calls.
- Multiple files: Replaced remaining `polar_service.dart` imports with `purchase_service.dart`.

### Analyze
- Reduced from 127 to 116 info-level issues (0 errors, 0 warnings).

---

## [1.0.6+46] — 2026-04-09

### Fixed (Critical)
- **pronunciation_service.dart**: Server URL was a placeholder — replaced with `AppConfig.backendUrl`.
- **pronunciation_screen.dart**: Demo mode was returning random scores instead of real server scores.
- **dalli_chat_screen.dart**: `http.Client()` instance leaked on every message send — added lifecycle management.
- **premium_screen.dart**: Subscription prices were hardcoded strings instead of fetched from RevenueCat.
- **main.dart**: Firebase initialization errors were silently caught with empty `catch(_){}`.

### Fixed (High)
- **dalli_chat_screen.dart**: Chat history was stored only in memory — added SharedPreferences persistence.
- **dalli_chat_screen.dart**: No SSE timeout + duplicate message submission possible — added 30s timeout and sending state guard.
- **auth_service.dart**: Hive migration type mismatch when upgrading guest → Google account.
- **daily_session_service.dart**: Filler words were always level 1 regardless of user's selected level.
- **home_screen.dart**: Notification bell button had empty `onPressed` callback.

### Removed
- `polar_service.dart` dead code (legacy Polar payment system shim).

---

## [1.0.6+45] — 2026-03-31

### Changed
- Migrated payment system from Polar → RevenueCat (purchases_flutter 9.x).
- Added 7-day free trial for annual subscription plan.
- Implemented `PaywallGate` widget for route-level premium protection.

---

## [1.0.6+44] — 2026-03-30

### Fixed
- Declared `AD_ID` permission for Android 13+ (required for Firebase Analytics).

---

## [1.0.6+43] — 2026-03-30

### Fixed
- AI chat `userLevel` was hardcoded — now reads from `userTopikLevelProvider`.
- Wired Dalli chat mode selection to backend API parameter.
