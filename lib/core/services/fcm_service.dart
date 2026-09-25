import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ── Background handler (top-level function required by FCM) ──────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background: ${message.notification?.title}');
}

class FcmService {
  final _messaging = FirebaseMessaging.instance;
  final _subs = <StreamSubscription<dynamic>>[];

  /// Called once on app startup (after Firebase.initializeApp).
  Future<void> initialize() async {
    if (_subs.isNotEmpty) return; // idempotent — prevent duplicate listeners

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 권한을 여기서 요청하지 않는다. 예전엔 앱 실행 즉시(로그인 화면 위에서)
    // 알림 권한을 물어 사용자가 이유도 모른 채 거절했다. 권한은 온보딩의
    // "매일 알림" 또는 알림 설정에서 사용자가 켤 때만 요청한다.
    final settings = await _messaging.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Token retrieved');
      }
    }

    // Refresh token whenever it rotates
    _subs.add(_messaging.onTokenRefresh.listen((_) {
      debugPrint('[FCM] Token refreshed');
    }));

    // Foreground notifications
    _subs.add(FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
    }));

    // App opened via notification tap
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] OpenedApp: ${message.notification?.title}');
      _handleNotificationRoute(message.data);
    }));

    // App launched from terminated state via notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleNotificationRoute(initial.data);
    }
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }

  // FCM 토큰은 더 이상 SharedPreferences 에 저장하지 않는다.
  // prefs 는 Android 자동 백업 대상이라, 기기를 바꿔 복원하면 옛 기기의
  // 토큰이 되살아나 푸시가 조용히 죽는다. 필요할 때 getToken() 으로
  // 매번 다시 물어보는 편이 정확하고 비용도 없다(로컬 캐시).

  /// Routes the user to the relevant screen based on notification data.
  /// Expected data keys: 'screen' (e.g. 'learn', 'progress', 'premium')
  void _handleNotificationRoute(Map<String, dynamic> data) {
    final screen = data['screen'] as String?;
    if (screen == null) return;
    // Navigation is handled via GoRouter — store target for post-launch routing
    _pendingRoute = '/$screen';
  }

  /// Pending route set from a notification tap (consumed by app_router on first build).
  static String? _pendingRoute;
  static String? consumePendingRoute() {
    final r = _pendingRoute;
    _pendingRoute = null;
    return r;
  }

  Future<String?> getToken() => _messaging.getToken();

  /// Subscribe to a topic (e.g. 'daily_reminder', 'topik_1')
  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);
}

final fcmServiceProvider = Provider<FcmService>((_) => FcmService());
