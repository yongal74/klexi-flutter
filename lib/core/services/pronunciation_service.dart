// lib/core/services/pronunciation_service.dart
// Sends audio to the Klexi pronunciation server and returns a score.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import '../network/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────

class PronunciationResult {
  final int score; // 0–100
  final String transcript; // what the server heard
  final String expected; // normalised expected text
  final String feedback; // human-readable feedback
  final List<PhonemeDetail> details;

  /// 채점 자체가 실패했을 때의 사용자용 메시지. null 이면 정상 채점 결과.
  /// 예전에는 실패를 score 0 으로 돌려줘서 사용자가 "0점"으로 오해했다.
  final String? error;
  bool get isError => error != null;

  const PronunciationResult({
    required this.score,
    required this.transcript,
    required this.expected,
    required this.feedback,
    required this.details,
    this.error,
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

  factory PronunciationResult.failed(String message) => PronunciationResult(
        score: 0,
        transcript: '',
        expected: '',
        feedback: '',
        details: const [],
        error: message,
      );

  factory PronunciationResult.offline() => PronunciationResult.failed(
      "Couldn't score your recording. Check your connection and try again.");
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
        // 실제 녹음 포맷은 aacLc/.m4a 다(pronunciation_screen.dart).
        // webm 으로 올리면 Whisper 가 포맷을 오인할 수 있다.
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'recording.m4a',
          contentType: MediaType('audio', 'mp4'),
        ),
        'text': expectedText,
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/pronunciation/score',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.data == null) return PronunciationResult.offline();
      return PronunciationResult.fromJson(response.data!);
    } on DioException catch (e) {
      debugPrint('[Pronunciation] DioException: ${e.message}');
      if (isAuthRequired(e)) {
        return PronunciationResult.failed(
            'Sign in with Google to use pronunciation scoring.');
      }
      return PronunciationResult.offline();
    } catch (e) {
      debugPrint('[Pronunciation] Unexpected error: $e');
      return PronunciationResult.offline();
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final pronunciationServiceProvider = Provider<PronunciationService>((ref) {
  return PronunciationService(ref.watch(apiDioProvider));
});
