// lib/core/services/pronunciation_service.dart
// Sends audio to the Klexi pronunciation server and returns a score.

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tts_service.dart'; // reuses dioProvider

// ── Model ─────────────────────────────────────────────────────────────────

class PronunciationResult {
  final int score;           // 0–100
  final String transcript;   // what the server heard
  final String expected;     // normalised expected text
  final String feedback;     // human-readable feedback
  final List<PhonemeDetail> details;

  const PronunciationResult({
    required this.score,
    required this.transcript,
    required this.expected,
    required this.feedback,
    required this.details,
  });

  factory PronunciationResult.fromJson(Map<String, dynamic> json) =>
      PronunciationResult(
        score: (json['score'] as num).toInt(),
        transcript: json['transcript'] as String? ?? '',
        expected: json['expected'] as String? ?? '',
        feedback: json['feedback'] as String? ?? '',
        details: (json['details'] as List<dynamic>? ?? [])
            .map((d) => PhonemeDetail.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  /// Fallback result used when the server is unavailable.
  factory PronunciationResult.offline() => const PronunciationResult(
        score: 0,
        transcript: '',
        expected: '',
        feedback: 'Server unavailable. Check your connection.',
        details: [],
      );
}

class PhonemeDetail {
  final String expected;
  final String heard;
  final bool correct;

  const PhonemeDetail({
    required this.expected,
    required this.heard,
    required this.correct,
  });

  factory PhonemeDetail.fromJson(Map<String, dynamic> json) => PhonemeDetail(
        expected: json['expected'] as String? ?? '',
        heard: json['heard'] as String? ?? '',
        correct: json['correct'] as bool? ?? false,
      );
}

// ── Service ───────────────────────────────────────────────────────────────

class PronunciationService {
  final Dio _dio;

  PronunciationService(this._dio);

  /// Upload [audioFile] (recorded by the device) and score it against [expectedText].
  Future<PronunciationResult> score({
    required File audioFile,
    required String expectedText,
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'recording.webm',
        ),
        'text': expectedText,
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/pronunciation/score',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.data == null) return PronunciationResult.offline();
      return PronunciationResult.fromJson(response.data!);
    } on DioException catch (e) {
      // Network / server error — return graceful offline result
      print('[Pronunciation] DioException: ${e.message}');
      return PronunciationResult.offline();
    } catch (e) {
      print('[Pronunciation] Unexpected error: $e');
      return PronunciationResult.offline();
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final pronunciationServiceProvider = Provider<PronunciationService>((ref) {
  final dio = ref.watch(dioProvider);
  return PronunciationService(dio);
});
