import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Hero
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign ↔ Text, Seamlessly',
                      style: theme.textTheme.headlineSmall!
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'We’re building an app that recognizes sign language and turns it into text so conversations can flow without barriers.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(context, 'ASL only (for now)'),
                      _chip(context, 'Works online'),
                      _chip(context, 'Firebase-backed privacy'),
                      _chip(context, 'Learn with lessons & quizzes'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mission
            Text('Our Mission',
                style: theme.textTheme.titleLarge!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Accessibility is a right. We co-design with Deaf communities to create technology that respects culture and supports everyday communication at school, work, and home.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            // How It Works (vertical cards to avoid overflow)
            Text('How It Works',
                style: theme.textTheme.titleLarge!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            _StepTile(
              icon: Icons.pan_tool_outlined,
              title: 'Capture',
              body:
                  'The camera detects handshape, motion, and facial cues (with your permission). Works online in the current version.',
            ),
            const SizedBox(height: 12),

            _StepTile(
              icon: Icons.translate_outlined,
              title: 'Interpret',
              body:
                  'Our model maps the movements to American Sign Language (ASL) and context to produce accurate text.',
            ),
            const SizedBox(height: 12),

            _StepTile(
              icon: Icons.lock_outline,
              title: 'Privacy',
              body:
                  'We use Firebase for secure storage and services. By default, we don’t store camera frames; nothing is shared without your consent.',
            ),
            const SizedBox(height: 24),

            // CTA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.handshake_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Questions or partnerships?',
                            style: theme.textTheme.titleMedium!
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          'We’d love to talk with schools, NGOs, and community groups. Reach out and let’s collaborate.',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/contact'),
                    icon: const Icon(Icons.send),
                    label: const Text('Contact Us'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _chip(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: theme.textTheme.labelLarge),
    );
  }
}

class _StepTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _StepTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: t.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: t.textTheme.titleMedium!
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(body, style: t.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
