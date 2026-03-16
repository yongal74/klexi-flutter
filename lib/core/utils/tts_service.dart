import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Mobile-only imports — guarded at runtime with kIsWeb
import 'tts_service_mobile.dart' if (dart.library.html) 'tts_service_web.dart'
    as platform;

/// TTS 음성 속도
enum TtsSpeed {
  normal, // 1.0x — 일반 속도
  slow, // 0.6x — 학습자용 느린 속도
}

/// TTS 엔진 우선순위
/// 1. Naver CLOVA Voice (서버 프록시) — 최고 품질 한국어  [mobile only]
/// 2. Google Cloud TTS Neural2 (서버 프록시) — 고품질 fallback  [mobile only]
/// 3. flutter_tts — 웹: 브라우저 SpeechSynthesis / 모바일: 기기 내장 TTS
class TtsService {
  final Dio _dio;
  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  // CLOVA Voice 설정
  static const String _clovaVoice = 'nara';
  static const String _googleVoice = 'ko-KR-Neural2-C';

  TtsService(this._dio);

  /// 단어 또는 문장 발음
  Future<void> speak(
    String text, {
    TtsSpeed speed = TtsSpeed.normal,
    bool isPremium = false,
  }) async {
    // 웹에서는 항상 flutter_tts (브라우저 SpeechSynthesis) 사용
    if (kIsWeb) {
      await _speakWithTts(text, speed);
      return;
    }

    if (isPremium) {
      // 1순위: Naver CLOVA Voice
      final success = await _speakWithClova(text, speed);
      if (success) return;

      // 2순위: Google Cloud TTS Neural2
      final googleSuccess = await _speakWithGoogle(text, speed);
      if (googleSuccess) return;
    }

    // 3순위: 기기 내장 TTS
    await _speakWithTts(text, speed);
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

  /// Naver CLOVA Voice — 서버 프록시 (모바일 전용)
  Future<bool> _speakWithClova(String text, TtsSpeed speed) async {
    final isSlow = speed == TtsSpeed.slow;
    try {
      final cached = await platform.loadCached(text, isSlow, 'clova');
      if (cached != null) {
        await platform.playFile(cached);
        return true;
      }

      final response = await _dio.post(
        '/api/tts/clova',
        data: {
          'text': text,
          'voice': _clovaVoice,
          'speed': isSlow ? -4 : 0,
          'pitch': 0,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final file = await platform.saveCache(text, isSlow, 'clova', response.data as List<int>);
        await platform.playFile(file);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Google Cloud TTS Neural2 — 서버 프록시 (모바일 전용)
  Future<bool> _speakWithGoogle(String text, TtsSpeed speed) async {
    final isSlow = speed == TtsSpeed.slow;
    try {
      final cached = await platform.loadCached(text, isSlow, 'google');
      if (cached != null) {
        await platform.playFile(cached);
        return true;
      }

      final response = await _dio.post(
        '/api/tts/google',
        data: {
          'text': text,
          'voice': _googleVoice,
          'speakingRate': isSlow ? 0.65 : 1.0,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final file = await platform.saveCache(text, isSlow, 'google', response.data as List<int>);
        await platform.playFile(file);
        return true;
      }
    } catch (_) {}
    return false;
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
  final dio = ref.watch(dioProvider);
  return TtsService(dio);
});

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: const String.fromEnvironment(
      'API_URL',
      defaultValue: 'https://your-server.com',
    ),
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));
});
