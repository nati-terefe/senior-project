import 'package:flutter/material.dart';

class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _ScaffoldPad(
      title: 'Lessons',
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) => ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text('Unit ${i + 1}: Basics'),
          subtitle: const Text('Handshapes, greetings, numbers'),
          trailing:
              FilledButton.tonal(onPressed: () {}, child: const Text('Start')),
        ),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: 6,
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
