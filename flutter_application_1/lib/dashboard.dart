import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Feature(
          'Instant translate', 'Camera → አማርኛ', Icons.camera_alt, '/translate'),
      _Feature('Vocabulary', 'Sign atlas + search', Icons.grid_view, '/vocab'),
      // Phrasebook removed
      _Feature('Quiz', 'Practice recognition', Icons.quiz, '/quiz'),
      _Feature('Lessons', 'Units & progress', Icons.menu_book, '/lessons'),
      _Feature(
          'Dataset', 'Record & label signs', Icons.video_library, '/dataset'),
// for testing, i hv delted it
      _Feature('Admin', 'Manage vocab & settings', Icons.admin_panel_settings,
          '/admin'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Text(
              'Good evening, Nati',
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface), // <-- add
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverGrid(
            delegate: SliverChildBuilderDelegate(
                (context, i) => _FeatureTile(feature: tiles[i]),
                childCount: tiles.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
          ),
        ],
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
        color: cs.surfaceVariant.withOpacity(.6),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: cs.primary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(feature.icon, size: 28, color: cs.primary),
            ),
            const Spacer(),
            Text(
              feature.title,
              style: TextStyle(
                // <-- no const here
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(feature.subtitle,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
          backgroundColor: cs.primary.withOpacity(.12),
          child: Icon(Icons.auto_awesome, color: cs.primary)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing:
          FilledButton.tonal(onPressed: () {}, child: const Text('Preview')),
    );
  }
}
