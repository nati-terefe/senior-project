import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // ---- tiny helper: schedule navigation next frame to avoid white screens
  void _safeGo(BuildContext context, String location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(location);
    });
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _displayName(User? u) {
    final dn = (u?.displayName ?? '').trim();
    if (dn.isNotEmpty) return dn;
    final email = (u?.email ?? '').trim();
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }
    return '';
  }

  // --- Responsive helpers
  int _cols(double w) {
    if (w <= 480) return 2;
    if (w <= 900) return 3;
    if (w <= 1200) return 3;
    return 4;
  }

  double _ratio(double w) {
    if (w <= 480) return 0.82;
    if (w <= 900) return 1.05;
    if (w <= 1200) return 1.15;
    return 1.25;
  }

  // ---- Gate for protected features (Instant Translate, Lessons, Quiz)
  Future<void> _goOrPrompt(BuildContext context, String route) async {
    // Normalize alias
    final normalized = (route == '/translate') ? '/instant_translate' : route;

    // Which routes require login?
    final bool needsAuth = normalized == '/instant_translate' ||
        normalized.startsWith('/lessons') ||
        normalized.startsWith('/quiz');

    if (needsAuth) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Friendly feature name for dialog
        String featureName = 'this feature';
        if (normalized == '/instant_translate') {
          featureName = 'Instant Translate';
        } else if (normalized.startsWith('/lessons')) {
          featureName = 'Lessons';
        } else if (normalized.startsWith('/quiz')) {
          featureName = 'Quiz';
        }

        final wantsLogin = await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Sign in required'),
            content: Text('You need to be signed in to use $featureName.'),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(_, rootNavigator: true).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(_, rootNavigator: true).pop(true),
                child: const Text('Login'),
              ),
            ],
          ),
        );

        if (wantsLogin == true) {
          _safeGo(context, '/auth');
        } else {
          // Stay on dashboard
          _safeGo(context, '/');
        }
        return;
      }
    }

    // Signed in or not protected → go
    _safeGo(context, normalized);
  }

  bool _isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 640;

  // Map current location to bottom-bar index
  int _indexForRoute(String loc) {
    if (loc.startsWith('/about')) return 0;
    if (loc.startsWith('/faq')) return 1;
    if (loc.startsWith('/contact')) return 2;
    return 0; // default index
  }

  @override
  Widget build(BuildContext context) {
    // Define individual features so we can arrange them precisely
    final fInstant = _Feature(
      'Instant translate',
      'Camera → English',

      //'Camera → አማርኛ',
      Icons.camera_alt,
      '/translate', // handler normalizes to /instant_translate
    );
    final fVocab =
        _Feature('Vocabulary', 'Sign atlas', Icons.grid_view, '/vocab');
    final fLessons =
        _Feature('Lessons', 'Divided by Units', Icons.menu_book, '/lessons');
    final fQuiz = _Feature('Quiz', 'Practice recognition', Icons.quiz, '/quiz');

    final fAbout =
        _Feature('About', 'How STS works', Icons.info_outline, '/about');
    final fFaq =
        _Feature('FAQ', 'Common questions', Icons.help_outline, '/faq');
    final fContact =
        _Feature('Contact', 'Get in touch', Icons.mail_outline, '/contact');

    // ---- Figure out the *actual* route for highlight handling
    final location =
        GoRouter.of(context).routerDelegate.currentConfiguration.fullPath ??
            '/';
    final bool neutralOnDashboard = location == '/' || location == '/home';

    final isMobile = _isMobile(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cols = _cols(w);
              final ratio = _ratio(w);

              return CustomScrollView(
                slivers: [
                  // --- Greeting
                  SliverToBoxAdapter(
                    child: StreamBuilder<User?>(
                      stream: FirebaseAuth.instance.authStateChanges(),
                      builder: (context, snap) {
                        final greet = _greeting(DateTime.now());
                        final name = _displayName(snap.data);
                        return Text(
                          name.isEmpty ? greet : '$greet, $name',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium!
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // --- Row of small feature tiles at the top
                  // Web/Desktop: 3 (Instant, Vocab, Lessons)
                  // Mobile: 2 (Instant, Vocab)
                  SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: _FeatureTile(
                            feature: fInstant,
                            onTap: () => _goOrPrompt(context, fInstant.route),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FeatureTile(
                            feature: fVocab,
                            onTap: () => _goOrPrompt(context, fVocab.route),
                          ),
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeatureTile(
                              feature: fLessons,
                              onTap: () => _goOrPrompt(context, fLessons.route),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // --- Big rectangle tile for QUIZ with image
                  SliverToBoxAdapter(
                    child: _QuizRectangleTile(
                      onTap: () => _goOrPrompt(context, fQuiz.route),
                      assetPath: 'assets/images/quiz_banner.jpg', // <- use .jpg
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // --- Remaining tiles continue "as they are"
                  // Mobile: Lessons + About + FAQ + Contact (2-column grid)
                  // Web: About + FAQ + Contact (adaptive grid)
                  SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final remaining = isMobile
                            ? <_Feature>[fLessons, fAbout, fFaq, fContact]
                            : <_Feature>[fAbout, fFaq, fContact];
                        final feat = remaining[i];
                        return _FeatureTile(
                          feature: feat,
                          onTap: () => _goOrPrompt(context, feat.route),
                        );
                      },
                      childCount:
                          isMobile ? 4 : 3, // matches lists above (mobile/web)
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 2 : cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: ratio,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
        ),
      ),

      // ---- MOBILE-ONLY bottom bar with the new pages
      bottomNavigationBar: _isMobile(context)
          ? NavigationBarTheme(
              data: NavigationBarThemeData(
                // When on Dashboard, make the bar look "neutral" (no visible selection).
                // On About/FAQ/Contact routes, use default highlight (visual selection).
                indicatorColor: neutralOnDashboard ? Colors.transparent : null,
                iconTheme: MaterialStateProperty.resolveWith((states) {
                  if (neutralOnDashboard) {
                    return IconThemeData(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    );
                  }
                  return const IconThemeData(); // default highlight colors
                }),
                labelTextStyle: MaterialStateProperty.resolveWith((states) {
                  if (neutralOnDashboard) {
                    return Theme.of(context).textTheme.labelMedium!;
                  }
                  return const TextStyle(); // default (will color selected)
                }),
              ),
              child: NavigationBar(
                selectedIndex: _indexForRoute(location),
                onDestinationSelected: (i) {
                  if (i == 0) {
                    _safeGo(context, '/about');
                  } else if (i == 1) {
                    _safeGo(context, '/faq');
                  } else {
                    _safeGo(context, '/contact');
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.info_outline),
                    label: 'About',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.help_outline),
                    label: 'FAQ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.mail_outline),
                    label: 'Contact',
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _Feature {
  final String title, subtitle, route;
  final IconData icon;
  _Feature(this.title, this.subtitle, this.icon, this.route);
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.feature,
    required this.onTap,
    super.key,
  });

  final _Feature feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        color: cs.surfaceVariant.withOpacity(.6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final iconSize = w < 170 ? 22.0 : (w < 220 ? 26.0 : 28.0);
              final titleSize = w < 170 ? 15.5 : (w < 220 ? 16.5 : 18.0);
              final subSize = w < 170 ? 12.0 : 13.5;

              return Column(
                mainAxisSize: MainAxisSize.min, // <-- important
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        Icon(feature.icon, size: iconSize, color: cs.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    feature.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: titleSize,
                      color: cs.onSurface,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Use loose Flexible instead of Expanded in unbounded height
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      feature.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: subSize,
                        color: cs.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Big rectangular promo-style tile for Quiz with an image background.
class _QuizRectangleTile extends StatelessWidget {
  const _QuizRectangleTile({
    required this.onTap,
    required this.assetPath,
  });

  final VoidCallback onTap;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 15 / 5, // nice wide rectangle for quiz
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image (bundled asset)
              // If asset missing, fall back to tinted surface.
              Container(color: cs.surfaceVariant.withOpacity(.5)),
              Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),

              // Subtle gradient for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(.45),
                      Colors.black.withOpacity(.05),
                    ],
                  ),
                ),
              ),

              // Text + icon overlay
              Padding(
                padding: const EdgeInsets.all(20),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(.9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.quiz, color: cs.onPrimary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quiz',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Practice recognition',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                  color: Colors.white.withOpacity(.95),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
