import 'package:flutter/material.dart';
import './theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeControllerProvider.of(context); // <-- works now

    return _ScaffoldPad(
      title: 'Settings',
      child: ListView(
        children: [
          SwitchListTile(
            value: theme.isDark,
            onChanged: theme.toggle, // toggles app-wide ThemeMode
            title: const Text('Dark mode'),
          ),
          const ListTile(
            title: Text('Language'),
            subtitle: Text('English (en-US)'),
          ),
          const ListTile(
              title: Text('TTS Voice'), subtitle: Text('System default')),
        ],
      ),
    );
  }
}

class _ScaffoldPad extends StatelessWidget {
  const _ScaffoldPad({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Expanded(child: child),
        ]),
      );
}
