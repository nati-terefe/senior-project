import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
    if (w <= 480) return 2; // phones
    if (w <= 900) return 3; // large phones / small tablets
    if (w <= 1200) return 3; // tablets / small desktop
    return 4; // wide desktop
  }

  double _ratio(double w) {
    if (w <= 480) return 0.82; // taller tiles on small phones
    if (w <= 900) return 1.05;
    if (w <= 1200) return 1.15;
    return 1.25;
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <_Feature>[
      _Feature(
          'Instant translate', 'Camera → አማርኛ', Icons.camera_alt, '/translate'),
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
                // Greeting with live user name
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

                // Responsive grid
                SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _FeatureTile(feature: tiles[i]),
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
  const _FeatureTile({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => context.go(feature.route),
      borderRadius: BorderRadius.circular(18),
      child: Card(
        color: cs.surfaceVariant.withOpacity(.6), // your preferred light look
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: LayoutBuilder(
            builder: (context, c) {
              // Scale internals based on available tile width
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
