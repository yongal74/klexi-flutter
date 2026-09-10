# Klexi (com.twentykorean.app) — Android 16 / Play policy review, build52 — 2026-09-10 (원문)

Verified: `android/app/build.gradle.kts:23,38-39` inherit `flutter.compileSdkVersion` / `targetSdkVersion` / `minSdkVersion` → with Flutter 3.41.4 the shipped AAB is compileSdk/targetSdk 36, minSdk 24, NDK 28.2. So Android 16 behaviour changes apply now.

**1. P0 — Daily reminder never schedules on Android 12+ (throws)**
`lib/core/services/notification_service.dart:81` uses `AndroidScheduleMode.exactAllowWhileIdle`. flutter_local_notifications 18.0.1 (`FlutterLocalNotificationsPlugin.java:758-761`) throws `exact_alarms_not_permitted` when `canScheduleExactAlarms()` is false. The manifest declares neither `SCHEDULE_EXACT_ALARM` nor `USE_EXACT_ALARM` (`AndroidManifest.xml:3-9`), so on API 31+ the check always fails; on API 34+ the permission is denied by default even if declared. The exception is swallowed in `notification_settings_screen.dart:54-56` → user sees no "Settings saved" and no reminder, silently. A language-learning reminder does not qualify for `USE_EXACT_ALARM` (alarm/calendar apps only). Fix: `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`; surface the error in `_save()`. Confidence: high.

**2. P0 — Scheduled reminder dies on reboot**
No `RECEIVE_BOOT_COMPLETED` permission and no `ScheduledNotificationBootReceiver` in `AndroidManifest.xml:10-41`; the plugin's own manifest merges only VIBRATE/POST_NOTIFICATIONS (verified in pub cache). AlarmManager alarms are cleared on reboot, so the reminder stops after the first restart until the user re-saves settings. Fix: declare `RECEIVE_BOOT_COMPLETED` + `ScheduledNotificationReceiver` + `ScheduledNotificationBootReceiver` (BOOT_COMPLETED, MY_PACKAGE_REPLACED, QUICKBOOT_POWERON, com.htc QUICKBOOT_POWERON). Confidence: high.

**3. P1 — Data safety: Advertising ID declared in manifest but not in privacy policy**
`AndroidManifest.xml:9` adds `com.google.android.gms.permission.AD_ID`; `web/privacy.html` has no mention of Advertising ID (SDK table at lines 29-33 lists Analytics/Crashlytics/RevenueCat/OpenAI only). Play's Data safety form must mark "Device or other IDs → Advertising ID" as collected, and the policy should match. Fix: add an "Advertising ID (Firebase Analytics)" row to privacy.html and tick it in the Data safety form; alternatively remove the permission and set `google_analytics_adid_collection_enabled=false`. Confidence: high.

**4. P1 — Backup rules absent (relevant to "secure device migration" notice)**
No `android:allowBackup`, `dataExtractionRules` (API 31+) or `fullBackupContent` on `<application>`, no `res/xml/` at all. Default = allowBackup true, everything backed up/transferred: Hive study boxes, SharedPreferences including `fcm_token` (`fcm_service.dart:71`, device-specific → stale token restored to a new device), and RevenueCat/Firebase caches. Fix: add `dataExtractionRules` + `fullBackupContent` that include the Hive dir/shared_prefs but exclude `fcm_token` (or stop persisting it). Confidence: medium.

**5. P1 — Edge-to-edge: status bar overlap on AppBar-less screens**
API 35+/36 enforces edge-to-edge and ignores `windowOptOutEdgeToEdgeEnforcement`. `styles.xml:4,15` use plain `Theme.Light.NoTitleBar` (no `windowLightStatusBar`), and `app_theme.dart:37` only sets transparent status bar for AppBar screens. Screens with `Scaffold` + `SafeArea` (`quiz_screen.dart:184`, `sentence_card_screen.dart:188`, etc.) and the bottom nav (`main_scaffold.dart:37`) are correct; `premium_screen.dart:270` handles the bottom inset; `home_screen.dart:63` uses `SliverAppBar` (safe). Remaining risk: `word_network_screen.dart:433-529` computes offsets from `padding.top` manually; `AppTheme.dark => light` (`app_theme.dart:148`) means 3-button nav bar on dark-system-theme devices gets a transparent bar over a light surface — cosmetic. Fix: global `SystemChrome.setSystemUIOverlayStyle` in `main.dart`; visually test `word_network_screen` on an API 36 emulator. Confidence: medium.

**6. P1 — Predictive back not enabled**
`android:enableOnBackInvokedCallback` absent. On API 36 predictive back animations are on by default for apps targeting 36 unless opted out; Flutter 3.41 supports it, and `PopScope.onPopInvokedWithResult` (`notification_settings_screen.dart:69-72`) is the compatible API. go_router 14.8.1 is fine. Fix: add `android:enableOnBackInvokedCallback="true"` and test the back gesture on settings → notifications. Confidence: medium.

**7. P2 — RECORD_AUDIO: no pre-permission rationale**
`pronunciation_screen.dart:132` calls `_recorder.hasPermission()` with no in-app explanation and silently no-ops on denial (`:133-141`). Fix: one-line rationale dialog before first request; on denial show "Enable microphone in Settings". Confidence: high.

**8. P2 — R8 keep rules: fine but bloated**
`proguard-rules.pro:2-22` keeps all of `io.flutter.**`, `com.google.firebase.**`, `com.google.android.gms.**`, `kotlin.**` — safe but defeats minification. Missing: RevenueCat (`-keep class com.revenuecat.purchases.** { *; }`) — purchases_flutter 9.15.1 ships consumer rules, so no crash expected. `com.hive.**` rule (line 14) is a no-op. Confidence: medium.

**9. P2 — Google Sign-In on legacy API**
`pubspec.yaml:23` `google_sign_in ^6.2.2` → 6.3.0 / `google_sign_in_android 6.2.1` (legacy `GoogleSignIn` API). Still works on Android 16 (deprecated, not removed); `google_sign_in 7.x` (Credential Manager) changes the API. `serverClientId` isn't set — relies on `google-services.json`; SHA-1 of the Play upload/signing key must be in Firebase. Fix: schedule the 7.x migration for build54. Confidence: high on facts, medium on urgency.

**10. P2 — 16 KB page size: compliant, one setting to revisit**
No `.so`/CMake in `record_android 1.5.1`, `just_audio 0.9.46`, `flutter_tts 4.2.5`, `audioplayers_android 5.2.1` — all Java/Kotlin. Only native libs are Flutter engine (3.41 + NDK 28.2 = aligned). `build.gradle.kts:65-69` sets `useLegacyPackaging = true` (compressed libs). Acceptable, but Play recommends uncompressed; also increases install size/time. Fix: remove the `packagingOptions.jniLibs` block. Confidence: high.

**11. P2 — Subscription disclosure copy**
`premium_screen.dart:221` hard-codes "Save 48% vs monthly — 7-day free trial" and `:247` "Try Free for 7 Days · then …/yr" regardless of what the RevenueCat offering actually contains (no check of `introductoryPrice`/`freeTrialPeriod`). Price string, billing period, and "Cancel anytime. Subscription automatically renews unless canceled." (`:266`) are present. Missing: link to Terms/Privacy on the paywall. Fix: derive trial/savings text from `storeProduct.introductoryPrice`; add Terms/Privacy links. Confidence: medium.

**12. P2 — Orientation/large-screen**: no `screenOrientation`, no `setPreferredOrientations`; `configChanges` include `orientation|screenSize`. Compliant. Confidence: high.

**13. P2 — Account deletion**: in-app (`settings_screen.dart:174-175,241-284` → `auth_service.dart:98-120`) + web `web/delete-account.html`. Both satisfy Play's requirement; ensure the Play Console URL points at `/delete-account`. Confidence: high.

**Not issues:** `android:exported="true"` only on the launcher activity — correct. No cleartext/network-security-config needed. Foreground services/trampolines: none. "App memory" quality: nothing pathological. "Financial features declaration": subscriptions via Play Billing are not a "financial feature" — answer "No".

## Suggested order for build53
1 + 2 (reminder actually works) → 3 (Data safety/privacy) → 4, 5, 6 (manifest additions) → 10, 8 → 9, 11 as follow-ups.
