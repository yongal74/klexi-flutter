// lib/core/widgets/google_sign_in_prompt.dart
// 게스트에게 구글 로그인을 요청하는 공용 다이얼로그.
//
// AI 기능(채팅·AI 음성·발음 채점)은 서버가 Firebase 로그인 토큰을 요구하므로
// 게스트는 쓸 수 없다. 게스트가 먼저 결제하면 돈을 내고도 AI 기능이 막히므로,
// 결제 전과 AI 화면 진입 시 로그인을 받는다. 게스트 학습기록은 그대로 이관된다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// 이미 구글 로그인 상태면 즉시 true. 게스트면 다이얼로그로 로그인을 받고
/// 성공 시 true, 취소·실패 시 false.
Future<bool> ensureGoogleSignIn(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  if (ref.read(isSignedInProvider)) return true;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign in with Google'),
      content: Text('$reason\n\nYour current study progress will be kept.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue with Google')),
      ],
    ),
  );
  if (go != true || !context.mounted) return false;

  try {
    final user = await ref.read(authServiceProvider).upgradeGuestWithGoogle();
    if (user == null) return false;
    ref.read(currentUserProvider.notifier).state = user;
    return true;
  } on AuthException catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Google sign-in didn't complete. Please try again.")));
    }
    return false;
  }
}
