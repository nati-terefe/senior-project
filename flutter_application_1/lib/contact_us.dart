import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key});

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String e) {
    final s = e.trim();
    final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return re.hasMatch(s);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _busy = true);

      await FirebaseFirestore.instance.collection('contact_messages').add({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Message sent. We’ll get back to you soon!')),
      );

      _formKey.currentState!.reset();
      _nameCtrl.clear();
      _emailCtrl.clear();
      _msgCtrl.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to send. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, c) {
            final isWide = c.maxWidth >= 980;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isWide
                      ? Row(
                          children: [
                            // Left info panel (only on wide)
                            Expanded(
                              child: _InfoPane(),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _FormCard(
                                    formKey: _formKey,
                                    nameCtrl: _nameCtrl,
                                    emailCtrl: _emailCtrl,
                                    msgCtrl: _msgCtrl,
                                    busy: _busy,
                                    validateEmail: _looksLikeEmail,
                                    onSubmit: _submit)),
                          ],
                        )
                      : ListView(
                          children: [
                            _InfoPane(),
                            const SizedBox(height: 16),
                            _FormCard(
                                formKey: _formKey,
                                nameCtrl: _nameCtrl,
                                emailCtrl: _emailCtrl,
                                msgCtrl: _msgCtrl,
                                busy: _busy,
                                validateEmail: _looksLikeEmail,
                                onSubmit: _submit),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Get in Touch',
              style: t.textTheme.titleLarge!
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Have questions, suggestions, or partnership ideas? We’d love to hear from you!',
            style: t.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _ContactInfo(
            icon: Icons.email_outlined,
            label: 'Email',
            value: 'SLS@gmail.com',
          ),
          _ContactInfo(
            icon: Icons.location_on_outlined,
            label: 'Office',
            value: '4 Kilo, Addis Ababa, Ethiopia',
          ),
          _ContactInfo(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: '+25137675360',
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController msgCtrl;
  final bool busy;
  final bool Function(String) validateEmail;
  final VoidCallback onSubmit;

  const _FormCard({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.msgCtrl,
    required this.busy,
    required this.validateEmail,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send a message',
                  style: t.textTheme.titleLarge!
                      .copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),

              // Name
              TextFormField(
                controller: nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  helperText: 'Tell us who you are',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (v.trim().length < 2) {
                    return 'Please enter a valid name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Email
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'We’ll reply to this address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!validateEmail(v)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Message
              TextFormField(
                controller: msgCtrl,
                maxLines: 6,
                minLines: 4,
                maxLength: 1000,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  helperText: 'Describe your question or idea',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.message_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Message is required';
                  }
                  if (v.trim().length < 10) {
                    return 'Please provide a bit more detail';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),

              // Submit
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: busy ? null : onSubmit,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(busy ? 'Sending…' : 'Send Message'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelMedium!
                        .copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
