import 'package:flutter/material.dart';

class VocabularyScreen extends StatelessWidget {
  const VocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = List.generate(18, (i) => 'Word ${i + 1}');
    return _ScaffoldPad(
      title: 'Vocabulary',
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: .95),
        itemCount: items.length,
        itemBuilder: (_, i) => Card(
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                const Expanded(
                    child: Center(child: Icon(Icons.pan_tool_alt, size: 42))),
                const SizedBox(height: 8),
                const Text('አዎ / Yes',
                    style: TextStyle(fontWeight: FontWeight.w700)),
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
