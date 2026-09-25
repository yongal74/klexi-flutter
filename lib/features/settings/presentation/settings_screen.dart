// lib/features/settings/presentation/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/tts_speed_provider.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/daily_session_service.dart';
import '../../../core/services/purchase_service.dart';
import '../../chat/presentation/dalli_chat_screen.dart'
    show chatMessagesProvider;
import '../../learn/presentation/quiz_screen.dart' show quizWrongWordsProvider;
import '../../progress/presentation/progress_screen.dart'
    show progressDataProvider;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F8),
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Profile ────────────────────────────────────────
            _ProfileCard(),

            const SizedBox(height: 20),

            // ── General ───────────────────────────────────────
            _SectionHeader(title: 'General'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SwitchTile(
                  icon: Icons.speed_rounded,
                  iconBg: const Color(0xFFEEF1FF),
                  iconColor: const Color(0xFF667EEA),
                  title: 'Slow TTS Speed',
                  subtitle: 'Speak more slowly for easier listening',
                  value: ref.watch(slowTtsProvider),
                  onChanged: (v) => ref.read(slowTtsProvider.notifier).set(v),
                ),
                // "Daily Reminders" 스위치는 제거했다 — 로컬 state 만 바꾸고
                // 실제 예약과 무관했다. 아래 Notifications 항목이 진짜 설정이다.
              ],
            ),

            const SizedBox(height: 20),

            // ── Premium ───────────────────────────────────────
            _SectionHeader(title: 'Premium'),
            const SizedBox(height: 10),
            _PremiumCard(),

            const SizedBox(height: 20),

            // ── About ─────────────────────────────────────────
            _SectionHeader(title: 'About'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _TapTile(
                  icon: Icons.info_outline_rounded,
                  iconBg: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF4ADE80),
                  title: 'App Version',
                  trailing: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (_, snap) => Text(
                      snap.hasData
                          ? '${snap.data!.version} (${snap.data!.buildNumber})'
                          : '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  onTap: () {},
                ),
                _Divider(),
                _TapTile(
                  icon: Icons.policy_outlined,
                  iconBg: const Color(0xFFF0F4FF),
                  iconColor: const Color(0xFF818CF8),
                  title: 'Privacy Policy',
                  onTap: () => _openUrl('${AppConfig.backendUrl}/privacy'),
                ),
                _Divider(),
                _TapTile(
                  icon: Icons.description_outlined,
                  iconBg: const Color(0xFFF0F4FF),
                  iconColor: const Color(0xFF818CF8),
                  title: 'Terms of Use',
                  onTap: () => _openUrl('${AppConfig.backendUrl}/terms'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Notification settings ───────────────────────
            _SectionHeader(title: 'Notifications'),
            const SizedBox(height: 10),
            _SettingsCard(children: [
              _TapTile(
                icon: Icons.notifications_active_rounded,
                iconBg: const Color(0xFFFFF4E6),
                iconColor: const Color(0xFFFF8C42),
                title: 'Daily Reminder Settings',
                onTap: () => context.push(AppRoutes.notifSettings),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Learning ──────────────────────────────────────
            _SectionHeader(title: 'Learning'),
            const SizedBox(height: 10),
            _SettingsCard(children: [
              _TapTile(
                icon: Icons.refresh_rounded,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                title: 'Reset All Progress',
                onTap: _resetSession,
              ),
            ]),

            const SizedBox(height: 20),

            // ── Sign out ───────────────────────────────────────
            _SectionHeader(title: 'Account'),
            const SizedBox(height: 10),
            _SettingsCard(children: [
              _TapTile(
                icon: Icons.logout_rounded,
                iconBg: const Color(0xFFFFF0F0),
                iconColor: const Color(0xFFEF4444),
                title: 'Sign Out',
                onTap: _signOut,
              ),
              _Divider(),
              _TapTile(
                icon: Icons.delete_forever_rounded,
                iconBg: const Color(0xFFFFF0F0),
                iconColor: const Color(0xFFEF4444),
                title: 'Delete Account',
                onTap: _deleteAccount,
              ),
            ]),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _resetSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text(
            'This permanently erases every word you have studied, your streak, '
            'and your review schedule. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Erase everything',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(dailySessionServiceProvider).resetSession();
      _clearSessionState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Progress reset. You will start with new words.')));
      }
    }
  }

  /// 세션·퀴즈처럼 이 사용자의 학습에 묶인 메모리 상태를 비운다.
  void _clearSessionState() {
    ref.read(todayStudiedCountProvider.notifier).state = 0;
    ref.read(lastSessionWordsProvider.notifier).state = [];
    ref.read(quizWrongWordsProvider.notifier).state = [];
    ref.invalidate(progressDataProvider);
  }

  /// 로그아웃·계정삭제 후 이전 사용자의 흔적(채팅 화면 내용 포함)이 다음
  /// 사용자에게 보이지 않도록 초기화한다.
  void _clearUserState() {
    _clearSessionState();
    ref.invalidate(chatMessagesProvider);
  }

  Future<void> _signOut() async {
    final isGuest = ref.read(currentUserProvider)?.isGuest ?? false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: Text(isGuest
            ? 'You are using Klexi as a guest. Your progress stays on this phone — '
                'choose "Continue as Guest" next time to get it back. '
                'To keep it safe across phones, sign in with Google instead.'
            : 'Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign Out',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(authServiceProvider).signOut();
      _clearUserState();
      ref.read(currentUserProvider.notifier).state = null;
      if (mounted) context.go(AppRoutes.auth);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.isGuest) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sign in required'),
          content: const Text(
              'Sign in with Google to delete your account. Guest data is stored only '
              'on this device and is removed automatically when you uninstall the app.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'This permanently deletes your account and study history. '
            'This cannot be undone. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await ref.read(authServiceProvider).deleteAccount();
      _clearUserState();
      ref.read(currentUserProvider.notifier).state = null;
      if (mounted) context.go(AppRoutes.auth);
    } on Exception catch (e) {
      debugPrint('[Settings] delete account failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Your account wasn't deleted. Please sign in again when asked and retry.")));
      }
    }
  }
}

// ── Profile Card ───────────────────────────────────────────────

class _ProfileCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  bool _upgrading = false;

  /// 게스트 → Google 업그레이드. 학습기록은 AuthService 가 새 uid 박스로 옮긴다.
  Future<void> _upgradeToGoogle() async {
    setState(() => _upgrading = true);
    try {
      final user = await ref.read(authServiceProvider).upgradeGuestWithGoogle();
      if (user != null && mounted) {
        ref.read(currentUserProvider.notifier).state = user;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Signed in. Your progress is now backed up.')));
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign-in failed: ${e.message}')));
      }
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'Guest';
    final email = user?.email ?? '';
    final photoUrl = user?.photoUrl;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G';

    final row = Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: photoUrl != null
              ? Image.network(photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                      child: Text(initial,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white))))
              : Center(
                  child: Text(initial,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (user?.isGuest != true) return _card(row);

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row,
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: _upgrading ? null : _upgradeToGoogle,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF5A3E8C),
                disabledBackgroundColor: Colors.white70,
              ),
              icon: _upgrading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(_upgrading
                  ? 'Signing in\u2026'
                  : 'Sign in with Google to back up progress'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}

// ── Premium Banner ─────────────────────────────────────────────

class _PremiumCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    return GestureDetector(
      // 프리미엄 사용자는 결제 화면 대신 구독 관리(복원)로 보낸다 — 같은 화면이 둘 다 제공
      onTap: () => context.push(AppRoutes.premium),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFF8C42).withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('⭐', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPremium ? 'Premium is active' : 'Upgrade to Premium',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPremium
                        ? 'Thanks for supporting Klexi — all features unlocked'
                        : 'Unlock all 7,200 words & advanced features',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (!isPremium)
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFFFF8C42),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF667EEA),
          ),
        ],
      ),
    );
  }
}

class _TapTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _TapTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            trailing ??
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 70),
      child: Divider(height: 1, color: Color(0xFFF0F0F5)),
    );
  }
}
