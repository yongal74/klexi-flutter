import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_session_service.dart';
import 'purchase_service.dart';

class KlexiUser {
  final String id;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool isGuest;
  const KlexiUser(
      {required this.id,
      this.displayName,
      this.email,
      this.photoUrl,
      this.isGuest = false});
}

class AuthService {
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final _firebaseAuth = FirebaseAuth.instance;

  KlexiUser? _currentUser;
  KlexiUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null && !_currentUser!.isGuest;

  static const String _userIdKey = 'klexi_user_id';

  /// dalli_chat_screen.dart 의 _kChatHistoryKey 와 같은 값이어야 한다.
  static const String _chatHistoryKey = 'dalli_chat_history';

  /// 앱 시작 시 이전 세션을 복원한다. Firebase 로그인이 살아 있으면 그 계정을,
  /// 없으면 prefs 에 저장된 게스트 id 를 되살린다.
  /// build52 까지는 이 함수를 아무도 부르지 않아서 실행할 때마다 로그인 화면이 떴다.
  Future<KlexiUser?> restoreSession() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      _currentUser = KlexiUser(
        id: firebaseUser.uid,
        displayName: firebaseUser.displayName,
        email: firebaseUser.email,
        photoUrl: firebaseUser.photoURL,
        isGuest: false,
      );
      await PurchaseService.instance.logIn(firebaseUser.uid);
      return _currentUser;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_userIdKey);
    if (savedId != null && savedId.startsWith('guest_')) {
      _currentUser = KlexiUser(id: savedId, isGuest: true);
      return _currentUser;
    }
    return null;
  }

  /// Google Sign-In + Firebase Auth 연동
  Future<KlexiUser?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null; // 사용자 취소

      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      _currentUser = KlexiUser(
        id: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? account.displayName,
        email: firebaseUser.email ?? account.email,
        photoUrl: firebaseUser.photoURL ?? account.photoUrl,
        isGuest: false,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, firebaseUser.uid);
      await PurchaseService.instance.logIn(firebaseUser.uid);
      return _currentUser;
    } on AuthException {
      rethrow;
    } on Exception catch (e) {
      debugPrint('[Auth] signInWithGoogle error: $e');
      throw AuthException('google_sign_in_failed', e.toString());
    }
  }

  /// 게스트 모드 — 로컬 전용, 기기 간 동기화 없음
  Future<KlexiUser> signInAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_userIdKey);
    final guestId = (existing != null && existing.startsWith('guest_'))
        ? existing
        : 'guest_${DateTime.now().millisecondsSinceEpoch}';

    _currentUser = KlexiUser(id: guestId, isGuest: true);
    await prefs.setString(_userIdKey, guestId);
    return _currentUser!;
  }

  /// 로그아웃. 학습기록은 남기되(재로그인 시 복구), 이 기기에 남는 계정 흔적
  /// (RevenueCat 엔타이틀먼트·채팅 히스토리·저장된 user id)은 정리한다.
  Future<void> signOut() async {
    await PurchaseService.instance.logOut();
    await DailySessionService.instance.closeForSignOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_chatHistoryKey);

    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    _currentUser = null;
  }

  /// Permanently deletes the signed-in user's Firebase Auth account and every
  /// trace of them on this device. Required by Google Play's account-deletion
  /// policy.
  ///
  /// 순서 주의: 서버 계정 삭제를 **먼저** 시도한다. 재인증 창을 사용자가 닫으면
  /// 여기서 예외로 끝나는데, 로컬 정리를 먼저 했다면 그 시점에 학습기록만
  /// 날아가고 계정은 살아남는다. 로컬 정리는 서버 삭제가 확정된 뒤에만 한다.
  /// (로컬 정리가 부분 실패해도 남는 것은 고아 로컬 파일뿐이라 되돌릴 수 있다.)
  ///
  /// Throws [AuthException] if there is no signed-in (non-guest) user.
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthException(
          'not_signed_in', 'No signed-in Google account to delete');
    }
    final uid = user.uid;

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Firebase requires a fresh sign-in for security-sensitive operations.
        final account = await _googleSignIn.signIn();
        if (account == null) {
          throw AuthException(
              'reauth_cancelled', 'Re-authentication was cancelled');
        }
        final googleAuth = await account.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
        await user.delete();
      } else {
        rethrow;
      }
    }

    await _wipeLocalData(uid);
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// 기기에 남은 사용자 흔적을 전부 지운다. 각 단계는 독립적으로 실패를
  /// 삼킨다 — 계정은 이미 서버에서 지워졌으므로 하나가 실패해도 나머지는
  /// 반드시 시도해야 한다.
  Future<void> _wipeLocalData(String uid) async {
    await _step('RevenueCat 로그아웃', () => PurchaseService.instance.logOut());
    await _step('FCM 토큰 삭제', () => FirebaseMessaging.instance.deleteToken());
    await _step(
      '학습기록 삭제',
      () => DailySessionService.instance.deleteDataForUser(uid),
    );
    await _step('설정 초기화', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });
    await _step('임시 파일 삭제', _deleteTempFiles);
  }

  /// 발음 녹음 파일과 TTS 캐시는 앱 임시 디렉토리에 남는다.
  Future<void> _deleteTempFiles() async {
    final dir = await getTemporaryDirectory();
    final recording = File('${dir.path}/klexi_pronunciation.m4a');
    if (recording.existsSync()) {
      await recording.delete();
    }
    final ttsCache = Directory('${dir.path}/tts_cache');
    if (ttsCache.existsSync()) {
      await ttsCache.delete(recursive: true);
    }
  }

  Future<void> _step(String label, Future<void> Function() action) async {
    try {
      await action();
    } on Exception catch (e) {
      debugPrint('[Auth] 계정삭제 정리 실패($label): $e');
    }
  }

  /// 게스트 → Google 계정 업그레이드 (학습 데이터 마이그레이션).
  /// build52 까지는 호출하는 화면이 없어서 게스트가 로그인하면 기록이 끊겼다.
  Future<KlexiUser?> upgradeGuestWithGoogle() async {
    final guestUser = _currentUser;
    final user = await signInWithGoogle();
    if (user == null) return null;

    if (guestUser != null && guestUser.isGuest && guestUser.id != user.id) {
      await DailySessionService.instance
          .migrateUser(fromUid: guestUser.id, toUid: user.id);
    } else {
      await DailySessionService.instance.init(user.id);
    }
    return user;
  }
}

class AuthException implements Exception {
  final String code;
  final String message;
  const AuthException(this.code, this.message);
  @override
  String toString() => 'AuthException[$code]: $message';
}

// ── Riverpod ─────────────────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final currentUserProvider = StateProvider<KlexiUser?>((ref) => null);
final isSignedInProvider = Provider<bool>((ref) =>
    ref.watch(currentUserProvider) != null &&
    !(ref.watch(currentUserProvider)?.isGuest ?? true));
