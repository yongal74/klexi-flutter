import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// TTS 음성 속도
enum TtsSpeed {
  normal,  // 1.0x — 일반 속도
  slow,    // 0.6x — 학습자용 느린 속도
}

/// TTS 엔진 우선순위
/// 1. Naver CLOVA Voice (서버 프록시) — 최고 품질 한국어
/// 2. Google Cloud TTS Neural2 (서버 프록시) — 고품질 fallback
/// 3. flutter_tts (기기 내장) — 오프라인 fallback
class TtsService {
  final Dio _dio;
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _fallbackTts = FlutterTts();
  bool _fallbackInitialized = false;

  // CLOVA Voice 설정
  static const String _clovaVoice = 'nara';       // 여성 (clara/jinho/nara/matt)
  static const String _clovaVoiceSlow = 'nara';   // 느린 속도도 동일 목소리

  // Google Neural2 한국어 목소리
  static const String _googleVoice = 'ko-KR-Neural2-C';  // 여성 Neural2

  TtsService(this._dio);

  /// 단어 또는 문장 발음
  /// [text] 한국어 텍스트
  /// [speed] 재생 속도 (normal / slow)
  /// [isPremium] 프리미엄 여부 (무료: 기기 TTS, 프리미엄: CLOVA/Google)
  Future<void> speak(
    String text, {
    TtsSpeed speed = TtsSpeed.normal,
    bool isPremium = false,
  }) async {
    if (isPremium) {
      // 1순위: Naver CLOVA Voice
      final success = await _speakWithClova(text, speed);
      if (success) return;

      // 2순위: Google Cloud TTS Neural2
      final googleSuccess = await _speakWithGoogle(text, speed);
      if (googleSuccess) return;
    }

    // 3순위: 기기 내장 TTS (무료 또는 API 실패 시)
    await _speakWithDeviceTts(text, speed);
  }

  /// Naver CLOVA Voice — 서버 프록시 호출
  Future<bool> _speakWithClova(String text, TtsSpeed speed) async {
    try {
      final cached = await _loadCached(text, speed, 'clova');
      if (cached != null) {
        await _playFile(cached);
        return true;
      }

      final response = await _dio.post(
        '/api/tts/clova',
        data: {
          'text': text,
          'voice': speed == TtsSpeed.slow ? _clovaVoiceSlow : _clovaVoice,
          'speed': speed == TtsSpeed.slow ? -4 : 0,  // CLOVA: -10~10
          'pitch': 0,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final file = await _saveCache(text, speed, 'clova', response.data);
        await _playFile(file);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Google Cloud TTS Neural2 — 서버 프록시 호출
  Future<bool> _speakWithGoogle(String text, TtsSpeed speed) async {
    try {
      final cached = await _loadCached(text, speed, 'google');
      if (cached != null) {
        await _playFile(cached);
        return true;
      }

      final response = await _dio.post(
        '/api/tts/google',
        data: {
          'text': text,
          'voice': _googleVoice,
          'speakingRate': speed == TtsSpeed.slow ? 0.65 : 1.0,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final file = await _saveCache(text, speed, 'google', response.data);
        await _playFile(file);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// 기기 내장 TTS (오프라인 fallback)
  Future<void> _speakWithDeviceTts(String text, TtsSpeed speed) async {
    if (!_fallbackInitialized) {
      await _fallbackTts.setLanguage('ko-KR');
      await _fallbackTts.setVolume(1.0);
      _fallbackInitialized = true;
    }
    await _fallbackTts.setSpeechRate(speed == TtsSpeed.slow ? 0.4 : 0.5);
    await _fallbackTts.speak(text);
  }

  /// MP3 파일 재생
  Future<void> _playFile(File file) async {
    await _player.stop();
    await _player.setFilePath(file.path);
    await _player.play();
  }

  /// 오디오 캐시 저장 경로
  Future<String> get _cacheDir async {
    final dir = await getTemporaryDirectory();
    final ttsDir = Directory('${dir.path}/tts_cache');
    if (!await ttsDir.exists()) await ttsDir.create(recursive: true);
    return ttsDir.path;
  }

  String _cacheKey(String text, TtsSpeed speed, String engine) {
    final slug = text.hashCode.abs().toString();
    final speedTag = speed == TtsSpeed.slow ? 'slow' : 'normal';
    return '${engine}_${slug}_$speedTag.mp3';
  }

  Future<File?> _loadCached(String text, TtsSpeed speed, String engine) async {
    final dir = await _cacheDir;
    final file = File('$dir/${_cacheKey(text, speed, engine)}');
    return await file.exists() ? file : null;
  }

  Future<File> _saveCache(
    String text, TtsSpeed speed, String engine, List<int> bytes) async {
    final dir = await _cacheDir;
    final file = File('$dir/${_cacheKey(text, speed, engine)}');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> stop() async {
    await _player.stop();
    await _fallbackTts.stop();
  }

  void dispose() {
    _player.dispose();
    _fallbackTts.stop();
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
