# Klexi build53 전체 업그레이드 계획 v1 — PM 봇 작성 (2026-09-10)

> 작성: Klexi PM 봇(claude-ad). 대상: Klexi 구현/개발 봇.
> 원칙: **PM 봇은 코드를 수정하지 않는다. 코드는 구현 봇만 수정한다.** PM은 평가·우선순위·수용기준·검증을 맡는다.
> 소스: `C:\workspace\klexi\KlexiDev\klexi_src\` (git master `38cdcf2`, GitHub `yongal74/klexi-flutter`). 이 문서의 file:line은 그 커밋 기준.

---

## 0. 현황 요약

| 항목 | 상태 |
|---|---|
| 라이브 버전 | build52 (1.0.6+52), 2026-09-02 Play 게시됨 |
| targetSdk | Flutter 3.41.4 기본값으로 **이미 compileSdk 36 / targetSdk 36 / minSdk 24** (`android/app/build.gradle.kts:23,38-39`). API 36 마이그레이션은 "값 변경"이 아니라 **Android 16 동작 변경 대응** 작업 |
| 백엔드 | `https://klexi-30ab5.web.app/api/**` — 라우트는 `/api/health`, `/api/ai-chat`, `/api/ai-tts`, `/api/pronunciation/score` 4개뿐 (`functions/src/index.ts:28-34`) |
| 서명 | 릴리즈 키 = `android/klexi-release.jks` (gitignore), 서명파일명 `META-INF/7EDE361C.SF`로 build51/52와 동일 확인됨 |
| 리뷰 | 7개 축(보안·안정성·성능·UX·기능완결성·Android16/정책·유지보수성) 병렬 리뷰 → PM이 핵심 발견을 코드로 재검증함 |

### 리뷰가 드러낸 가장 큰 사실 — "한 번도 작동한 적이 없는 기능"이 여럿이다
1. **프리미엄 TTS(CLOVA/Google)는 라우트가 서버에 없어** 항상 404 → 기기 TTS로 폴백. 유료 기능 문구가 허위 상태.
2. **데일리 리마인더는 Android 12+에서 예약 자체가 예외로 실패**(정확알람 권한 미선언), 재부팅 시 소멸.
3. **앱을 다시 켤 때마다 로그인 화면**(세션 복원 함수가 호출된 적 없음).
4. **계정삭제가 학습기록을 지우지 않음**(삭제 대상 Hive 박스명이 실제 박스명과 다름). 학습기록은 uid 없이 단일 박스라 기기 내 사용자 간 공유됨.
5. **테마 팩 단어 카드가 항상 엉뚱한 단어**(레벨1 첫 단어)를 연다.
6. **백엔드가 완전 무인증**이라 누구나 OpenAI 비용을 태울 수 있고, 프롬프트 주입/캐시 오염이 가능.

---

## 1. 운영 규칙 (구현 봇 필독)

- 작업 단위 = 아래 **WP(Work Package)**. WP 하나 = 커밋 1~3개. 커밋 메시지 접두어 `build53/WP-XX:`.
- 각 WP 완료 시 PM에게 보고: 변경 파일, `flutter analyze` 에러 0 캡처, 검증 방법·결과(에뮬레이터 API 36.1 = `emulator-5554` 사용 가능), 남은 리스크.
- 절대 금지: `android/klexi-release.jks`·`key.properties`·`google-services.json`·`firebase_options.dart`·`functions/.env` 커밋, keystore 수정, 프로덕션 Firebase 배포(배포는 PM 승인 후 지정된 WP에서만).
- 수정 전 라우터(`lib/core/router/app_router.dart`) 먼저 읽는다(전역 규칙 3).
- 애매하면 SendMessage로 PM(`claude-ad`)에게 묻는다. 추측으로 범위를 넓히지 않는다.
- 메모리 dev_log 파일명은 역할 접미사 필수: `dev_log_klexi_pm_YYYY-MM-DD.md` / `dev_log_klexi_dev_YYYY-MM-DD.md` (09-10에 PM 로그가 덮어써진 사고 재발 방지).
- 버전: `pubspec.yaml` `1.0.6+53`(build52가 라이브이므로 versionCode 53 필수). 릴리즈 빌드는 PM이 최종 게이트 통과 후 지시.

---

## 2. 작업 패키지 — 우선순위 순

### P0 — 정책·수익·핵심기능 (Sprint 1, 이것 없이는 build53 출시 불가)

#### WP-01 백엔드 인증 + 입력검증 + 비용 방어 (functions/)
근거: `functions/src/index.ts:36` `invoker: "public"`, 어떤 라우트도 토큰 검사 없음. `ai-chat.ts:71-77` role/content 무검증, `:136` `messages.slice(-8)`에 공격자 `role:"system"` 포함 가능, `:95-107,150-153` 캐시키가 `level:message`뿐이라 **크로스 유저 캐시 오염** 가능. `pronunciation.ts:13` 10MB, `:24-50` `text` 길이 무제한 → O(m·n) Levenshtein DoS. `ai-tts.ts:12` `/api/ai-tts`는 클라이언트가 호출하지 않는 공개 비용 엔드포인트.
조치:
1. Express 미들웨어로 **Firebase ID 토큰 검증**(`admin.auth().verifyIdToken`) — `/api/health` 제외 전 라우트. 클라이언트는 `FirebaseAuth.instance.currentUser?.getIdToken()`을 `Authorization: Bearer`로 전송(dio 인터셉터 1곳: `lib/core/utils/tts_service.dart:145` dioProvider, `pronunciation_service.dart:108` _dioProvider, `dalli_chat_screen.dart` http 호출부). 게스트는 401 → 클라이언트에서 "Sign in to use AI features" 안내.
2. `ai-chat`: `role ∈ {user, assistant}`만 허용, `content`는 string, 각 ≤1,000자, `messages.length ≤ 8`, `express.json({limit:'16kb'})`; 캐시키에 `mode` 포함; `req.on('close', () => stream.controller.abort())`.
3. `pronunciation`: `text.length ≤ 200`, `fileSize ≤ 2MB`, mimetype 검사.
4. `onRequest` 옵션에 `maxInstances: 5`, `concurrency` 기본 유지. (OpenAI 대시보드 월 하드캡 설정은 **사용자 몫**.)
5. `/api/ai-tts`는 WP-02에서 실제 사용하게 되므로 유지하되 `voice` 화이트리스트 검증.
6. `functions/src/polar.ts` 삭제, `@polar-sh/sdk`·`POLAR_*` 제거.
완료 기준: 토큰 없이 `curl` → 401; 유효 토큰 → 200; `role:"system"` 주입 → 400; 1MB text → 400. `npm run build` 성공. 배포는 PM 승인 후.

#### WP-02 프리미엄 TTS를 실제로 작동시키기
근거: `lib/core/utils/tts_service.dart:81` `/api/tts/clova`, `:113` `/api/tts/google` — 서버에 없음. `word_card_screen.dart:46`, `sentence_practice_screen.dart:118` `isPremium: true` 하드코딩; `sentence_card_screen.dart:270,302`, `level_words_screen.dart:310`, `pronunciation_screen.dart:150`은 `isPremium` 미전달. `app_strings.dart:127-128` "Naver CLOVA / Google Neural2" 문구는 허구.
조치:
1. 클라이언트를 **`/api/ai-tts`**(OpenAI TTS, `{text, voice:'nova'}`) 1개 경로로 통일. `_speakWithClova/_speakWithGoogle` 삭제 → `_speakWithServer`.
2. `isPremium`은 항상 `ref.read(isPremiumProvider)`에서. 404/네트워크 실패는 Crashlytics 비치명 1회만(연속 실패 억제) 기록 후 기기 TTS 폴백 + 짧은 스낵바 "Using device voice".
3. 서버는 WP-01 토큰 필수. (2단계: RevenueCat REST로 entitlement 서버 검증 — `Purchases.logIn(uid)` 도입(WP-03) 후 `app_user_id=uid`로 조회. RC 시크릿키는 Functions secret. 사용자에게 키 요청 필요 → 2단계는 build54로 이월 가능, PM 판단.)
4. 문구를 "AI voice (premium)"로 정정.
5. TTS 캐시: 키를 SHA-1(text+voice+speed)로, 시작 시 mtime 기준 50MB LRU 정리, `getTemporaryDirectory()` 1회 캐시 (`tts_service_mobile.dart:9-34`).
완료 기준: 에뮬레이터에서 로그인 유저가 스피커 탭 → `/api/ai-tts` 200 + MP3 재생 확인(로그), 비로그인/오프라인 → 기기 TTS + 안내.

#### WP-03 계정·세션·데이터 모델 정리
근거: `auth_service.dart:28` `restoreSession()` 호출 0건, `app_router.dart:61-65` 초기 `/auth` 리다이렉트 → 매 실행 로그인 화면. `daily_session_service.dart:88` 박스명 `study_records`(공유) vs `auth_service.dart:138` 삭제 대상 `study_records_$uid`, `:170` 마이그레이션 대상 `study_records_<guest>` → 둘 다 존재하지 않는 박스. `upgradeGuestWithGoogle()`(`:152`) 호출 0건. `Purchases.logIn/logOut` 0건 → 로그아웃/삭제 후에도 premium 유지. 삭제 시 `dalli_chat_history`·녹음파일·TTS 캐시·FCM 토큰 등 잔존.
조치:
1. `main.dart`: Firebase init 후 `restoreSession()` → `currentUserProvider` 시드 → 그 다음 `runApp`. (게스트도 prefs `klexi_user_id`가 `guest_`면 복원.)
2. `DailySessionService.init(uid)`로 **박스명 `study_records_$uid`**. 기존 공유 박스 `study_records`는 첫 로그인 사용자에게 1회 마이그레이션(데이터 손실 방지) 후 삭제. 인증 변경 시 박스 재오픈.
3. `deleteAccount()`: 재인증 로직 유지 + 실제 박스 삭제 + `prefs.clear()` + temp 파일(`klexi_pronunciation.m4a`, `tts_cache/`) 삭제 + `FirebaseMessaging.instance.deleteToken()` + `Purchases.logOut()` + `premiumProvider=false`.
4. `signOut()`: `Purchases.logOut()`, premium false, 채팅 히스토리 초기화.
5. 로그인 성공 시 `Purchases.logIn(uid)`; 앱 시작 복원 시에도.
6. 프로필 카드(게스트일 때) "Sign in with Google to back up progress" → `upgradeGuestWithGoogle()` 연결(마이그레이션이 이제 실제 박스명으로 동작).
7. `PurchaseService.initialize()`·`FcmService().initialize()`는 `runApp` **이후** 비동기, 각각 try/catch(`main.dart:43`, `:27`; FCM 오류는 `fatal:false`로만).
완료 기준: 에뮬레이터에서 (a) 로그인 후 앱 종료→재실행 시 홈으로 직행, (b) 계정삭제 후 Hive/prefs 비어있음 확인(adb shell run-as 또는 로그), (c) 게스트→구글 업그레이드 시 학습기록 유지.

#### WP-04 데일리 리마인더를 실제로 작동시키기
근거: `notification_service.dart:81` `exactAllowWhileIdle` + 매니페스트에 `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` 없음(플러그인 18.0.1도 미선언) → Android 12+에서 `exact_alarms_not_permitted` 예외, `notification_settings_screen.dart:54-56`이 삼킴. `RECEIVE_BOOT_COMPLETED`·부트 리시버 없음 → 재부팅 후 소멸. `tz.setLocalLocation` 미호출 → DST 후 1시간 어긋남. `settings_screen.dart:57-75` 두 스위치는 로컬 state만.
조치:
1. `AndroidScheduleMode.inexactAllowWhileIdle`로 변경(언어학습 리마인더는 정확알람 자격 없음).
2. 매니페스트: `RECEIVE_BOOT_COMPLETED` + `ScheduledNotificationReceiver`/`ScheduledNotificationBootReceiver`(BOOT_COMPLETED, MY_PACKAGE_REPLACED, QUICKBOOT_POWERON) 선언.
3. `flutter_timezone` 추가 → `tz.setLocalLocation`.
4. 예약 실패를 사용자에게 표시(스낵바) + Crashlytics 비치명.
5. Settings 메인의 가짜 "Daily Reminders" 스위치 제거(Notification Settings 링크만 유지). "Slow TTS Speed"는 Riverpod provider + prefs로 실제 연결(`TtsService.speak`가 읽음) 또는 제거 — **PM 결정: 실제 연결**.
6. 온보딩(WP-09) 마지막 페이지에서 리마인더 켜기 제안(권한 요청은 그 시점).
완료 기준: 에뮬레이터 API 36.1에서 시간 설정→저장→`adb shell dumpsys alarm | grep twentykorean`에 예약 존재, 재부팅(`adb reboot`) 후에도 존재.

#### WP-05 Play 정책·매니페스트·개인정보 문서
근거: `AndroidManifest.xml:9` `AD_ID` 선언됐으나 `web/privacy.html`에 광고ID 미고지; `pronunciation.ts:85` 음성이 OpenAI로 가지만 privacy.html은 "최근 8개 채팅"만 고지. 백업 규칙 없음(`allowBackup` 기본 true, `fcm_token` 등 기기별 값이 새 기기로 복원). `enableOnBackInvokedCallback` 미설정. `build.gradle.kts:65-69` `useLegacyPackaging = true`.
조치:
1. `web/privacy.html`: "Advertising ID (Firebase Analytics)" 행, "Voice recordings → OpenAI Whisper, 채점 후 미보관" 행 추가. `web/delete-account.html` 삭제 항목을 WP-03 실제 동작과 일치시킴.
2. `res/xml/data_extraction_rules.xml` + `backup_rules.xml`: Hive·prefs 포함하되 `FlutterSharedPreferences.xml`의 `fcm_token`은 제외(→ 토큰을 별도 비백업 저장소로 옮기는 편이 간단: `flutter_secure_storage` 대신 그냥 매 실행 `getToken()` 재조회로 대체하고 prefs 저장 제거).
3. `<application android:enableOnBackInvokedCallback="true">`; `notification_settings_screen.dart` PopScope 저장 동작을 제스처 백으로 검증.
4. `useLegacyPackaging` 블록 제거(16KB·설치크기).
5. `main.dart`에서 `SystemChrome.setSystemUIOverlayStyle` 전역 설정; 다크 배경 화면(`dalli_chat_screen`, `word_network_screen`)은 `AnnotatedRegion(SystemUiOverlayStyle.light)`.
6. RECORD_AUDIO 최초 요청 전 1줄 rationale 다이얼로그, 거부 시 "Enable microphone in Settings".
7. `proguard-rules.pro`에 `-keep class com.revenuecat.purchases.** { *; }` 추가.
사용자 몫(PM이 안내): Play Console 데이터 보안 양식에 광고ID·음성녹음 반영, 계정삭제 URL 확인.
완료 기준: 매니페스트 diff 리뷰, 빌드 성공, 에뮬레이터에서 제스처 백 + 상태바 아이콘 색 확인.

### P1 — 사용자 가시 버그·전환율 (Sprint 2)

#### WP-06 결제 UX
근거: `settings_screen.dart:480` `_PremiumSheet` "Start Free Trial" = `Navigator.pop`(구매 없음), 프리미엄 유저에게도 카드 노출. `premium_screen.dart:91-99` offerings 실패 시 가격 null → 스피너 무한. `:221,247` 트라이얼/할인 문구 하드코딩(실제 상품과 불일치 시 허위표시). 페이월 진입점 4종 상이.
조치: `_PremiumSheet` 삭제 → `context.push(AppRoutes.premium)`; `isPremiumProvider` true면 카드 숨김; 오류 상태 "Couldn't load prices · Retry" + 구독 버튼 비활성; 트라이얼/절약률을 `storeProduct.introductoryPrice`·월×12 대비로 계산; 페이월에 Terms/Privacy 링크; `showPaywall(context, feature)` 헬퍼로 진입 통일(`home_screen.dart:258`, `learn_screen.dart:204,282`, `paywall_gate.dart`, `word_network_screen.dart:345-379`).
완료 기준: 에뮬레이터(오프라인 모드 포함)에서 4 진입점 모두 동일 페이월, 오류 상태 표시.

#### WP-07 학습 기능 정합성
근거: `theme_detail_screen.dart:79` → `word_card_screen.dart:27-29` `getAllWords().firstWhere(orElse: words.first)` (테마 id는 vocab에 없음). `cloze_quiz_screen.dart:31-36` 7,200 전체에서 무작위·게이트 없음·기록 없음. `quiz_screen.dart:84-98` 오답이 세션 단어에서만 → 옵션 2~3개/중복 영어 뜻. `getTodayWordIds()` 인자 누락 3곳(`quiz_screen.dart:69`, `pronunciation_screen.dart:60`, `sentence_practice_screen.dart:57`). 세션 완료 화면 불일치(`daily_session_screen.dart:66-81` CTA 없음 vs `sentence_card_screen.dart:152-159` "Next 20" 재푸시).
추가 근거(유지보수성 리뷰): `daily_session_service.dart:107,217`의 `isPremium`/`userLevel`이 **선택 인자**라 `quiz_screen.dart:69`, `review_screen.dart:62`, `sentence_practice_screen.dart:57`, `pronunciation_screen.dart:60`에서 누락 → **유료 사용자가 이 4개 화면에서 레벨1 필러 단어만 받음**(build48에서 고쳤다는 #19 버그의 회귀). 수익 직결.
조치: **`getTodaySession`/`getTodayWordIds`의 두 인자를 `required`로** 바꿔 컴파일러가 모든 호출처를 잡게 함; word_card는 테마 단어 우선 조회; cloze는 `isPremium ? userLevel : 1` 필터 + `recordStudy`; 퀴즈 오답은 같은 레벨 풀에서 영어 뜻 중복 제거하며 4개 보장; 4개 화면에 반복된 `(isPremium || w.level == 1)` 필터를 `core/`의 `SessionSelector`로 추출(테스트 가능); 완료 컴포넌트 1개(Quiz / Practice / Review CTA)로 통일; `DateTime` 주간계산은 날짜 생성자 사용(`daily_session_service.dart:250`).
완료 기준: 에뮬레이터에서 테마→카드 일치, 무료 유저 cloze에 L2+ 단어 0개, 퀴즈 항상 4옵션, 프리미엄 상태(테스트용 provider 오버라이드)로 4개 화면에서 선택 레벨 단어 노출.

#### WP-08 발음 코치
근거: `pronunciation_service.dart:82` `recording.webm`로 업로드(실제 aacLc `.m4a`, `pronunciation_screen.dart:135-137`) → Whisper 포맷 오인 가능; `:39-45` 오프라인 결과 score 0 → 실패로 표시; `pronunciation_screen.dart:68-73` 세션 비면 로딩 무한; `:116` 한국어 스낵바; 서버 `buildFeedback` 한국어(`pronunciation.ts:53-59`).
조치: filename `recording.m4a` + `contentType audio/mp4`; 오류는 `PronunciationResult`에 `isError` 추가해 배너로; 빈 세션 empty state; 문구 영어(AppStrings); 서버 피드백 영어(한국어 병기 가능).
완료 기준: 에뮬레이터 마이크 없이 오류 배너 확인, 서버 통합은 사용자 실기기.

#### WP-09 온보딩 + 설정/버전/문자열
근거: `app_strings.dart:14-23` 온보딩 문구 존재하나 화면 없음; `settings_screen.dart:99` 버전 '1.0.0'; 한국어 UI 문자열 `word_network_screen.dart:503`, `dalli_chat_screen.dart:240`; `auth_screen.dart:100,105` 저대비.
조치: 3페이지 온보딩(1회, prefs 플래그) + 마지막에 레벨 선택·리마인더 제안; `package_info_plus`로 버전; 한국어 UI 문자열 전수 영어화(`grep -P '[가-힣]'` lib/features, 콘텐츠 데이터 제외); 대비 토큰(muted `#6B7280`, 버튼 primary 어둡게); 터치타깃 ≥44dp; `word_card_screen.dart:90-98` 등 오버플로 `Wrap`; 아이콘 버튼 tooltip/Semantics.
완료 기준: 첫 실행 온보딩 1회만, 버전 표시 1.0.6 (53), 한국어 UI 문자열 0건.

#### WP-10 채팅·알림 딥링크·오류 표시
근거: `dalli_chat_screen.dart:212-215` 서버 `{error}` 무시, `:239-254` 오류 메시지가 히스토리에 영구 저장, `:431-442` 온라인 점 항상 초록, `_history` 재시작 후 컨텍스트 소실; `fcm_service.dart:86-95` `consumePendingRoute` 호출 0건; `main.dart:27` FCM 예외가 fatal로 기록.
조치: error 이벤트 → 오류 버블(비저장); 저장된 히스토리 마지막 8개를 `_history`에 복원; 온라인 점은 마지막 응답 성공 여부; `appRouterProvider.redirect`에서 `consumePendingRoute()` 소비 + `screen` 허용목록; FCM init `catchError → recordError(fatal:false)`.

#### WP-11 성능
근거: `main.dart:43` 콜드스타트가 RevenueCat 네트워크 대기; `word_network_screen.dart:98,193` 틱마다 `setState` 전체 재빌드, `:793-816` 노드마다 TextPainter 생성·layout, `:675-695` 프레임당 수천 `drawLine`, `shouldRepaint=>true`; `daily_session_service.dart:107-181` 화면 열 때마다 7,200 스캔, 홈 `_load` 3회 풀스캔; `word.dart:6` `HiveObject` 상속으로 7,200 인스턴스 런타임 할당; `app_theme.dart:132` 폰트 런타임 다운로드, `NotoSansKR`·Pretendard 미선언; `home_screen.dart:92` 아바타 캐시 없음.
조치: (WP-03에서 startup 비동기화 완료) 워드네트워크는 위치를 `ChangeNotifier`로 `CustomPainter(repaint:)`, TextPainter 캐시(word.id×fontSize), Paint 필드화, 엣지 목록 노드셋당 1회 계산 + `drawPoints(lines)`; 세션 결과 `daySeed` 기준 메모이즈, 통계 1패스; `Word` const 생성자·HiveObject 제거·`WordAdapter` 삭제(박스는 `Box<Map>`만 사용); 폰트 번들(`fonts:` 선언, `allowRuntimeFetching=false`); `CachedNetworkImageProvider`.
완료 기준: 에뮬레이터 `flutter run --profile`로 워드네트워크 300노드 평균 프레임 <16ms(DevTools 캡처 또는 `--trace-skia` 로그), 콜드스타트 홈 표시 <2s(오프라인 포함).

### P2 — 유지보수·기술부채 (Sprint 3, 출시 전 가능한 만큼)
- WP-12 죽은 코드: `polar_service.dart`, `srs_algorithm.dart`(미사용 확인 후), `WordRepository.getDailyWords`, `flutter_animate`, `cached_network_image`(WP-11에서 사용하면 유지), `theme_sentences.dart` 소비 화면 없음(사용하거나 삭제), `relatedIds` 미채움.
- WP-13 `withOpacity`→`withValues` 134건, `assets/images`·`assets/icons` 선언 정리, `analysis_options` 위반 정리.
- WP-14 테스트: `flutter test`가 Windows에서 멈추는 원인 확인(위젯 테스트 격리, `--platform`/`dart test`로 순수 로직 분리), `deleteAccount`·세션 선택·게이팅·퀴즈 생성 유닛테스트 추가, CI(`.github/workflows/ci.yml`) 현행화.
- WP-15 문서: `README.md`(템플릿 상태), `KlexiDev/CLAUDE.md`(경로·상태·이슈표 현행화), `docs/CHANGELOG.md`(build49~53), ADR 추가(백엔드 인증, 데이터 모델 uid 분리).
- WP-16 호스팅 루트: `flutter build web`은 `purchases_flutter` 미지원으로 빈 화면(`main.dart:43`) → 루트를 **간단한 랜딩 페이지**(스토어 링크·기능·개인정보/약관 링크)로 교체. klexi.app 도메인이 죽어있으므로 이 페이지가 당분간 공식 랜딩.
- 이월(build54): `google_sign_in` 7.x(Credential Manager) 마이그레이션, npm moderate 9건(firebase-admin 메이저 업), RevenueCat 서버측 entitlement 검증.

---

## 3. 순서·마일스톤

| 단계 | 내용 | 게이트 |
|---|---|---|
| S1 | **WP-00(CI)**→01→02→03→04→05 (P0) | CI 초록, analyze 0에러, 에뮬레이터 스모크(로그인복원·삭제·리마인더·TTS), PM 검토 → **백엔드 배포 승인** |
| S2 | WP-06→07→08→09→10→11 | 에뮬레이터 UX 워크스루 캡처(스크린샷 5장 이상), 성능 수치 |
| S3 | WP-12~16 가능한 만큼 | 회귀 없음 |
| RC | `pubspec 1.0.6+53`, `flutter build appbundle --release`, `jarsigner -verify`로 `7EDE361C.SF` 확인, `releases/klexi-v1.0.6-build53.aab` | PM 최종 점검 → 사용자 실기기 체크리스트 → Play 업로드(사용자) |

에뮬레이터: `C:\androidsdk\platform-tools\adb.exe`, 기기 `emulator-5554`(Medium Phone API 36.1, 부팅 완료). `flutter run -d emulator-5554`.

## 4. 사용자(형님) 몫 — PM이 시점에 맞춰 요청
1. OpenAI 대시보드 월 사용 하드캡 설정(WP-01 배포 전).
2. Play Console 데이터 보안 양식: 광고ID·음성녹음(제3자 OpenAI) 반영(WP-05 후).
3. (선택, build54) RevenueCat 시크릿 키 → Functions secret.
4. RC 빌드 실기기 테스트: Google 로그인·복원, 구독(라이선스 테스터), 푸시 수신, 마이크 채점.
5. build53 Play 업로드·단계적 출시.

## 5. 유지보수성 리뷰 반영 — WP-12~15 상세 (P2지만 순서상 앞당길 것 있음)

**⚠️ CI가 절대 통과할 수 없는 상태**(`.github/workflows/ci.yml:20,61` Flutter 3.29.0 핀 vs `pubspec.lock`은 Flutter ≥3.38.4 요구 / `dart format --set-exit-if-changed`가 84개 파일에서 실패 / analyze 경고 2건(`pubspec.yaml:86-87` 없는 asset 디렉토리) / `ci.yml:73`이 존재하지 않는 `android/keystore/`에 키 복원). **PM 결정: CI 복구를 Sprint 1 첫 작업(WP-00)으로 앞당긴다** — 이후 모든 WP의 회귀를 잡는 안전망이기 때문.

#### WP-00 CI 복구 (Sprint 1 최우선)
1. `ci.yml` Flutter 핀 `3.41.4`; `dart format lib/ test/` 1회 실행 후 커밋(포맷 커밋은 단독으로, 리뷰 노이즈 분리); `pubspec.yaml`의 `assets/images/`·`assets/icons/` 줄 삭제; 워크플로에서 `mkdir -p android/keystore` 또는 경로를 `android/klexi-release.jks`로 정정(현재 `android/key.properties:4`는 `../klexi-release.jks`).
2. CI의 `flutter analyze`는 `firebase_options.dart`가 없으면 `main.dart:15`에서 실패 → 워크플로에 `FIREBASE_OPTIONS_DART` secret에서 파일 복원 단계 추가(secret 등록은 사용자 몫; PM이 요청).
3. `README.md`의 CI 배지는 CI가 실제로 초록이 된 뒤에만 유지.
완료 기준: GitHub Actions에서 analyze+test+build 3 job 초록(푸시 후 PM이 확인).

#### WP-12 죽은 코드·잔재 제거 (확정 목록)
- `lib/core/services/polar_service.dart`(3줄 re-export)를 import하는 5곳 교체: `review_screen.dart:7`, `sentence_practice_screen.dart:14`, `pronunciation_screen.dart:9`, `level_words_screen.dart:10`, `word_network_screen.dart:15` → `purchase_service.dart`. 그 후 파일 삭제.
- `functions/src/polar.ts` 삭제, `@polar-sh/sdk` 제거, `package.json:3` description 정정, `@types/multer`를 devDependencies로.
- `lib/core/utils/srs_algorithm.dart`(SM-2, import 0건) 삭제. 실제 스케줄러는 `daily_session_service.dart:40-47`의 고정 간격표 `[1,3,7,14,30,60]` — `docs/ADR/`·README의 "SM-2" 표현을 사실대로 정정.
- `WordRepository.getDailyWords`, `flutter_animate`(미사용), `mockito`(미사용) 제거. `cached_network_image`는 WP-11에서 사용.
- `theme_sentences.dart`(48문장, 소비 화면 없음): 테마 상세에 "예문" 섹션으로 노출(권장) 또는 삭제 — **PM 결정: 노출**(이미 만든 콘텐츠는 자산).
- `Word.relatedIds`는 어떤 데이터에도 채워지지 않음 → 워드네트워크 패널의 "Related" 섹션은 `relatedWordsMap` 기준으로만 그리도록 정리.

#### WP-13 코드 품질
- `withOpacity`→`.withValues(alpha:)` 91~134건(일괄 치환 후 analyze).
- `Color(0x…)` 리터럴 119건(특히 `settings_screen.dart` 40, `progress_screen.dart` 25)을 `AppColors` 토큰으로; TOPIK 배지 13곳(12파일)을 `core/widgets/topik_badge.dart`로 추출; 페이월 UI 4중복은 WP-06 헬퍼로 흡수.
- `flutter_markdown 0.7.7+1`은 **단종** → `flutter_markdown_plus`로 교체(사용처 확인 후).
- 싱글턴(`DailySessionService.instance`, `PurchaseService.instance`, `AnalyticsService.instance`, `WordRepository.instance`)과 Riverpod 혼용: 이번 빌드에서는 **새 코드만** provider 경유, 전면 리팩터는 build54. 단 `PurchaseService.attachNotifier`의 `late` 역참조는 WP-03에서 provider 내부 생성으로 제거.
- `analysis_options.yaml`의 `avoid_catches_without_on_clauses` 위반(`main.dart:28`, `review_screen.dart:68`) 정리.

#### WP-14 테스트
- 가짜 테스트 6개(`dalli_chat_test`, `sm2_algorithm_test`, `tts_service_test`, `notification_service_test`, `pronunciation_service_test` 절반, 플레이스홀더 `widget_test.dart`)는 테스트 내부에 복제한 함수를 검증할 뿐 → 삭제.
- 신규: `getTodaySession`(임시 디렉토리 `Hive.init` + 시계 주입), `SessionSelector`(WP-07), `QuizBuilder` 4옵션·중복없음, `deleteAccount` 정리 순서(서비스 분리 후 목), 게이팅(`PaywallGate`가 free/premium에서 각각 무엇을 렌더하는지 위젯 테스트 1개).
- Windows에서 `flutter test`가 멈추는 문제: 파일 단위로 `flutter test test/word_model_test.dart`를 먼저 실행해 엔진 레벨 hang인지 확인. `Word`가 `HiveObject`를 상속해 `dart test`가 불가한 것도 원인 — WP-11에서 `Word`를 순수 클래스로 바꾸면 `lib/data/**` 테스트는 `dart test`로 실행 가능해짐. 결과를 PM에 보고(이 머신 이슈면 CI에서만 test 실행).

#### WP-15 문서 진실화
- `KlexiDev/CLAUDE.md`: 경로 `C:/KlexiDev/`→`C:\workspace\klexi\KlexiDev\`, 버전 build51→53, "알려진 이슈" 표 현행화(A·B·D·F는 해결됨, C(npm) 이월), 봇 역할 규칙 추가.
- `docs/CHANGELOG.md`: build49~53 항목 추가(52의 계정삭제 재구현·FCM/알림 수정 포함).
- `README.md`: Flutter 템플릿 → 실제 프로젝트 설명(설치·env·빌드·서명 절차 요약, 시크릿 제외).
- ADR 추가: `0005-backend-auth-id-token.md`, `0006-study-data-per-uid.md`, `0004` SRS 표현 정정.

---

## 6. 공통 구현 규격 (구현 봇이 그대로 따를 것)

### 6.1 백엔드 인증 미들웨어 (WP-01)
```ts
// functions/src/auth.ts
import * as admin from "firebase-admin";
import type { Request, Response, NextFunction } from "express";
export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  const h = req.headers.authorization ?? "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: "unauthenticated" });
  try {
    (req as any).uid = (await admin.auth().verifyIdToken(token)).uid;
    return next();
  } catch { return res.status(401).json({ error: "invalid_token" }); }
}
```
`index.ts`: `app.use("/api/ai-chat", requireAuth)`, `app.use("/api/ai-tts", requireAuth)`, `app.use("/api/pronunciation", requireAuth)`; `/api/health`는 제외. `onRequest({ ..., maxInstances: 5 })`.

### 6.2 클라이언트 토큰 인터셉터 (WP-01)
`lib/core/network/api_client.dart` 신설: 단일 `Dio` 인스턴스 + `InterceptorsWrapper(onRequest: idToken 첨부)`. `tts_service.dart:145` `dioProvider`, `pronunciation_service.dart:108` `_dioProvider`, 채팅의 `http.Client` 호출 모두 이 클라이언트로 통일(SSE는 `dio`의 `ResponseType.stream`). 401 수신 시 `AuthRequiredException` → 화면은 "Sign in to use AI features" + 로그인 버튼.

### 6.3 데이터 모델 (WP-03)
- 박스명: `study_records_$uid` (게스트도 `study_records_guest_xxx`). 마이그레이션: 앱 시작 시 `Hive.boxExists('study_records')`이면 현재 uid 박스로 복사 후 삭제(1회, 실패 시 원본 유지 + Crashlytics).
- `AuthService`는 `Stream<KlexiUser?>` 노출 → `DailySessionService`가 구독해 박스 스위칭. 화면은 `currentUserProvider`만 본다.
- 삭제 순서(**D-10 개정**): `user.delete()`(requires-recent-login이면 Google 재인증 후 재시도) **성공 후에만** 로컬 정리 — RC logOut → FCM deleteToken → Hive 박스 deleteFromDisk → prefs.clear → temp 파일 → 상태 초기화 → `/auth`. 각 로컬 단계는 독립 try/catch + Crashlytics 비치명. 이유: 재인증을 사용자가 취소하면 로컬만 지워지고 계정은 남는 비대칭 실패를 피해야 함(구현봇 지적으로 정정).

### 6.4 알림 (WP-04) 매니페스트 스니펫
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<application ... android:enableOnBackInvokedCallback="true"
    android:dataExtractionRules="@xml/data_extraction_rules"
    android:fullBackupContent="@xml/backup_rules">
  <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
  <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
      <action android:name="android.intent.action.BOOT_COMPLETED"/>
      <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
      <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
  </receiver>
```

### 6.5 워드네트워크 렌더 (WP-11)
- `_NetworkState extends ChangeNotifier` (positions, hovered) → `CustomPaint(painter: _Painter(state), ...)` with `super(repaint: state)`. 틱은 `state.notifyListeners()`만; 위젯 트리 `setState` 금지.
- `Map<String, TextPainter> _labelCache` 키 `'${id}|${fontSize.round()}|${bold}'`; 스케일 변경 시 폰트 단계(3단계)로 양자화해 캐시 히트 유지.
- 엣지: 노드셋 변경 시 1회 `List<Offset>` 쌍 계산(그래프 좌표 기준 임계값), 프레임에는 `canvas.drawPoints(PointMode.lines, ...)` 색상별 1회.
- 목표: 300노드 평균 프레임 ≤12ms(에뮬레이터 profile 모드).

### 6.6 문자열/디자인 토큰
- 사용자 노출 문자열은 전부 `AppStrings`. 한국어는 콘텐츠 데이터에만.
- `AppColors.textMuted = 0xFF6B7280`(≤13px 텍스트), 버튼 primary `0xFF5A6FD6`, 최소 터치 44dp.

---

## 7. 구현 봇 보고 템플릿 (WP마다)
```
[WP-XX 완료 보고]
변경 파일: (경로 목록)
핵심 변경: 3줄 이내
검증: flutter analyze → 에러 0 (경고 N) / 관련 테스트 → 통과 N / 에뮬레이터: 무엇을 어떻게 확인했나(명령·로그·스크린샷 경로)
미해결/리스크: …
커밋: <hash> build53/WP-XX: …
PM 결정 필요: (있으면)
```

## 8. 검증 명령 모음
```powershell
# 에뮬레이터
& "C:\androidsdk\platform-tools\adb.exe" devices
flutter run -d emulator-5554                     # 디버그
flutter run -d emulator-5554 --profile           # 성능 측정
& "C:\androidsdk\platform-tools\adb.exe" shell dumpsys alarm | Select-String twentykorean   # 리마인더 예약
& "C:\androidsdk\platform-tools\adb.exe" reboot   # 재부팅 후 알람 생존 확인
& "C:\androidsdk\platform-tools\adb.exe" logcat -s flutter   # 앱 로그
# 백엔드 (배포 후, PM 승인 필요)
curl -s -o NUL -w "%{http_code}" -X POST https://klexi-30ab5.web.app/api/ai-chat -H "Content-Type: application/json" -d "{}"   # 기대 401
# 릴리즈
flutter build appbundle --release
& "C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe" -verify -verbose:summary -certs build\app\outputs\bundle\release\app-release.aab   # jar verified + 7EDE361C
```

## 10. PM 결정 로그
| ID | 일시 | 결정 |
|---|---|---|
| D-01 | 09-10 | CI `firebase_options.dart`는 워크플로 내 더미 생성(공개 클라이언트 설정, secret 불필요) |
| D-02 | 09-10 | `build-android` job은 `KEYSTORE_BASE64` secret 없으면 조건부 skip; 복원 경로 `android/klexi-release.jks`+`android/key.properties` |
| D-03 | 09-10 | 포맷터가 유발한 `curly_braces` 린트 4건은 중괄호 추가(WP-13 선반영) |
| D-04 | 09-10 | **2트랙 병렬 승인**. A=백엔드·정책·문서(`functions/**`, `web/**`, Manifest, `res/xml`, gradle 1건, proguard, `docs/**`, `.github/**`, README) / B=앱 코어(`lib/**`, `test/**`, `pubspec.yaml`). B 순서 WP-03→04→02(클라, §6 계약 기준)→07→06→09→10→11→12(lib)→13. 경계 밖 편집 금지 |
| D-05 | 09-10 | 트랙 A는 구현봇(claude-84)이 Agent 서브에이전트 1개로 운영, git worktree `klexi_src_trackA`/브랜치 `build53/track-a`, WP 단위로 master에 merge --no-ff |
| D-06 | 09-10 | analyze·에뮬레이터·deploy는 직렬(한 번에 하나). 백엔드 배포는 WP-01 보고→PM 승인→A 배포→curl 증빙 |
| D-02′ | 09-10 | signing 가드는 job `if`가 아니라 step 레벨(`steps.signing.outputs.available`) — GitHub Actions 제약 |
| D-07 | 09-10 | WP 완료 시 master push 승인(배포 파이프라인 없음, build-android 스킵) — 형님 거부 시 되돌림 |
| D-08 | 09-10 | CI `flutter test` 실패 시 가짜 테스트 6개+widget_test 즉시 삭제(WP-14a). `continue-on-error` 금지 |
| D-09 | 09-10 | 이번 세션 범위 = P0 + "required 인자"(WP-07 일부, 수익 버그) 앞당김. B: 03→07a→04→02 / A: 01→05. 종료 전 `docs/HANDOFF_build53.md` 필수 |
| D-10 | 09-10 | 계정삭제는 서버 삭제 성공 후 로컬 정리(§6.3 개정) — 구현봇 지적 채택 |
| D-11 | 09-10 | 중간 커밋이 컴파일 불가면 WP 합본 커밋 허용(`build53/WP-03+WP-07a:`). 원칙: 모든 커밋은 단독 analyze 통과 |
| D-12 | 09-10 | `firebase.json`은 트랙 B 담당: functions `predeploy`(ci+build) 추가, `hosting.public`→`web` |
| D-14 | 09-10 | WP-14 "가짜 테스트 6개 일괄 삭제" 철회 → **한 건씩 "무엇을 검증하는가" 판단 후 삭제/보강**. 근거: `grammar_content_test`가 유료 Grammar Coach 예문 74건 영어 공백·`g2-11` meaning 공백을 잡아냄(`1e0c3e3`에서 수정) |
| D-15 | 09-10 | `flutter test`는 **CI(ubuntu)에서만** 실행(90건 2m23s 통과). Windows hang 원인 규명은 P2 최하위 |
| D-16 | 09-10 | 규칙: 포맷/린트 검증은 반드시 실제 패키지 컨텍스트(`.dart_tool/package_config.json` 존재)에서. 격리 디렉토리는 언어 버전이 달라 결과가 뒤집힘(`6bd778f` 자기정정 사례) |
| D-17 | 09-10 | 백엔드(soft) 배포는 **다음 세션**(형님 결정). 결제 활성 확인됨, 선결 조건 없음 — 다음 세션 첫 승인 항목 |
| D-18 | 09-10 | 이 계획서·7축 리뷰 원문(`docs/reviews/2026-09-10/`)·`CLAUDE.md`를 git 저장소(`klexi_src`)로 편입. `KlexiDev/CLAUDE.md`는 포인터. 이유: 9/1 워킹트리 유실 전례, 결정 대장 백업 |
| D-13 | 09-10 | **백엔드 인증 2단계 배포**: 1단계 `AUTH_MODE=soft`(토큰 없음 통과+계수, 무효 토큰 401, 입력검증·상한은 즉시) → build52 사용자 무중단. 2단계 `hard`는 build53 프로덕션 ≥90% 분포 또는 출시 14일 중 먼저 오는 시점에 PM 결정 재배포. S1 게이트의 "배포 승인"은 1단계 기준 |

## 9. Definition of Done (build53 RC 게이트)
1. P0 WP-00~05 전부 완료·보고·PM 검토 통과. P1 WP-06~11 완료(WP-11은 수치 첨부). P2는 WP-12·15 필수, 13·14는 가능한 만큼.
2. `flutter analyze` 에러 0·경고 0, CI 초록, `dart format` 클린.
3. 에뮬레이터 API 36.1 워크스루: 온보딩→게스트→학습→퀴즈→구글로그인(에뮬레이터 Play 계정 필요, 불가 시 사용자 실기기)→설정→리마인더→계정삭제. 스크린샷 `KlexiDev/qa/build53/`에 저장.
4. 백엔드 배포 후 401/200/400 시나리오 통과.
5. `pubspec 1.0.6+53`, AAB 서명 `7EDE361C` 확인, `releases/klexi-v1.0.6-build53.aab` 저장, CHANGELOG·CLAUDE.md·dev_log 갱신, GitHub push.
6. 사용자 실기기 체크리스트(§4-4) 전달 → 통과 후 Play 업로드.
