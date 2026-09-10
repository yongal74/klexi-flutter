# CLAUDE.md — Klexi 프로젝트 컨텍스트

> 이 파일은 Claude Code가 Klexi 프로젝트 작업 시 항상 참조하는 컨텍스트 문서입니다.

---

## 프로젝트 개요

**Klexi** — 문장 기반 한국어 학습 앱 (Flutter + Firebase)
- 타겟: 비한국어권 한국어 학습자 (TOPIK 1~6 대응)
- 플랫폼: Android (프로덕션), iOS (준비 중)
- 버전: **1.0.6+52 라이브**(2026-09-02 게시) / **1.0.6+53 개발 중**(미출시)
- 실제 경로: `C:\workspace\klexi\KlexiDev\`
- 소스 원본: `KlexiDev\klexi_src\` (GitHub `yongal74/klexi-flutter`, master)
- **모든 문서 원본은 저장소 안**이다(2026-09-10 편입, D-18). `KlexiDev\docs\` 와
  `KlexiDev\CLAUDE.md` 는 구경로이며 포인터만 남아 있다. 같은 문서를 두 곳에 두면
  드리프트가 생기므로 **저장소 쪽만 갱신한다.**

  | 문서 | 경로 |
  |---|---|
  | 이 지침 | `klexi_src\CLAUDE.md` |
  | 재개 지점 | `klexi_src\docs\HANDOFF_build53.md` ← **세션 시작 시 먼저 읽는다** |
  | 계획서·결정 대장(D-01~) | `klexi_src\docs\UPGRADE_PLAN_build53.md` |
  | 7축 리뷰 원문 | `klexi_src\docs\reviews\2026-09-10\` |
  | 변경 내역 | `klexi_src\docs\CHANGELOG.md` |
  | ADR | `klexi_src\docs\ADR\` |
  | 시계열 대장 | `KlexiDev\_history.md` (저장소 밖 — 버전·배포 이력만) |
- targetSdk: Flutter 3.41.4 기본값으로 compileSdk/targetSdk 36 (Android 16 유예 마감 11/1은 이미 충족)

## 봇 체제 (2026-09-10~)
- **PM 봇**(평가·우선순위·수용기준·검증·문서): 코드 수정 금지. 산출물 = `docs/UPGRADE_PLAN_build53.md`, 리뷰 보고, dev_log.
- **구현/개발 봇**: 코드 수정은 이 봇만. `docs/UPGRADE_PLAN_build53.md`의 WP 순서대로, WP마다 §7 템플릿으로 PM에 보고. 프로덕션 배포·릴리즈 빌드는 PM 승인 후.
- 금지: keystore/key.properties/google-services.json/firebase_options.dart/functions/.env 커밋·수정.

### 병렬 작업 시 파일 경계 (2026-09-10 확립, 병합 충돌 0건으로 검증됨)
| 트랙 | 담당 경로 |
|---|---|
| A (백엔드·정책·문서) | `functions/**`, `web/**`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/**`, `android/app/build.gradle.kts`, `android/app/proguard-rules.pro`, `docs/**`, `README.md` |
| B (앱 코어) | `lib/**`, `test/**`, `pubspec.yaml`, `.github/**` |
| 어느 쪽도 아님 | `firebase.json` — PM 이 그때그때 지정 |

- 경계 밖 파일이 필요하면 직접 고치지 말고 담당 트랙에 요청한다.
- 트랙 A 는 git worktree(`klexi_src_trackA`, 브랜치 `build53/track-a`)에서 작업하고
  WP 완료 시 master 로 `--no-ff` 병합한다. `.dart_tool` 락 충돌을 피하기 위해
  **`flutter analyze`·에뮬레이터·배포는 한 번에 하나만** 돌린다.
- ⚠️ **병렬은 시간을 줄이지 토큰을 줄이지 않는다** — 각 트랙이 따로 읽고 검증하므로
  총 사용량은 오히려 1.3~1.6배 늘어난다. 토큰 예산이 빠듯하면 단일 트랙이 낫다.

### dev_log 파일명 (2026-09-10 사고 후 규칙화)
한 프로젝트에 봇이 둘 이상이면 **`dev_log_klexi_<pm|dev>_YYYY-MM-DD.md`** 를 쓴다.
역할 접미사 없이 `dev_log_klexi_YYYY-MM-DD.md` 를 쓰면 다른 봇의 로그를 덮어쓴다
(실제로 발생했다). memory 폴더는 git 이 아니라 되돌릴 스냅샷이 없다.

---

## 기술 스택

| 레이어 | 기술 |
|---|---|
| 프레임워크 | Flutter 3.x / Dart 3.6 |
| 상태관리 | flutter_riverpod 2.x (StateNotifier + Provider) |
| 라우팅 | go_router 14.x (StatefulShellRoute) |
| 로컬 DB | Hive (학습 기록), SharedPreferences (설정) |
| 인증 | Firebase Auth + Google Sign-In |
| 결제 | RevenueCat (purchases_flutter 9.x) |
| 백엔드 | Firebase Cloud Functions (TypeScript/Express) |
| AI | OpenAI GPT-4o-mini (채팅), OpenAI TTS (음성) |
| 분석 | Firebase Analytics + Crashlytics |
| 알림 | FCM + flutter_local_notifications |

---

## 디렉토리 구조

```
C:/KlexiDev/
├── klexi_src/                  # Flutter 앱 소스
│   ├── .github/workflows/      # CI/CD (ci.yml) — build48에서 추가
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants/      # app_config.dart, app_colors.dart 등
│   │   │   ├── providers/      # user_level_provider.dart ← build48에서 분리
│   │   │   ├── router/         # app_router.dart (GoRouter)
│   │   │   ├── services/       # auth, purchase, analytics, fcm, notification 등
│   │   │   ├── theme/
│   │   │   ├── utils/          # srs_algorithm, tts_service
│   │   │   └── widgets/        # main_scaffold, paywall_gate
│   │   ├── data/
│   │   │   ├── content/        # 7200 단어 vocab 데이터, 문장, 문법
│   │   │   ├── models/         # Word, GrammarPattern
│   │   │   └── repositories/   # WordRepository (싱글톤 + 캐싱)
│   │   └── features/           # 각 화면별 feature 폴더
│   │       ├── auth/
│   │       ├── chat/           # Dalli AI 채팅
│   │       ├── grammar/
│   │       ├── hangeul/
│   │       ├── home/
│   │       ├── learn/          # 핵심: daily_session, quiz, review 등
│   │       ├── premium/        # RevenueCat 연동 결제 화면
│   │       ├── pronunciation/  # 발음 채점
│   │       ├── settings/
│   │       ├── themes/         # K-culture 테마 팩
│   │       └── word_network/
│   ├── functions/              # Firebase Cloud Functions
│   │   └── src/
│   │       ├── index.ts        # Express 앱 진입점
│   │       ├── ai-chat.ts      # GPT-4o-mini SSE 스트리밍
│   │       ├── ai-tts.ts       # OpenAI TTS
│   │       └── polar.ts        # (구 결제 시스템 잔재 — 미사용)
│   └── android/
│       └── keystore/           # 릴리즈 서명 키 (klexi-release.jks)
└── releases/                   # .aab 빌드 파일들
```

---

## 핵심 설정값

```dart
// lib/core/constants/app_config.dart
backendUrl = 'https://klexi-30ab5.web.app'   // Firebase Functions URL
revenueCatApiKey = 'goog_BGlWjxuopFQTSNIxAFkAIFrmZXO'  // Android 공개키
daySeed = DateTime.now().millisecondsSinceEpoch ~/ msPerDay  // 일별 시드
```

---

## 결제 시스템

- **RevenueCat** 사용 (purchases_flutter)
- Entitlement 이름: `'premium'`
- 플랜: monthly / annual (PackageType.monthly / PackageType.annual)
- 7일 무료 체험: annual 플랜에 적용
- `PremiumNotifier` (StateNotifier<bool>) → `premiumProvider`
- `isPremiumProvider` → 전체 앱에서 paywall 체크
- `PaywallGate` 위젯으로 premium 라우트 보호

**paywalled 기능:**
- Dalli AI Chat (`/dalli-chat`)
- Grammar Coach (`/grammar`, `/grammar/:id`)
- Theme Packs (`/themes`, `/themes/:id`)
- Pronunciation Coach (`/pronunciation`)
- TOPIK 레벨 2~6 단어

---

## 인증 흐름

1. 게스트 모드 → 로컬 Hive 저장 (`study_records_guest_xxx`)
2. Google Sign-In → Firebase Auth
3. 게스트→Google 업그레이드 시 Hive 데이터 마이그레이션
   - `_migrateHiveData(fromId, toId)` 호출

---

## 복습 스케줄러 (SM-2 아님)

- `DailySessionService` — 매일 20단어 세션
- **고정 간격 사다리** `[1, 3, 7, 14, 30, 60]`일. SM-2 가 아니다(ADR-004 정정).
  `srs_algorithm.dart` 에 SM-2 코드가 있지만 import 0건인 죽은 코드다(WP-12 삭제 대상).
- 우선순위: 복습 due → 신규 → filler. 최소 5개 신규 단어 보장
- Hive box: **`study_records_$uid`** (build53 부터 uid 별 분리. 이전에는 공용 박스
  `study_records` 하나라 같은 기기의 다른 사용자가 기록을 공유했다)
- 인증 상태가 바뀌면 `DailySessionService.init(uid)` 로 박스를 갈아끼운다.
  게스트 로그인 / 구글 로그인 / 게스트→구글 업그레이드 세 경로 모두에서 호출돼야
  첫 학습 진입 시 `StateError('not initialised')` 가 안 난다.
- `getTodaySession`/`getTodayWordIds` 의 `isPremium`·`userLevel` 은 **`required`** 다.
  선택 인자였을 때 4개 화면이 인자를 빠뜨려 유료 사용자가 레벨1 단어만 받았다.

---

## 백엔드 (Firebase Functions, `klexi-30ab5`)

베이스: `https://klexi-30ab5.web.app`. 라우트는 아래 4개뿐이다.

| 라우트 | 인증 | 입력 상한 |
|---|---|---|
| `GET /api/health` | 불필요 | — |
| `POST /api/ai-chat` | **필요** | `role` ∈ {user, assistant}, `content` 1~1,000자, `messages` 1~8개, `mode` 4종, 본문 16KB |
| `POST /api/ai-tts` | **필요** | `voice` 화이트리스트, `text` 500자 |
| `POST /api/pronunciation/score` | **필요** | 오디오 2MB, mimetype 화이트리스트, `text` 200자 |

- 클라이언트는 `lib/core/network/api_client.dart` 를 통해서만 호출한다.
  `AuthInterceptor` 가 `Authorization: Bearer <Firebase ID 토큰>` 을 붙인다.
- 🔴 **`AUTH_MODE` 는 현재 `soft`** — 토큰이 없으면 통과(경고 로그), 있는데 무효면 401.
  라이브 build52 가 토큰을 안 보내기 때문이다. build53 이 90% 보급되거나 출시 14일
  경과 시 **`hard` 로 재배포해야 한다.** 안 하면 비용 방어가 절반만 걸린 채 남는다.
- 🔴 `functions/lib/` 는 커밋 대상이 아니다. 배포 전 `npm run build` 가 반드시
  선행돼야 하며, `firebase.json` 의 `predeploy` 훅이 이를 자동 수행한다.
- 호스팅 루트(`web/`)는 정적 랜딩 페이지다. Flutter 웹은 `purchases_flutter` 미지원.

### AI 채팅 (Dalli)
- `/api/ai-chat` — GPT-4o-mini SSE 스트리밍
- 모드: freeChat / wordReview / rolePlay / grammarCoach (그 외는 400)
- 히스토리 최근 8개 메시지만 전송. **서버가 더 이상 잘라주지 않으므로 클라이언트가
  8개로 맞춰 보내야 한다**(9개 이상이면 400)
- 서버 측 캐싱: 동일 (mode, level, message) 1시간 캐시 (최대 200개)

---

## 아키텍처 규칙 (build48 기준)

### userTopikLevelProvider
- 위치: `lib/core/providers/user_level_provider.dart`
- **절대 home_screen.dart에서 임포트하지 말 것** (이미 분리됨)
- `UserLevelNotifier` (public class)

### WordRepository 캐싱
- `getWordsByLevel()`, `categories`, `buildRelatedIdsMap()` 모두 캐시됨
- 싱글톤이므로 앱 생명주기 동안 1회만 계산

### daySeed
- `AppConfig.daySeed` 사용 — `86400000` 매직넘버 직접 쓰지 말 것

---

## 알려진 이슈 및 수정 이력

### ✅ build46 수정 완료

| # | 파일 | 이슈 |
|---|---|---|
| 1 | `pronunciation_service.dart` | 발음 서버 URL 플레이스홀더 |
| 2 | `pronunciation_screen.dart` | Demo 모드 랜덤 점수 코드 |
| 3 | `dalli_chat_screen.dart` | http.Client() 누수 |
| 4 | `premium_screen.dart` | 가격 하드코딩 |
| 5 | `main.dart` | Firebase catch(_){} 묵살 |
| 6 | `dalli_chat_screen.dart` | 채팅 히스토리 메모리만 저장 |
| 7 | `dalli_chat_screen.dart` | SSE 타임아웃 없음 + 중복 전송 |
| 8 | `auth_service.dart` | Hive 마이그레이션 타입 불일치 |
| 9 | `daily_session_service.dart` | filler 단어 level 1 고정 |
| 10 | `home_screen.dart` | 알림 버튼 빈 콜백 |

### ✅ build47 수정 완료

| # | 파일 | 이슈 |
|---|---|---|
| 11 | `premium_screen.dart` | 구독료 화폐 단위 오버플로우 (FittedBox 적용) |
| 12 | `home_screen.dart` | NetworkImage 에러 핸들러 누락 |
| 13 | `home_screen.dart` | _SentenceSpotlight 매 빌드 7200단어 필터 |
| 14 | `dalli_chat_screen.dart` | mounted 체크 누락, 에러 swallow |
| 15 | `fcm_service.dart` | StreamSubscription 누수 |
| 16 | `word_network_screen.dart` | _tick 미사용 필드 |
| 17 | 여러 파일 | polar_service 임포트 → purchase_service |

### ✅ build48 수정 완료

| # | 파일 | 이슈 |
|---|---|---|
| 18 | `tts_service.dart` | 프리미엄 TTS URL 플레이스홀더 (완전 고장) |
| 19 | `sentence_card_screen.dart` | getTodayWordIds 파라미터 누락 |
| 20 | `word_repository.dart` | 관계어 맵 중복 데이터 버그 |
| 21 | `word_repository.dart` | getWordsByLevel/categories/relatedIds 캐싱 부재 |
| 22 | 아키텍처 | userTopikLevelProvider cross-feature 의존성 |
| 23 | 여러 파일 | 86400000 매직넘버 중복 |

### ✅ build53 수정 완료 (2026-09-10, 미출시)

| # | 파일 | 이슈 |
|---|---|---|
| 24 | `functions/**` | 백엔드 완전 무인증 — 누구나 OpenAI 비용 유발 가능, 프롬프트 주입·캐시 오염 |
| 25 | `tts_service.dart` | 프리미엄 TTS 가 없는 라우트를 호출해 항상 404 — 유료 음성이 한 번도 안 나옴 |
| 26 | `main.dart`/`auth_service.dart` | `restoreSession()` 호출처 0건 — 실행할 때마다 로그인 화면 |
| 27 | `daily_session_service.dart` | 학습기록이 기기 공용 박스 1개 — 사용자 간 공유, 계정삭제가 못 지움 |
| 28 | `notification_service.dart` | Android 12+ 에서 리마인더 예약 자체가 실패(정확알람 권한), 실패를 삼킴 |
| 29 | `notification_service.dart` | `tz.setLocalLocation` 미호출 — 예약 시각이 UTC 기준으로 어긋남 |
| 30 | 4개 학습 화면 | `getTodayWordIds` 인자 누락 → 유료 사용자가 레벨1 단어만 받음(#19 회귀) |
| 31 | `grammar_data.dart` | 유료 Grammar Coach 예문 74/324건(23%)에 영어 번역 없음 |
| 32 | `.github/workflows/ci.yml` | CI 가 구조적으로 통과 불가능한 상태 → **최초 초록** |
| 33 | `firebase.json` | predeploy 훅 부재(옛 빌드 배포 위험), `hosting.public` 이 빈 디렉토리 |
| 34 | `fcm_service.dart` | FCM 토큰 prefs 저장 — 백업 복원 시 옛 토큰이 살아나 푸시가 죽음 |

### 🟡 향후 개선 필요

| # | 이슈 | 우선순위 |
|---|---|---|
| A | `withOpacity` → `.withValues()` 마이그레이션 (analyze info 128건의 대부분) | Low (WP-13) |
| B | GitHub Actions secrets (KEYSTORE_BASE64, KEY_PROPERTIES) | Low — 없으면 CI 가 자동 skip, 릴리즈는 로컬 빌드 |
| C | ~~Windows 테스트 GPU isolate~~ → **CI(ubuntu)에서는 92건 정상 통과.** 로컬만 멈추므로 테스트는 CI 에서만 돌린다 | 해결 불필요 |
| D | TopikBadge 공통 위젯 추출 (12개 파일 중복) | Low (WP-13) |
| E | npm moderate 취약점 9건 — firebase-admin 메이저 업 필요 | build54 이월 |
| F | `google_sign_in` 7.x(Credential Manager) 마이그레이션 | build54 이월 |
| G | RevenueCat 서버측 entitlement 검증(REST) | build54 이월 |

---

## CI/CD

```yaml
# .github/workflows/ci.yml
# push to master/main/develop 또는 PR 시 자동 실행
# jobs: analyze-and-test → build-android (master only)
```

**GitHub Actions secrets 필요:**
- `KEYSTORE_BASE64`: base64 인코딩된 키스토어 파일
- `KEY_PROPERTIES`: android/key.properties 내용

---

## 빌드 & 배포

```powershell
# 릴리즈 AAB
cd C:\workspace\klexi\KlexiDev\klexi_src
flutter build appbundle --release
& "C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe" -verify -verbose:summary -certs build\app\outputs\bundle\release\app-release.aab
# 서명 확인 문자열: 7EDE361C (build51/52 와 동일해야 한다)

# Firebase 배포 (predeploy 훅이 npm ci + build 를 자동 수행)
firebase deploy --only functions,hosting --project klexi-30ab5

# 에뮬레이터 / 실기기
& "C:\androidsdk\platform-tools\adb.exe" devices
flutter run -d <device>
& "C:\androidsdk\platform-tools\adb.exe" shell dumpsys alarm | Select-String twentykorean

# 릴리즈 파일 위치
C:\workspace\klexi\KlexiDev\releases\
```

⚠️ 프로덕션 배포·릴리즈 빌드는 **PM 승인 + 형님 승인** 후에만 실행한다.

---

## 작업 시 주의사항

- `.pen` 파일은 Pencil MCP 도구로만 읽기/쓰기
- 키스토어 위치 (헷갈리기 쉬우니 정확히):
  - **빌드가 실제로 쓰는 것**: `klexi_src/android/klexi-release.jks`
    (`android/key.properties` 의 `storeFile=../klexi-release.jks` 기준). gitignore 대상.
  - **원본 보관소**: `KlexiDev/keystore/` (`release.jks`, `key.properties` 등)
  - `android/keystore/` 는 **존재하지 않는 디렉토리**다 — CI 가 그 경로로 복원하려다
    계속 실패했다(build53 WP-00 에서 정정).
  - 전부 절대 수정/삭제 금지
- `firebase_options.dart` — git에 커밋 주의 (API 키 포함)
- RevenueCat entitlement 이름은 반드시 `'premium'` (대소문자 구분)
- Hive box 이름 변경 시 기존 유저 데이터 마이그레이션 필수
- 프로덕션 배포 전 반드시 사용자에게 보고 후 커밋/푸시
- `getTodayWordIds()`/`getTodaySession()` 의 두 파라미터는 `required` 다 — 기본값을
  다시 넣지 말 것. 선택 인자였던 것이 #19/#30 회귀의 원인이었다
- 포맷·린트 검증은 **실제 패키지 컨텍스트에서** 돌린다. 격리 디렉토리(`.dart_tool` 없음)는
  언어 버전을 못 읽어 `dart format` 결과가 뒤집힌다
- `x ?? ref.read(provider)` 는 좌변이 nullable 이면 `read<T>` 의 T 까지 nullable 로
  하향 추론된다 — 좌변에 명시적 타입을 붙일 것
- provider 파일이 서비스 파일을 import 하면 순환으로 타입 추론이 깨진다
- `userTopikLevelProvider`는 `core/providers/user_level_provider.dart`에서 임포트
