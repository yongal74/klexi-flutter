// lib/core/providers/onboarding_provider.dart
// 첫 실행 안내(온보딩)를 이미 봤는지. main.dart 가 SharedPreferences 값으로 시드한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kOnboardingDoneKey = 'onboarding_done_v1';

final onboardingDoneProvider = StateProvider<bool>((ref) => true);

Future<void> markOnboardingDone(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kOnboardingDoneKey, true);
  ref.read(onboardingDoneProvider.notifier).state = true;
}
