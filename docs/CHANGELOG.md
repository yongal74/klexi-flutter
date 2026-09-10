# Changelog — Klexi

All notable changes to Klexi are documented here.

---

## [1.0.6+53] — 2026-09-10 (개발 중)

> build53 은 2트랙 병렬 작업이다. 아래는 **트랙 A(백엔드·정책·문서)** 항목이며,
> 트랙 B(앱 코어: 세션 복원, 계정·데이터 모델, 리마인더, 프리미엄 TTS, 학습 정합성)는
> 병합 시 이 절에 합쳐진다.

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
  키스토어 복원 경로 정정, 존재하지 않는 asset 디렉토리 항목 제거, `dart format lib/ test/` 적용.

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
