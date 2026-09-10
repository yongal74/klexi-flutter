// lib/core/providers/tts_speed_provider.dart
// 설정 화면의 "Slow TTS Speed" 스위치를 실제 발음 속도에 연결한다.
// build52 까지 이 스위치는 화면 로컬 state 라 앱을 나가면 사라지고
// 발음에도 아무 영향이 없었다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SlowTtsNotifier extends StateNotifier<bool> {
  SlowTtsNotifier() : super(false) {
    _load();
  }

  static const String prefsKey = 'tts_slow_speed';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(prefsKey) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
  }
}

final slowTtsProvider =
    StateNotifierProvider<SlowTtsNotifier, bool>((ref) => SlowTtsNotifier());
