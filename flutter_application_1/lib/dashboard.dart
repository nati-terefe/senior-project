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
        if (normalized == '/instant_translate')
          featureName = 'Instant Translate';
        else if (normalized.startsWith('/lessons'))
          featureName = 'Lessons';
        else if (normalized.startsWith('/quiz')) featureName = 'Quiz';

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

  @override
  Widget build(BuildContext context) {
    final tiles = <_Feature>[
      _Feature(
        'Instant translate',
        'Camera → አማርኛ',
        Icons.camera_alt,
        '/translate', // handler normalizes to /instant_translate
      ),
      _Feature('Vocabulary', 'Sign atlas + search', Icons.grid_view, '/vocab'),
      _Feature('Quiz', 'Practice recognition', Icons.quiz, '/quiz'),
      _Feature('Lessons', 'Units & progress', Icons.menu_book, '/lessons'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = _cols(w);
            final ratio = _ratio(w);

            return CustomScrollView(
              slivers: [
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
                SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _FeatureTile(
                      feature: tiles[i],
                      onTap: () => _goOrPrompt(context, tiles[i].route),
                    ),
                    childCount: tiles.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
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
                  Expanded(
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
