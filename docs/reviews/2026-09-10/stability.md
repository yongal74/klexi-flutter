# Klexi correctness / crash-risk review — 2026-09-10 (원문)

Confirmed: the backend mounts only `/api/ai-chat`, `/api/ai-tts`, `/api/pronunciation/score`; the two TTS endpoints the app calls do not exist.

**1. P1 — Daily reminder silently never schedules on Android 12+**
`lib/core/services/notification_service.dart:81` uses `AndroidScheduleMode.exactAllowWhileIdle`, but neither `android/app/src/main/AndroidManifest.xml` nor the plugin manifest declares `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`. flutter_local_notifications 18 calls `checkCanScheduleExactAlarms()` and throws `PlatformException(exact_alarms_not_permitted)`. `notification_settings_screen.dart:54` catches and only `debugPrint`s, so the user sees no error and no reminder ever fires. Repro: Android 12+ device → Notifications → enable, back. No notification at 09:00. Fix: use `AndroidScheduleMode.inexactAllowWhileIdle` (a daily nudge needs no exact alarm), or add `USE_EXACT_ALARM` + `requestExactAlarmsPermission()`. Confidence: high.

**2. P1 — Session is never restored; every cold start lands on the login screen**
`AuthService.restoreSession()` (`auth_service.dart:28`) has zero callers; `currentUserProvider` starts `null` and `app_router.dart:61-65` redirects to `/auth`. Paying users must tap "Continue with Google" on every launch (guests get a new guest id each time unless prefs match). Fix: in `main()` after Firebase init: `container.read(currentUserProvider.notifier).state = await container.read(authServiceProvider).restoreSession();`. Confidence: high.

**3. P1 — Account deletion does not delete study data; study data is not per-user**
`DailySessionService` opens box `'study_records'` (`daily_session_service.dart:88`), but `_deleteLocalData` deletes `'study_records_<uid>'` (`auth_service.dart:138`) and `_migrateHiveData` copies `'study_records_<guest>'` (`:170`) — both names never exist. Consequences: (a) "permanently deletes … study history" claim in Settings is false (Play policy risk); (b) signing in with another Google account on the same device inherits the previous user's streak/records; (c) guest→Google migration is a no-op. Fix (minimal): in `deleteAccount()` and `signOut()` call `DailySessionService.instance.resetSession()`. Proper: name the box `study_records_$uid` and reopen on auth change. Confidence: high.

**4. P1 — Premium CLOVA/Google TTS endpoints do not exist on the backend**
`tts_service.dart:81,113` POST `/api/tts/clova` and `/api/tts/google`; `functions/src/index.ts:32-34` mounts only ai-chat, ai-tts, pronunciation. Every premium TTS tap does two 404 round-trips, logs two Crashlytics non-fatals (`:97,:128`, new this week — will flood Crashlytics), then falls back to device TTS with ~1–2 s delay. `sentence_practice_screen.dart:118` and `word_card_screen.dart:46` pass `isPremium: true` unconditionally, so free users hit this too. Fix: route both to the existing `/api/ai-tts` (or implement the routes); don't `recordError` on 404. Confidence: high.

**5. P2 — Unhandled FCM init errors are recorded as *fatal* crashes**
`main.dart:27` `unawaited(FcmService().initialize())` runs outside the `try` after the await chain; a `PlatformException` from `requestPermission`/`getToken` (no Play Services, FIS auth failure) reaches `PlatformDispatcher.onError` (`analytics_service.dart:28-31`) which records `fatal: true`, corrupting crash-free-user metrics. Fix: `unawaited(FcmService().initialize().catchError((e, s) => AnalyticsService.instance.recordError(e, s)))`. Confidence: high.

**6. P2 — Notification-tap deep links are dead code**
`fcm_service.dart:86-95` stores `_pendingRoute`, but `consumePendingRoute()` is never called anywhere. Tapping a push with `screen=premium` just opens the app. Fix: in `appRouterProvider.redirect`, `final p = FcmService.consumePendingRoute(); if (p != null && isAuthed) return p;`. Confidence: high.

**7. P2 — `tz.local` never initialised → reminder drifts across DST**
`notification_service.dart:15` calls `initializeTimeZones()` but never `setLocalLocation`; `tz.local` is UTC. First fire is correct (instant preserved), but `matchDateTimeComponents.time` repeats at a fixed UTC time, so US/EU users get the reminder an hour off after DST changes. Fix: `tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()))`. Confidence: medium-high.

**8. P2 — Premium entitlement never tied to the account; not cleared on sign-out/delete**
No `Purchases.logIn(uid)`/`logOut()` anywhere; `signOut()`/`deleteAccount()` (`auth_service.dart:89,132`) leave `premiumProvider` true. A deleted/signed-out user (or the next person on the device) keeps Pro; on a new device the user must find "Restore Purchases". Fix: `Purchases.logIn(uid)` after sign-in, `Purchases.logOut()` + `setPremium(false)` on sign-out/delete. Confidence: medium.

**9. P2 — Pronunciation upload mislabels AAC as WebM**
`pronunciation_screen.dart:137` records `aacLc` to `.m4a`; `pronunciation_service.dart:82` uploads it as `filename: 'recording.webm'` with default octet-stream type; backend forwards `originalname` to Whisper (`pronunciation.ts:78-81`), which sniffs by extension → likely "Invalid file format" → 500 → user sees score 0 "채점 서버 오류". Fix: `filename: 'recording.m4a', contentType: MediaType('audio','mp4')`. Confidence: medium.

**10. P2 — `Purchases.configure` outside try/catch blocks `runApp`**
`purchase_service.dart:38` + `main.dart:43`: any throw (billing unavailable, plugin init) aborts `main()` before `runApp` → blank white screen. Fix: wrap `initialize()` body in try/catch. Confidence: medium.

**11. P2 — App Version shows "1.0.0" while pubspec is 1.0.6+52**
`settings_screen.dart:99` hardcoded. Fix: `package_info_plus` → `'${info.version} (${info.buildNumber})'`. Confidence: high.

**12. P2 — Free users get all 7,200 words in Fill-in-the-Blank**
`cloze_quiz_screen.dart:32-36` shuffles `getAllWords()` with no premium/level filter, and the route has no `PaywallGate` — bypasses the level-1-only monetisation gate. Fix: filter `w.level == 1` when `!isPremium`. Confidence: high.

**13. P2 — `setState` after dispose in async loaders**
`sentence_card_screen.dart:166` (after `await recordReview`), `daily_session_screen.dart:36`, `cloze_quiz_screen.dart:35`: no `mounted` guard. Closing the screen mid-await throws (`_element!` null in release) → surfaces as a Crashlytics fatal via #5's handler. Fix: `if (!mounted) return;` before each `setState`. Confidence: high (occurrence rare).

**14. P2 — Weekly activity shifts a day across DST fall-back**
`daily_session_service.dart:250` `today.subtract(Duration(days: weekday-1))` can land at 23:00 of the previous day, so Mon→Sun bars start on Sunday for that week. Fix: `DateTime(today.year, today.month, today.day - (today.weekday - 1))`. Confidence: medium.

**15. P2 — Backend chat cache ignores `mode`; SSE `error` events are dropped client-side**
`ai-chat.ts:50` keys on `level:message` only, so a Role-Play reply can be served for Grammar Coach. On upstream failure it writes `{error}` (`:161`), which `dalli_chat_screen.dart:212-215` ignores → user sees no reply at all. Fix: include `mode` in key; in client, on `parsed['error']` append an error bubble. Confidence: high.

**Test coverage note:** `test/` covers only pure models/algorithms (SrsAlgorithm — which the app doesn't use; StudyRecord; word data). None of #1–#10 (notifications, auth restore, Hive box naming, purchases, TTS routes, FCM) are exercised; `widget_test.dart` is a placeholder.
