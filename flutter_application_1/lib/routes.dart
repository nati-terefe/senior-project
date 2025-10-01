// routes.dart
import 'package:go_router/go_router.dart';

import './app_shell.dart';
import './dashboard.dart';
import './instant_translate.dart';
import './vocabulary.dart';
import './lessons.dart';
import './quiz.dart';
import './dataset.dart';
import './settings.dart';
import './admin.dart';

// 👇 import your auth UI (use the actual file where LoginSignup lives)
import './auth.dart'; // contains `LoginSignup`

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    // ------ Auth (no AppShell) ------
    GoRoute(
      path: '/auth',
      builder: (_, __) => const LoginSignup(), // ✅ Correct target
    ),

    // ------ Admin (no AppShell) ------
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminScreen(),
      // Optional: simple guard pattern (uncomment when you wire auth)
      // redirect: (context, state) {
      //   final user = FirebaseAuth.instance.currentUser;
      //   if (user == null) return '/auth';
      //   return null;
      // },
    ),

    // ------ Client app inside AppShell ------
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        GoRoute(
            path: '/translate',
            builder: (_, __) => const InstantTranslateScreen()),
        GoRoute(path: '/vocab', builder: (_, __) => const VocabularyScreen()),
        GoRoute(path: '/lessons', builder: (_, __) => const LessonsScreen()),
        GoRoute(path: '/quiz', builder: (_, __) => const QuizScreen()),
        GoRoute(path: '/dataset', builder: (_, __) => const DatasetScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
);
