import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../constants/app_strings.dart';
import '../network/api_client.dart';
import '../providers/tts_speed_provider.dart';
import '../services/analytics_service.dart';
import '../services/purchase_service.dart';
import '../widgets/app_messenger.dart';

// Mobile-only imports — guarded at runtime with kIsWeb
import 'tts_service_mobile.dart' if (dart.library.html) 'tts_service_web.dart'
    as platform;

/// TTS 음성 속도
enum TtsSpeed {
  normal, // 일반 속도
  slow, // 학습자용 느린 속도
}

/// 발음 엔진 우선순위
/// 1. 서버 프록시 `/api/ai-tts` (OpenAI TTS) — 프리미엄 전용, 로그인 필요
/// 2. flutter_tts — 웹: 브라우저 SpeechSynthesis / 모바일: 기기 내장 TTS
///
/// build52 까지는 서버에 존재한 적 없는 `/api/tts/clova`, `/api/tts/google`
/// 를 호출해 항상 404 -> 기기 TTS 로 떨어졌다. 즉 유료 음성이 한 번도
/// 동작한 적이 없다.
class TtsService {
  final Dio _dio;
  final Ref _ref;
  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  /// OpenAI TTS voice. 서버 화이트리스트와 일치해야 한다.
  static const String _voice = 'nova';

  /// 서버 실패를 Crashlytics 에 매번 올리면 노이즈가 된다. 세션당 1회만.
  bool _serverFailureReported = false;

  TtsService(this._dio, this._ref);

  /// 단어 또는 문장 발음.
  /// [speed] 를 주지 않으면 설정 화면의 "Slow TTS Speed" 값을 따른다.
  /// [isPremium] 을 주지 않으면 현재 구독 상태를 그대로 쓴다 — 화면마다
  /// true 를 하드코딩하던 것이 build52 의 문제였다.
  Future<void> speak(
    String text, {
    TtsSpeed? speed,
    bool? isPremium,
  }) async {
    final rate =
        speed ?? (_ref.read(slowTtsProvider) ? TtsSpeed.slow : TtsSpeed.normal);
    final bool premium = isPremium ?? _ref.read(isPremiumProvider);

    // 웹에서는 파일 재생을 못 하므로 항상 브라우저 SpeechSynthesis.
    if (kIsWeb) {
      await _speakWithTts(text, rate);
      return;
    }

    if (premium && await _speakWithServer(text, rate)) return;

    await _speakWithTts(text, rate);
  }

  /// flutter_tts — 웹(브라우저 SpeechSynthesis) + 모바일(기기 TTS) 공용
  Future<void> _speakWithTts(String text, TtsSpeed speed) async {
    if (!_ttsInitialized) {
      await _tts.setLanguage('ko-KR');
      await _tts.setVolume(1.0);
      _ttsInitialized = true;
    }
    await _tts.setSpeechRate(speed == TtsSpeed.slow ? 0.4 : 0.5);
    await _tts.speak(text);
  }

  /// 서버 프록시 `/api/ai-tts` (OpenAI TTS). 성공하면 true.
  /// 실패는 조용히 false 를 돌려 기기 TTS 로 떨어지되, 사용자에게 한 번은
  /// 무슨 일이 일어났는지 알린다.
  Future<bool> _speakWithServer(String text, TtsSpeed speed) async {
    final isSlow = speed == TtsSpeed.slow;
    try {
      final cached = await platform.loadCached(text, isSlow, _voice);
      if (cached != null) {
        await platform.playFile(cached);
        return true;
      }

      final response = await _dio.post<List<int>>(
        '/api/ai-tts',
        data: {
          'text': text,
          'voice': _voice,
          'speed': isSlow ? 0.7 : 1.0,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (response.statusCode == 200 && bytes != null && bytes.isNotEmpty) {
        final file = await platform.saveCache(text, isSlow, _voice, bytes);
        await platform.playFile(file);
        return true;
      }
      _notifyFallback(AppStrings.usingDeviceVoice);
      return false;
    } on Exception catch (e, st) {
      if (isAuthRequired(e)) {
        _notifyFallback(AppStrings.signInForAi);
      } else {
        _notifyFallback(AppStrings.usingDeviceVoice);
        if (!_serverFailureReported) {
          _serverFailureReported = true;
          AnalyticsService.instance.recordError(e, st);
        }
      }
      return false;
    }
  }

  /// 기기 음성으로 떨어졌다는 사실을 짧게 알린다. 같은 메시지가 연속으로
  /// 쌓이지 않도록 기존 스낵바를 먼저 걷어낸다.
  void _notifyFallback(String message) {
    final messenger = klexiMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> stop() async {
    await _tts.stop();
    await platform.stopPlayer();
  }

  void dispose() {
    _tts.stop();
    platform.disposePlayer();
  }
}

// Riverpod Provider
final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService(ref.watch(apiDioProvider), ref);
});
