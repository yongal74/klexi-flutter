import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _loading = false;

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithGoogle();
      if (user != null && mounted) {
        ref.read(currentUserProvider.notifier).state = user;
        context.go('/home');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guestSignIn() async {
    setState(() => _loading = true);
    try {
      final user = await ref.read(authServiceProvider).signInAsGuest();
      if (mounted) {
        ref.read(currentUserProvider.notifier).state = user;
        context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Gradient background
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        )),
        SafeArea(child: Column(children: [
          // Hero section
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 88, height: 88,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5)),
                child: const Center(child: Text('K', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)))),
              const SizedBox(height: 20),
              const Text('Klexi', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text('Learn Korean through sentences', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.85))),
              const SizedBox(height: 48),
              _bullet('📚', '7,200 TOPIK words across 6 levels'),
              const SizedBox(height: 16),
              _bullet('🗣️', 'AI conversation with Dalli'),
              const SizedBox(height: 16),
              _bullet('🕸️', 'Visual Word Network'),
            ]),
          )),
          // Bottom card
          Container(
            decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 28),
                decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
              // Google Sign-In button
              SizedBox(width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _googleSignIn,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF3C4043),
                    elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFDDDDDD)))),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _googleIcon(),
                        const SizedBox(width: 12),
                        const Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ]),
                )),
              const SizedBox(height: 12),
              TextButton(onPressed: _loading ? null : _guestSignIn,
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: Colors.grey),
                child: const Text('Continue as Guest', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
              const SizedBox(height: 8),
              Text('By continuing, you agree to our Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ]),
          ),
        ])),
      ]),
    );
  }

  Widget _bullet(String emoji, String text) => Row(children: [
    Container(width: 44, height: 44,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
    const SizedBox(width: 16),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500))),
  ]);

  Widget _googleIcon() => SizedBox(width: 22, height: 22, child: Stack(children: [
    Positioned(left: 0, top: 0, child: Container(width: 10, height: 10,
      decoration: const BoxDecoration(color: Color(0xFFEA4335), borderRadius: BorderRadius.only(topLeft: Radius.circular(10))))),
    Positioned(right: 0, top: 0, child: Container(width: 10, height: 10,
      decoration: const BoxDecoration(color: Color(0xFF4285F4), borderRadius: BorderRadius.only(topRight: Radius.circular(10))))),
    Positioned(left: 0, bottom: 0, child: Container(width: 10, height: 10,
      decoration: const BoxDecoration(color: Color(0xFFFBBC05), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10))))),
    Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10,
      decoration: const BoxDecoration(color: Color(0xFF34A853), borderRadius: BorderRadius.only(bottomRight: Radius.circular(10))))),
    Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
  ]));
}
