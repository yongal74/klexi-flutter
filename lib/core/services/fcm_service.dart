import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ── Background handler (top-level function required by FCM) ──────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[FCM] Background: ${message.notification?.title}');
}

class FcmService {
  final _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _messaging.getToken();
      print('[FCM] Token: $token');
      // TODO: send token to backend for targeted pushes
    }

    // Foreground notifications
    FirebaseMessaging.onMessage.listen((message) {
      print('[FCM] Foreground: ${message.notification?.title}');
      // Show local notification via NotificationService
    });

    // App opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('[FCM] OpenedApp: ${message.notification?.title}');
      // TODO: navigate to relevant screen based on message.data
    });
  }

  Future<String?> getToken() => _messaging.getToken();

  /// Subscribe to a topic (e.g. 'daily_reminder', 'topik_1')
  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);
}

final fcmServiceProvider = Provider<FcmService>((_) => FcmService());
