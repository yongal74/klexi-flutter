// test/tts_service_test.dart
// Tests for TTS tier selection logic
import 'package:flutter_test/flutter_test.dart';

enum TtsTier { clova, googleNeural2, device }

TtsTier _selectTier({
  required bool clovaAvailable,
  required bool googleAvailable,
}) {
  if (clovaAvailable) return TtsTier.clova;
  if (googleAvailable) return TtsTier.googleNeural2;
  return TtsTier.device;
}

bool _isKorean(String text) {
  return text.runes.any((r) => r >= 0xAC00 && r <= 0xD7A3);
}

double _parseSpeedMultiplier(bool slowMode) => slowMode ? 0.75 : 1.0;

void main() {
  group('TTS tier selection', () {
    test('selects CLOVA when available', () {
      expect(
        _selectTier(clovaAvailable: true, googleAvailable: true),
        TtsTier.clova,
      );
    });

    test('falls back to Google Neural2 when CLOVA unavailable', () {
      expect(
        _selectTier(clovaAvailable: false, googleAvailable: true),
        TtsTier.googleNeural2,
      );
    });

    test('falls back to device TTS when both unavailable', () {
      expect(
        _selectTier(clovaAvailable: false, googleAvailable: false),
        TtsTier.device,
      );
    });
  });

  group('Korean text detection', () {
    test('detects Korean Hangul', () {
      expect(_isKorean('안녕하세요'), true);
    });

    test('returns false for pure English', () {
      expect(_isKorean('Hello world'), false);
    });

    test('returns true for mixed Korean/English', () {
      expect(_isKorean('Hello 안녕'), true);
    });

    test('returns false for empty string', () {
      expect(_isKorean(''), false);
    });

    test('returns false for numbers and punctuation', () {
      expect(_isKorean('1234!@#\$'), false);
    });
  });

  group('TTS speed multiplier', () {
    test('slow mode returns 0.75x', () {
      expect(_parseSpeedMultiplier(true), 0.75);
    });

    test('normal mode returns 1.0x', () {
      expect(_parseSpeedMultiplier(false), 1.0);
    });
  });
}
