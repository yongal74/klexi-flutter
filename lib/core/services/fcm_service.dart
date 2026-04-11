import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Token retrieved');
        await _saveToken(token);
      }
    }

    // Refresh token whenever it rotates
    _subs.add(_messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed');
      await _saveToken(newToken);
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

  /// Saves FCM token to SharedPreferences for backend delivery on next API call.
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// Returns the stored FCM token (to be sent to backend with user auth).
  static Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

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
