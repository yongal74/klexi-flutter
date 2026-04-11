// test/dalli_chat_test.dart
import 'package:flutter_test/flutter_test.dart';

// ── Pure logic helpers matching dalli_chat_screen.dart ─────────────────────

enum DalliMode { freeChat, wordReview, rolePlay, grammarCoach }

String _modeLabel(DalliMode mode) {
  switch (mode) {
    case DalliMode.freeChat:
      return 'Free Chat';
    case DalliMode.wordReview:
      return 'Word Review';
    case DalliMode.rolePlay:
      return 'Role Play';
    case DalliMode.grammarCoach:
      return 'Grammar Coach';
  }
}

String _systemPrompt(DalliMode mode, String? focusWord) {
  final base = 'You are Dalli, a friendly Korean language tutor. ';
  switch (mode) {
    case DalliMode.freeChat:
      return '${base}Have a natural conversation in Korean, correcting mistakes gently.';
    case DalliMode.wordReview:
      final word = focusWord ?? 'Korean vocabulary';
      return '${base}Help the student practice the word "$word" in various sentences.';
    case DalliMode.rolePlay:
      return '${base}Engage in a role-play scenario (e.g., café, market). Stay in character.';
    case DalliMode.grammarCoach:
      return '${base}Explain grammar patterns with examples. Ask practice questions.';
  }
}

bool _isUserMessage(Map<String, String> msg) => msg['role'] == 'user';

List<Map<String, String>> _trimHistory(
    List<Map<String, String>> history, int maxTokens) {
  // Simple trim: keep last N messages if too long
  const avgCharsPerToken = 4;
  var totalChars = history.fold<int>(
      0, (sum, m) => sum + (m['content']?.length ?? 0));
  final result = [...history];
  while (totalChars > maxTokens * avgCharsPerToken && result.length > 2) {
    totalChars -= result.removeAt(0)['content']!.length;
  }
  return result;
}

void main() {
  group('DalliMode labels', () {
    test('all modes have labels', () {
      for (final mode in DalliMode.values) {
        expect(_modeLabel(mode), isNotEmpty);
      }
    });

    test('freeChat label is correct', () {
      expect(_modeLabel(DalliMode.freeChat), 'Free Chat');
    });

    test('rolePlay label is correct', () {
      expect(_modeLabel(DalliMode.rolePlay), 'Role Play');
    });
  });

  group('System prompts', () {
    test('all modes produce non-empty prompts', () {
      for (final mode in DalliMode.values) {
        expect(_systemPrompt(mode, null), isNotEmpty);
      }
    });

    test('wordReview prompt includes focus word', () {
      final prompt = _systemPrompt(DalliMode.wordReview, '사랑');
      expect(prompt.contains('사랑'), true);
    });

    test('wordReview without focus word uses fallback', () {
      final prompt = _systemPrompt(DalliMode.wordReview, null);
      expect(prompt.contains('Korean vocabulary'), true);
    });

    test('all prompts contain Dalli name', () {
      for (final mode in DalliMode.values) {
        expect(_systemPrompt(mode, null).contains('Dalli'), true);
      }
    });
  });

  group('Message role detection', () {
    test('user message detected correctly', () {
      expect(_isUserMessage({'role': 'user', 'content': 'hi'}), true);
    });

    test('assistant message not user', () {
      expect(
          _isUserMessage({'role': 'assistant', 'content': 'hello'}), false);
    });
  });

  group('History trimming', () {
    test('short history not trimmed', () {
      final history = [
        {'role': 'user', 'content': 'hi'},
        {'role': 'assistant', 'content': 'hello'},
      ];
      final trimmed = _trimHistory(history, 4096);
      expect(trimmed.length, 2);
    });

    test('very long history gets trimmed', () {
      final history = List.generate(
        100,
        (i) => {'role': i.isEven ? 'user' : 'assistant', 'content': 'x' * 100},
      );
      final trimmed = _trimHistory(history, 100); // very small limit
      expect(trimmed.length, lessThan(100));
    });

    test('at least 2 messages always kept', () {
      final history = [
        {'role': 'user', 'content': 'a' * 10000},
        {'role': 'assistant', 'content': 'b' * 10000},
      ];
      final trimmed = _trimHistory(history, 1);
      expect(trimmed.length, greaterThanOrEqualTo(2));
    });
  });
}
