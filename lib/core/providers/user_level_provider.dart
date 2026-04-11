import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final userTopikLevelProvider =
    StateNotifierProvider<UserLevelNotifier, int>((ref) => UserLevelNotifier());

class UserLevelNotifier extends StateNotifier<int> {
  static const _key = 'userTopikLevel';
  UserLevelNotifier() : super(1) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) state = prefs.getInt(_key) ?? 1;
  }

  Future<void> setLevel(int level) async {
    if (mounted) state = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, level);
  }
}
