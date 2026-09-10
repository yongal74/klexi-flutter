import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/daily_session_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/purchase_service.dart';
import 'core/theme/app_theme.dart';
import 'data/models/word.dart';

// Firebase — requires google-services.json (Android) + GoogleService-Info.plist (iOS)
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 — 실패 시 로그 출력 후 앱 계속 실행
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await AnalyticsService.instance.init();
  } on Exception catch (e, stack) {
    debugPrint('[Firebase] 초기화 실패: $e');
    debugPrint('[Firebase] $stack');
    // Crashlytics 없이도 앱은 계속 실행됨
  }

  await Hive.initFlutter();
  Hive.registerAdapter(WordAdapter());

  final container = ProviderContainer();
  PurchaseService.instance
      .attachNotifier(container.read(premiumProvider.notifier));

  // 이전 세션 복원 — runApp 전에 끝내야 라우터가 첫 프레임부터 홈으로 간다.
  // build52 까지는 restoreSession() 을 아무도 부르지 않아서 앱을 켤 때마다
  // 로그인 화면이 떴다.
  KlexiUser? restored;
  try {
    restored = await container.read(authServiceProvider).restoreSession();
  } on Exception catch (e) {
    debugPrint('[Auth] 세션 복원 실패: $e');
  }
  if (restored != null) {
    await DailySessionService.instance.init(restored.id);
    container.read(currentUserProvider.notifier).state = restored;
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const KlexiApp(),
    ),
  );

  // 네트워크가 필요한 초기화는 첫 프레임 이후로 미룬다 — 콜드스타트를 막지 않는다.
  unawaited(_initAfterFirstFrame());
}

/// runApp 이후에 도는 초기화. 여기서 던진 예외는 앱을 죽여선 안 되므로
/// 각각 따로 삼키고 로그만 남긴다.
Future<void> _initAfterFirstFrame() async {
  try {
    await PurchaseService.instance.initialize();
  } on Exception catch (e) {
    debugPrint('[Purchase] 초기화 실패: $e');
  }
  try {
    // POST_NOTIFICATIONS (Android 13+) / APNs 권한 요청 + 푸시 토큰 등록.
    await FcmService().initialize();
  } on Exception catch (e) {
    debugPrint('[FCM] 초기화 실패: $e');
  }
}

class KlexiApp extends ConsumerWidget {
  const KlexiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Klexi — Learn Korean',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
