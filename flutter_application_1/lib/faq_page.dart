import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final faqs = const [
      _Faq(
        q: 'How long does it take to learn sign language?',
        a: 'It varies by person and language. With our bite-sized lessons, many learners hold simple conversations in 4–6 weeks when practicing daily.',
      ),
      _Faq(
        q: 'Which sign languages does the app support?',
        a: 'We focus on ASL and Ethiopian Sign for now. We’re expanding with local partners—follow our updates for more languages.',
      ),
      _Faq(
        q: 'Does it work offline?',
        a: 'Lessons and quizzes work offline. Live sign-to-text needs the camera and may use on-device models; some features still require internet for best accuracy.',
      ),
      _Faq(
        q: 'Is my camera data stored?',
        a: 'No, by default we process video frames locally and do not store them. You can opt-in to share anonymized samples to improve models.',
      ),
      _Faq(
        q: 'Is this a replacement for interpreters?',
        a: 'No. Technology supports independence and everyday communication, but interpreters remain essential for many contexts.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Frequently Asked Questions',
                      style: t.textTheme.headlineSmall!
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(
                    'Answers to common questions about our sign-to-text app, privacy, and learning.',
                    style: t.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: faqs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final f = faqs[i];
                        return Card(
                          child: ExpansionTile(
                            title: Text(f.q,
                                style: t.textTheme.titleMedium!
                                    .copyWith(fontWeight: FontWeight.w700)),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(f.a, style: t.textTheme.bodyLarge),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});
}
