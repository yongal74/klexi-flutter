// lib/core/services/analytics_service.dart
// Centralised Firebase Analytics + Crashlytics wrapper.
// Call AnalyticsService.instance.* from any screen/service.

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsServiceProvider = Provider<AnalyticsService>(
  (_) => AnalyticsService.instance,
);

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final _fa = FirebaseAnalytics.instance;

  // ── Initialisation ───────────────────────────────────────────────────────

  Future<void> init() async {
    // Disable analytics in debug builds so dev traffic doesn't pollute data
    await _fa.setAnalyticsCollectionEnabled(!kDebugMode);

    // Route all Flutter errors to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // ── User Properties ──────────────────────────────────────────────────────

  Future<void> setUserId(String? userId) =>
      _fa.setUserId(id: userId);

  Future<void> setTopikLevel(int level) =>
      _fa.setUserProperty(name: 'topik_level', value: level.toString());

  Future<void> setIsPremium(bool isPremium) =>
      _fa.setUserProperty(name: 'is_premium', value: isPremium.toString());

  // ── Screen Tracking ──────────────────────────────────────────────────────

  Future<void> logScreen(String screenName) =>
      _fa.logScreenView(screenName: screenName);

  // ── Learning Events ──────────────────────────────────────────────────────

  /// User completed today's daily study session
  Future<void> logSessionCompleted({
    required int wordCount,
    required int topikLevel,
  }) =>
      _fa.logEvent(name: 'session_completed', parameters: {
        'word_count': wordCount,
        'topik_level': topikLevel,
      });

  /// User finished a quiz
  Future<void> logQuizCompleted({
    required int correct,
    required int total,
    required int topikLevel,
  }) =>
      _fa.logEvent(name: 'quiz_completed', parameters: {
        'correct': correct,
        'total': total,
        'score_pct': total > 0 ? ((correct / total) * 100).round() : 0,
        'topik_level': topikLevel,
      });

  /// User completed sentence practice
  Future<void> logSentencePracticeCompleted({required int topikLevel}) =>
      _fa.logEvent(name: 'sentence_practice_completed', parameters: {
        'topik_level': topikLevel,
      });

  /// User viewed a word card detail
  Future<void> logWordCardViewed({
    required String wordId,
    required int topikLevel,
  }) =>
      _fa.logEvent(name: 'word_card_viewed', parameters: {
        'word_id': wordId,
        'topik_level': topikLevel,
      });

  /// TTS played
  Future<void> logTtsPlayed({required String source}) =>
      _fa.logEvent(name: 'tts_played', parameters: {'source': source});

  // ── Word Network ─────────────────────────────────────────────────────────

  Future<void> logWordNetworkOpened() =>
      _fa.logEvent(name: 'word_network_opened');

  Future<void> logWordNetworkNodeTapped({required String wordId}) =>
      _fa.logEvent(name: 'word_network_node_tapped', parameters: {
        'word_id': wordId,
      });

  // ── Engagement ───────────────────────────────────────────────────────────

  /// User changed TOPIK level selector on home
  Future<void> logLevelChanged({required int level}) =>
      _fa.logEvent(name: 'topik_level_changed', parameters: {'level': level});

  /// Spotlight sentence swiped
  Future<void> logSpotlightSwiped({required int index}) =>
      _fa.logEvent(name: 'spotlight_swiped', parameters: {'index': index});

  // ── Premium Funnel ───────────────────────────────────────────────────────

  Future<void> logPremiumScreenViewed() =>
      _fa.logEvent(name: 'premium_screen_viewed');

  Future<void> logCheckoutStarted({required String plan}) =>
      _fa.logEvent(name: 'checkout_started', parameters: {'plan': plan});

  Future<void> logPremiumActivated({required String plan}) =>
      _fa.logEvent(name: 'premium_activated', parameters: {'plan': plan});

  // ── Errors ───────────────────────────────────────────────────────────────

  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  }
}
