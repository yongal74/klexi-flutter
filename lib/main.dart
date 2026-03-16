import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/services/daily_session_service.dart';
import 'core/theme/app_theme.dart';
import 'data/models/word.dart';

// Firebase — requires google-services.json (Android) + GoogleService-Info.plist (iOS)
// These files must be downloaded from Firebase Console and added manually.
// After adding them, run: flutterfire configure
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();
  Hive.registerAdapter(WordAdapter());
  await DailySessionService.instance.init();

  runApp(
    const ProviderScope(
      child: KlexiApp(),
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
