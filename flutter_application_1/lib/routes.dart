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

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
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
