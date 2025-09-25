import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 980;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const Text('EthSL', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search signs, words, lessons…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: CircleAvatar(child: Icon(Icons.person)),
          )
        ],
      ),
      drawer: isWide ? null : const _AppDrawer(),
      body: Row(
        children: [
          if (isWide)
            const SizedBox(width: 260, child: _AppDrawer(permanent: true)),
          Expanded(
              child: Container(
                  color: Theme.of(context).colorScheme.surface, child: child)),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({this.permanent = false});
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final nav = [
      _Nav('Home', Icons.home, '/'),
      _Nav('Instant Translate', Icons.camera_alt, '/translate'),
      _Nav('Vocabulary', Icons.grid_view, '/vocab'),
      _Nav('Lessons', Icons.menu_book, '/lessons'),
      _Nav('Quiz', Icons.quiz, '/quiz'),
      _Nav('Dataset', Icons.video_library, '/dataset'),
      _Nav('Settings', Icons.settings, '/settings'),
    ];

    final content = SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        children: [
          ListTile(
            title: Text('Creative Platform',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(fontWeight: FontWeight.w700)),
            subtitle: const Text('Amharic Sign Tools'),
          ),
          const SizedBox(height: 10),
          for (final n in nav)
            ListTile(
              leading: Icon(n.icon),
              title: Text(n.label),
              onTap: () => context.go(n.path),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          const Divider(),
          // Upgrade removed per request
        ],
      ),
    );

    return permanent
        ? Material(elevation: 0, child: content)
        : Drawer(child: content);
  }
}

class _Nav {
  final String label;
  final IconData icon;
  final String path;
  _Nav(this.label, this.icon, this.path);
}
