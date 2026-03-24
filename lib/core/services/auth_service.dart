import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KlexiUser {
  final String id;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool isGuest;
  const KlexiUser({required this.id, this.displayName, this.email, this.photoUrl, this.isGuest = false});
}

class AuthService {
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final _firebaseAuth = FirebaseAuth.instance;

  KlexiUser? _currentUser;
  KlexiUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null && !_currentUser!.isGuest;

  static const String _userIdKey = 'klexi_user_id';

  /// Firebase가 이미 로그인된 상태면 복원
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

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
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
      return _currentUser;
    } catch (e) {
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

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    _currentUser = null;
  }

  /// 게스트 → Google 계정 업그레이드 (학습 데이터 마이그레이션)
  Future<KlexiUser?> upgradeGuestWithGoogle() async {
    final guestUser = _currentUser;
    final user = await signInWithGoogle();
    if (user == null) return null;

    if (guestUser != null && guestUser.isGuest) {
      await _migrateHiveData(fromId: guestUser.id, toId: user.id);
    }
    return user;
  }

  Future<void> _migrateHiveData({required String fromId, required String toId}) async {
    try {
      const boxName = 'study_records';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, toId);
      debugPrint('[Auth] Migrated study data from $fromId → $toId');

      final oldBoxName = '${boxName}_$fromId';
      if (Hive.isBoxOpen(oldBoxName) || await Hive.boxExists(oldBoxName)) {
        final oldBox = await Hive.openBox<Map>(oldBoxName);
        final newBox = await Hive.openBox<Map>('${boxName}_$toId');
        for (final key in oldBox.keys) {
          final val = oldBox.get(key);
          if (val != null) await newBox.put(key, val);
        }
        await oldBox.deleteFromDisk();
        debugPrint('[Auth] Hive box migration complete: $oldBoxName → ${boxName}_$toId');
      }
    } catch (e) {
      debugPrint('[Auth] Migration warning: $e');
    }
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
final currentUserProvider  = StateProvider<KlexiUser?>((ref) => null);
final isSignedInProvider   = Provider<bool>((ref) =>
    ref.watch(currentUserProvider) != null &&
    !(ref.watch(currentUserProvider)?.isGuest ?? true));
