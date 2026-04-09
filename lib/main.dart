import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/services/daily_session_service.dart';
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
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await AnalyticsService.instance.init();
  } catch (e, stack) {
    debugPrint('[Firebase] 초기화 실패: $e');
    debugPrint('[Firebase] $stack');
    // Crashlytics 없이도 앱은 계속 실행됨
  }

  await Hive.initFlutter();
  Hive.registerAdapter(WordAdapter());
  await DailySessionService.instance.init();

  final container = ProviderContainer();

  // PurchaseService를 PremiumNotifier에 연결하고 초기화
  final notifier = container.read(premiumProvider.notifier);
  PurchaseService.instance.attachNotifier(notifier);
  await PurchaseService.instance.initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const KlexiApp(),
    ),
  );
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
