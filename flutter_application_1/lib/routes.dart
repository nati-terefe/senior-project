// routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import './app_shell.dart';
import './dashboard.dart';
import './instant_translate.dart';
import './vocabulary.dart';
import './lessons.dart';
import './quiz.dart';
import './dataset.dart';
import './settings.dart';
import './admin.dart';
import './auth.dart';
import './about_us.dart';
import './faq_page.dart';
import './contact_us.dart';

/// ---------------- RequireAuth gate ----------------
class RequireAuth extends StatefulWidget {
  const RequireAuth({
    super.key,
    required this.child,
    this.dialogTitle = 'Sign in required',
    this.dialogMessage = 'You need to be signed in to use Instant Translate.',
  });

  final Widget child;
  final String dialogTitle;
  final String dialogMessage;

  @override
  State<RequireAuth> createState() => _RequireAuthState();
}

class _RequireAuthState extends State<RequireAuth> {
  bool _checked = false;
  bool _allowed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeAsk();
  }

  Future<void> _maybeAsk() async {
    if (_checked) return;
    _checked = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (!mounted) return;
      setState(() => _allowed = true);
      return;
    }

    // Use ROOT navigator and pop with the dialog's own context.
    final wantsLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text(widget.dialogTitle),
        content: Text(widget.dialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Login'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (wantsLogin == true) {
      // Defer navigation to next frame to avoid lifecycle asserts/white flashes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/auth');
      });
    } else {
      // Cancel → leave/return home
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _allowed
        ? widget.child
        : const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// ---------------- Router ----------------
final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    // Standalone (outside shell)
    GoRoute(path: '/auth', builder: (_, __) => const LoginSignup()),
    GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),

    // App shell (sidebar/topbar etc.)
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),

        // Protected: Instant Translate
        GoRoute(
          path: '/instant_translate',
          builder: (_, __) => const RequireAuth(
            child: InstantTranslateScreen(),
          ),
        ),

        // Back-compat alias: /translate → /instant_translate
        GoRoute(
          path: '/translate',
          redirect: (_, __) => '/instant_translate',
        ),

        GoRoute(path: '/vocab', builder: (_, __) => const VocabularyScreen()),

        // --- Protected: Lessons (list / unit / unit+lesson) ---
        GoRoute(
          path: '/lessons',
          builder: (_, __) => const RequireAuth(
            dialogMessage: 'You need to be signed in to use Lessons.',
            child: LessonsScreen(),
          ),
        ),
        GoRoute(
          path: '/lessons/:unitId',
          builder: (_, state) => RequireAuth(
            dialogMessage: 'You need to be signed in to use Lessons.',
            child: LessonsScreen(unitId: state.pathParameters['unitId']!),
          ),
        ),
        GoRoute(
          path: '/lessons/:unitId/:lessonId',
          builder: (_, state) => RequireAuth(
            dialogMessage: 'You need to be signed in to use Lessons.',
            child: LessonsScreen(
              unitId: state.pathParameters['unitId']!,
              lessonId: state.pathParameters['lessonId']!,
            ),
          ),
        ),

        // --- Protected: Quiz ---
        GoRoute(
          path: '/quiz',
          builder: (_, __) => const RequireAuth(
            dialogMessage: 'You need to be signed in to use Quiz.',
            child: QuizScreen(),
          ),
        ),

        GoRoute(path: '/dataset', builder: (_, __) => const DatasetScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/about', builder: (_, __) => const AboutUsPage()),
        GoRoute(path: '/faq', builder: (_, __) => const FaqPage()),
        GoRoute(path: '/contact', builder: (_, __) => const ContactUsPage()),
      ],
    ),
  ],
);
