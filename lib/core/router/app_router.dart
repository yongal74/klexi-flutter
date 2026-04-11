import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/main_scaffold.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/learn/presentation/learn_screen.dart';
import '../../features/learn/presentation/daily_session_screen.dart';
import '../../features/learn/presentation/sentence_card_screen.dart';
import '../../features/learn/presentation/sentence_practice_screen.dart';
import '../../features/learn/presentation/quiz_screen.dart';
import '../../features/learn/presentation/review_screen.dart';
import '../../features/learn/presentation/cloze_quiz_screen.dart';
import '../../features/learn/presentation/word_card_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/notification_settings_screen.dart';
import '../../features/word_network/presentation/word_network_screen.dart';
import '../../features/chat/presentation/dalli_chat_screen.dart';
import '../../features/grammar/presentation/grammar_screen.dart';
import '../../features/grammar/presentation/grammar_detail_screen.dart';
import '../../features/themes/presentation/themes_screen.dart';
import '../../features/themes/presentation/theme_detail_screen.dart';
import '../../features/pronunciation/presentation/pronunciation_screen.dart';
import '../../features/hangeul/presentation/hangeul_tracing_screen.dart';
import '../../features/learn/presentation/level_words_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../widgets/paywall_gate.dart';

abstract class AppRoutes {
  static const String auth              = '/auth';
  static const String home              = '/home';
  static const String learn             = '/learn';
  static const String progress          = '/progress';
  static const String settings          = '/settings';
  static const String dailySession      = '/daily-session';
  static const String sentenceCard      = '/sentence-card';
  static const String clozeQuiz        = '/cloze-quiz';
  static const String wordCard          = '/word-card';
  static const String wordNetwork       = '/word-network';
  static const String dalliChat         = '/dalli-chat';
  static const String grammar           = '/grammar';
  static const String grammarDetail     = '/grammar/:id';
  static const String themes            = '/themes';
  static const String themeDetail       = '/themes/:id';
  static const String pronunciation     = '/pronunciation';
  static const String hangeul           = '/hangeul';
  static const String notifSettings     = '/notification-settings';
  static const String levelWords        = '/level/:level';
  static const String premium           = '/premium';
  static const String sentencePractice  = '/sentence-practice';
  static const String quizSession       = '/quiz-session';
  static const String reviewSession     = '/review';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: AppRoutes.auth,
    redirect: (context, state) {
      final isAuthed = authState != null;
      final onAuth = state.matchedLocation == AppRoutes.auth;
      if (!isAuthed && !onAuth) return AppRoutes.auth;
      if (isAuthed && onAuth) return AppRoutes.home;
      return null;
    },
    routes: [
      // ── Auth (fullscreen) ──────────────────────────────
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),

      // ── Main Shell (4 tabs) ───────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.learn,
              builder: (context, state) => const LearnScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.progress,
              builder: (context, state) => const ProgressScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),

      // ── Stack screens ─────────────────────────────────
      GoRoute(
        path: AppRoutes.dailySession,
        pageBuilder: (c, s) => _slide(const DailySessionScreen()),
      ),
      GoRoute(
        path: AppRoutes.sentenceCard,
        pageBuilder: (c, s) {
          final lvl = int.tryParse(s.uri.queryParameters['level'] ?? '');
          final wordId = s.uri.queryParameters['wordId'];
          final startIndex = int.tryParse(s.uri.queryParameters['startIndex'] ?? '') ?? 0;
          return _slide(SentenceCardScreen(level: lvl, wordId: wordId, startIndex: startIndex));
        },
      ),
      GoRoute(
        path: AppRoutes.levelWords,
        pageBuilder: (c, s) {
          final level = int.tryParse(s.pathParameters['level'] ?? '1') ?? 1;
          return _slide(LevelWordsScreen(level: level));
        },
      ),
      GoRoute(
        path: AppRoutes.clozeQuiz,
        pageBuilder: (c, s) => _slide(const ClozeQuizScreen()),
      ),
      GoRoute(
        path: AppRoutes.wordCard,
        pageBuilder: (c, s) {
          final wordId = s.uri.queryParameters['id'] ?? '';
          return _slide(WordCardScreen(wordId: wordId));
        },
      ),
      GoRoute(
        path: AppRoutes.wordNetwork,
        pageBuilder: (c, s) => _slide(const WordNetworkScreen()),
      ),
      GoRoute(
        path: AppRoutes.dalliChat,
        pageBuilder: (c, s) => _slide(const PaywallGate(
          featureName: 'Dalli AI Chat',
          featureDescription:
              'Unlimited Korean conversation practice with Dalli, your AI tutor. '
              'Upgrade to Klexi Pro for unlimited Dalli sessions.',
          child: DalliChatScreen(),
        )),
      ),
      GoRoute(
        path: AppRoutes.grammar,
        pageBuilder: (c, s) => _slide(const PaywallGate(
          featureName: 'Grammar Coach',
          featureDescription:
              'Master all Korean grammar patterns across TOPIK levels 1–6. '
              'Upgrade to Klexi Pro for full grammar access.',
          child: GrammarScreen(),
        )),
      ),
      GoRoute(
        path: AppRoutes.grammarDetail,
        pageBuilder: (c, s) {
          final id = s.pathParameters['id'] ?? '';
          return _slide(PaywallGate(
            featureName: 'Grammar Detail',
            child: GrammarDetailScreen(patternId: id),
          ));
        },
      ),
      GoRoute(
        path: AppRoutes.themes,
        pageBuilder: (c, s) => _slide(const PaywallGate(
          featureName: 'Theme Packs',
          featureDescription:
              'Access K-Drama, K-Pop, K-Food, Travel, Slang, and Manners '
              'vocabulary packs. Upgrade to Klexi Pro to unlock all themes.',
          child: ThemesScreen(),
        )),
      ),
      GoRoute(
        path: AppRoutes.themeDetail,
        pageBuilder: (c, s) {
          final id = s.pathParameters['id'] ?? '';
          return _slide(PaywallGate(
            featureName: 'Theme Pack',
            child: ThemeDetailScreen(themeId: id),
          ));
        },
      ),
      GoRoute(
        path: AppRoutes.pronunciation,
        pageBuilder: (c, s) => _slide(const PaywallGate(
          featureName: 'Pronunciation Coach',
          featureDescription:
              'AI-powered pronunciation scoring and feedback. '
              'Upgrade to Klexi Pro for unlimited pronunciation sessions.',
          child: PronunciationScreen(),
        )),
      ),
      GoRoute(
        path: AppRoutes.hangeul,
        pageBuilder: (c, s) => _slide(const HangeulTracingScreen()),
      ),
      GoRoute(
        path: AppRoutes.notifSettings,
        pageBuilder: (c, s) => _slide(const NotificationSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.sentencePractice,
        pageBuilder: (c, s) => _slide(const SentencePracticeScreen()),
      ),
      GoRoute(
        path: AppRoutes.quizSession,
        pageBuilder: (c, s) => _slide(const QuizScreen()),
      ),
      GoRoute(
        path: AppRoutes.reviewSession,
        pageBuilder: (c, s) => _slide(const ReviewScreen()),
      ),

      // ── Modal screens ─────────────────────────────────
      GoRoute(
        path: AppRoutes.premium,
        pageBuilder: (c, s) => _modal(const PremiumScreen()),
      ),
    ],
  );
});

CustomTransitionPage<void> _slide(Widget child) {
  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (context, animation, _, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

CustomTransitionPage<void> _modal(Widget child) {
  return CustomTransitionPage(
    child: child,
    fullscreenDialog: true,
    transitionsBuilder: (context, animation, _, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}
