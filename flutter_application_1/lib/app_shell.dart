import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ---------- Shared UI helpers ----------
SnackBar _snack(String msg, {IconData? icon}) => SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(child: Text(msg)),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

void _showSnack(BuildContext context, String msg, {IconData? icon}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..clearSnackBars()
    ..showSnackBar(_snack(msg, icon: icon));
}

/// Glassy loading overlay
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({this.label = 'Working...'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(.35)),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                  boxShadow: const [
                    BoxShadow(blurRadius: 20, color: Colors.black26)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Working...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ===============================================================
/// App Shell
/// ===============================================================
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
          SizedBox(width: 8),
          _UserMenu(),
          SizedBox(width: 8),
        ],
      ),
      drawer: isWide ? null : const _AppDrawer(),
      body: Row(
        children: [
          if (isWide)
            const SizedBox(width: 260, child: _AppDrawer(permanent: true)),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu();

  String _initials(String? displayName, String email) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      final parts = displayName
          .trim()
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        return parts.take(2).map((p) => p[0].toUpperCase()).join();
      }
    }
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;

        // Not signed in → simple avatar to /auth
        if (user == null) {
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () => context.go('/auth'),
              borderRadius: BorderRadius.circular(30),
              child: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
                child: const Icon(Icons.person),
              ),
            ),
          );
        }

        final displayName = user.displayName?.trim();
        final email = user.email ?? '';
        final photoUrl = user.photoURL;
        final initials = _initials(displayName, email);

        Widget avatarChild;
        if (photoUrl != null && photoUrl.isNotEmpty) {
          avatarChild = CircleAvatar(
            foregroundImage: NetworkImage(photoUrl),
            onForegroundImageError:
                (_, __) {}, // safe: only present when image provided
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: Text(initials),
          );
        } else {
          avatarChild = CircleAvatar(
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: Text(initials),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: PopupMenuButton<_UserAction>(
            tooltip: 'Account',
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (choice) async {
              switch (choice) {
                case _UserAction.account:
                  await _showAccountInfo(context, user);
                  break;
                case _UserAction.edit:
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  );
                  break;
                case _UserAction.signOut:
                  await FirebaseAuth.instance.signOut(); // stream rebuilds UI
                  _showSnack(context, 'Signed out.');
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_UserAction>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (displayName?.isNotEmpty == true
                          ? displayName!
                          : 'Signed in'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (email.isNotEmpty)
                      Text(email, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _UserAction.edit,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit),
                  title: Text('Edit profile'),
                ),
              ),
              const PopupMenuItem(
                value: _UserAction.account,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline),
                  title: Text('Account info'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _UserAction.signOut,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Sign out'),
                ),
              ),
            ],
            child: avatarChild,
          ),
        );
      },
    );
  }
}

enum _UserAction { account, edit, signOut }

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
            title: Text(
              'Creative Platform',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(fontWeight: FontWeight.w700),
            ),
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

/// ===============================================================
/// Account Info Sheet (trimmed)
/// ===============================================================
Future<void> _showAccountInfo(BuildContext context, User user) async {
  final uid = user.uid;
  final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = doc.data() ?? {};
  final userType = (data['userType'] ?? 'User').toString();
  final hint = (data['hint'] ?? '').toString();
  final name = (data['name'] ?? (user.displayName ?? '')).toString();
  final email = user.email ?? (data['email'] ?? '').toString();

  final meta = user.metadata;
  final created = meta.creationTime?.toLocal().toString() ?? '—';
  final lastSignIn = meta.lastSignInTime?.toLocal().toString() ?? '—';

  await showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text('Account info',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _kv('Name', name.isEmpty ? '—' : name),
            _kv('Email', email.isEmpty ? '—' : email),
            _kv('User type', userType),
            _kv('Hint', hint.isEmpty ? '—' : hint),
            _kv('Created', created),
            _kv('Last sign-in', lastSignIn),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      final ok = await _confirmDeleteAccount(context);
                      if (ok) await _deleteAccountFlow(context);
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete account'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Widget _kv(String k, String v) {
  return ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(v),
  );
}

Future<bool> _confirmDeleteAccount(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This will permanently delete your account and profile data. '
            'You can still browse the app signed out.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

/// Delete both Auth user and Firestore user doc.
Future<void> _deleteAccountFlow(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  bool loadingShown = false;
  void showLoading() {
    if (!loadingShown) {
      loadingShown = true;
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: _LoadingOverlay(),
        ),
      );
    }
  }

  void hideLoading() {
    if (loadingShown) {
      Navigator.of(context, rootNavigator: true).pop();
      loadingShown = false;
    }
  }

  try {
    showLoading();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .delete()
        .catchError((_) {});
    await user.delete();
    hideLoading();

    _showSnack(context, 'Account deleted. You are signed out.',
        icon: Icons.check_circle_outline);
    await FirebaseAuth.instance.signOut();
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      hideLoading();
      final ok = await _reauthenticateForDeletion(context, user);
      if (!ok) return;
      await _deleteAccountFlow(context);
    } else {
      hideLoading();
      _showSnack(context, e.message ?? 'Delete failed.',
          icon: Icons.error_outline);
    }
  } catch (e) {
    hideLoading();
    _showSnack(context, 'Delete failed. ${e.toString()}',
        icon: Icons.error_outline);
  }
}

/// Reauthenticate for deletion
Future<bool> _reauthenticateForDeletion(BuildContext context, User user) async {
  final providers = user.providerData.map((p) => p.providerId).toList();

  if (providers.contains('password') && (user.email?.isNotEmpty ?? false)) {
    final pass = await _promptPassword(context);
    if (pass == null) return false;

    try {
      final cred =
          EmailAuthProvider.credential(email: user.email!, password: pass);
      await user.reauthenticateWithCredential(cred);
      return true;
    } on FirebaseAuthException catch (e) {
      _showSnack(context, e.message ?? 'Reauthentication failed.',
          icon: Icons.error_outline);
      return false;
    }
  }

  if (providers.contains('google.com')) {
    try {
      // Web popup try; on mobile this will throw and we ask to re-sign-in.
      try {
        final google = GoogleAuthProvider();
        await user.reauthenticateWithPopup(google);
        return true;
      } catch (_) {
        _showSnack(context, 'Please sign in again to confirm deletion.',
            icon: Icons.info_outline);
        await FirebaseAuth.instance.signOut();
        return false;
      }
    } catch (e) {
      _showSnack(context, 'Reauthentication failed.',
          icon: Icons.error_outline);
      return false;
    }
  }

  _showSnack(
      context, 'Reauthentication not available. Sign out and sign back in.',
      icon: Icons.info_outline);
  return false;
}

Future<String?> _promptPassword(BuildContext context) async {
  final ctrl = TextEditingController();
  bool obscure = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text('Confirm password'),
        content: StatefulBuilder(
          builder: (context, setSt) => TextField(
            controller: ctrl,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setSt(() => obscure = !obscure),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      );
    },
  );
  if (ok == true) return ctrl.text;
  return null;
}

/// ===============================================================
/// Edit Profile Page (password fields hidden until clicked)
/// ===============================================================
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // read-only
  final _hintCtrl = TextEditingController();

  // Change password fields
  final _pwCurrentCtrl = TextEditingController();
  final _pwNewCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _pwObscureCurrent = true;
  bool _pwObscureNew = true;
  bool _pwObscureConfirm = true;
  bool _showPwFields = false;

  bool _loading = true;
  bool _saving = false;
  bool _changingPassword = false;
  late final List<String> _providers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};
    _nameCtrl.text = (data['name'] ?? user.displayName ?? '').toString();
    _emailCtrl.text = (user.email ?? (data['email'] ?? '')).toString();
    _hintCtrl.text = (data['hint'] ?? '').toString();
    _providers = user.providerData.map((p) => p.providerId).toList();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _hintCtrl.dispose();
    _pwCurrentCtrl.dispose();
    _pwNewCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _deco(String hint) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor:
          isDark ? cs.surfaceVariant.withOpacity(.35) : cs.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    try {
      setState(() => _saving = true);

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'hint': _hintCtrl.text.trim(),
        'userType': 'User',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(
          _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim());
      await user.reload();

      if (!mounted) return;
      _showSnack(context, 'Profile updated.', icon: Icons.check_circle_outline);
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(context, e.message ?? 'Failed to update profile.',
          icon: Icons.error_outline);
    } catch (e) {
      if (!mounted) return;
      _showSnack(context, 'Failed to update profile. ${e.toString()}',
          icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser!;
    final email = user.email ?? '';

    if (!_providers.contains('password') || email.isEmpty) {
      // Google-only: send setup link
      try {
        setState(() => _changingPassword = true);
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        if (!mounted) return;
        _showSnack(context, 'Password setup email sent to $email.',
            icon: Icons.mark_email_read_outlined);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        _showSnack(context, e.message ?? 'Could not send setup email.',
            icon: Icons.error_outline);
      } finally {
        if (mounted) setState(() => _changingPassword = false);
      }
      return;
    }

    // Validate fields
    final current = _pwCurrentCtrl.text.trim();
    final newPw = _pwNewCtrl.text.trim();
    final confirm = _pwConfirmCtrl.text.trim();

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      _showSnack(context, 'Fill all password fields.',
          icon: Icons.error_outline);
      return;
    }
    if (newPw.length < 6) {
      _showSnack(context, 'New password must be at least 6 characters.',
          icon: Icons.error_outline);
      return;
    }
    if (newPw != confirm) {
      _showSnack(context, 'New passwords do not match.',
          icon: Icons.error_outline);
      return;
    }

    try {
      setState(() => _changingPassword = true);
      final cred =
          EmailAuthProvider.credential(email: email, password: current);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPw);
      if (!mounted) return;
      _pwCurrentCtrl.clear();
      _pwNewCtrl.clear();
      _pwConfirmCtrl.clear();
      setState(() => _showPwFields = false);
      _showSnack(context, 'Password changed.',
          icon: Icons.check_circle_outline);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(context, e.message ?? 'Password change failed.',
          icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // --- FIXED AVATAR: conditional onForegroundImageError only if image exists
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final bool hasImg = photoUrl != null && photoUrl.isNotEmpty;
    final ImageProvider? img = hasImg ? NetworkImage(photoUrl) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final double w = constraints.maxWidth;
                final double maxW = w < 480.0 ? w - 24.0 : 560.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  foregroundImage: img,
                                  onForegroundImageError: hasImg
                                      ? (Object _, StackTrace? __) {}
                                      : null,
                                  child: hasImg
                                      ? null
                                      : const Icon(Icons.person, size: 28),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Update your public profile details.\nPassword is managed below.',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            Text('Name',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: _deco('Your display name'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Name is required'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            Text('Email',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailCtrl,
                              readOnly: true,
                              decoration: _deco('Email (read-only)').copyWith(
                                suffixIcon: Tooltip(
                                  message:
                                      'Email changes require re-verification.\nImplement separately if needed.',
                                  child: const Icon(Icons.lock_outline),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            Text('Recovery hint',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _hintCtrl,
                              decoration:
                                  _deco('Used to verify password reset'),
                            ),

                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _saving ? null : _saveProfile,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save changes'),
                            ),
                            const SizedBox(height: 16),

                            Divider(color: cs.outlineVariant),
                            const SizedBox(height: 8),

                            // ----- Change Password Section -----
                            Text('Change password',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),

                            if (_providers.contains('password')) ...[
                              if (!_showPwFields)
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      setState(() => _showPwFields = true),
                                  icon: const Icon(Icons.password),
                                  label: const Text('Change password'),
                                )
                              else ...[
                                TextFormField(
                                  controller: _pwCurrentCtrl,
                                  obscureText: _pwObscureCurrent,
                                  decoration:
                                      _deco('Current password').copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(_pwObscureCurrent
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(() =>
                                          _pwObscureCurrent =
                                              !_pwObscureCurrent),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _pwNewCtrl,
                                  obscureText: _pwObscureNew,
                                  decoration:
                                      _deco('New password (min 6 chars)')
                                          .copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(_pwObscureNew
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(
                                          () => _pwObscureNew = !_pwObscureNew),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _pwConfirmCtrl,
                                  obscureText: _pwObscureConfirm,
                                  decoration:
                                      _deco('Confirm new password').copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(_pwObscureConfirm
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(() =>
                                          _pwObscureConfirm =
                                              !_pwObscureConfirm),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: _changingPassword
                                            ? null
                                            : _changePassword,
                                        icon: const Icon(Icons.check),
                                        label: const Text('Save new password'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _changingPassword
                                            ? null
                                            : () {
                                                _pwCurrentCtrl.clear();
                                                _pwNewCtrl.clear();
                                                _pwConfirmCtrl.clear();
                                                setState(() =>
                                                    _showPwFields = false);
                                              },
                                        icon: const Icon(Icons.close),
                                        label: const Text('Cancel'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ] else ...[
                              // No password provider -> offer setup email
                              OutlinedButton.icon(
                                onPressed:
                                    _changingPassword ? null : _changePassword,
                                icon: const Icon(Icons.mail_outline),
                                label: const Text(
                                    'Email me a password setup link'),
                              ),
                            ],

                            const SizedBox(height: 16),
                            Divider(color: cs.outlineVariant),
                            const SizedBox(height: 8),

                            // Bottom delete button (top icon removed)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.error,
                                foregroundColor: cs.onError,
                              ),
                              onPressed: _saving || _changingPassword
                                  ? null
                                  : () async {
                                      final ok =
                                          await _confirmDeleteAccount(context);
                                      if (ok) await _deleteAccountFlow(context);
                                    },
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Delete account'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (_saving || _changingPassword) const _LoadingOverlay(),
        ],
      ),
    );
  }
}
