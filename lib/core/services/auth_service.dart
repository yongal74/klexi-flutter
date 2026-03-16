import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

// NOTE: Firebase Auth is wired up but initializeApp() is commented in main.dart
// until google-services.json is added. For now we use google_sign_in directly.
// Once Firebase is configured, uncomment the firebase_auth import + usage below.

// import 'package:firebase_auth/firebase_auth.dart';

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
  KlexiUser? _currentUser;
  KlexiUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null && !_currentUser!.isGuest;

  /// Google Sign-In — the PRIMARY auth method for Klexi.
  /// Returns KlexiUser on success, null if user cancelled.
  Future<KlexiUser?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null; // user cancelled

      _currentUser = KlexiUser(
        id: account.id,
        displayName: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
        isGuest: false,
      );
      return _currentUser;
    } catch (e) {
      throw AuthException('google_sign_in_failed', e.toString());
    }
  }

  /// Guest mode — limited features, no sync across devices.
  Future<KlexiUser> signInAsGuest() async {
    _currentUser = KlexiUser(id: 'guest_${DateTime.now().millisecondsSinceEpoch}', isGuest: true);
    return _currentUser!;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Call after Firebase is set up to link guest progress to Google account.
  Future<KlexiUser?> upgradeGuestWithGoogle() async {
    final user = await signInWithGoogle();
    // TODO: migrate Hive data from guest ID to Google ID
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
final currentUserProvider  = StateProvider<KlexiUser?>((ref) => null);
final isSignedInProvider   = Provider<bool>((ref) => ref.watch(currentUserProvider) != null && !(ref.watch(currentUserProvider)?.isGuest ?? true));
