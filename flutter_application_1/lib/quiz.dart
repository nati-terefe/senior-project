import 'package:flutter/material.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _ScaffoldPad(
      title: 'Quiz',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('What does this sign mean?',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Container(
                  height: 220,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.pan_tool_alt, size: 72),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(onPressed: () {}, child: const Text('አዎ')),
                    OutlinedButton(onPressed: () {}, child: const Text('አይ')),
                    OutlinedButton(onPressed: () {}, child: const Text('ሰላም')),
                    OutlinedButton(onPressed: () {}, child: const Text('እባክህ')),
                  ],
                ),
              ]),
            ),
          ),
        ),
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
