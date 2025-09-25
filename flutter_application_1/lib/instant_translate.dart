import 'package:flutter/material.dart';

class InstantTranslateScreen extends StatelessWidget {
  const InstantTranslateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _ScaffoldPad(
      title: 'Instant translate',
      child: Center(
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(20)),
                child: const Center(child: Icon(Icons.videocam, size: 56)),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(.9),
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('ዛሬ እንዴት ነህ?',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimaryContainer)),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                          onPressed: () {}, child: const Icon(Icons.volume_up)),
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

class _ScaffoldPad extends StatelessWidget {
  const _ScaffoldPad({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
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
}
