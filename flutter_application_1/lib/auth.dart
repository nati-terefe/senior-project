import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// ========== Shared UI helpers ==========
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
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(_snack(msg, icon: icon));
}

String _friendlyError(Object e) {
  if (e is FirebaseAuthException) {
    final code = e.code.toLowerCase();
    if (code.contains('popup') && code.contains('closed')) {
      return 'Google sign-in canceled.';
    }
    switch (code) {
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'user-disabled':
        return 'This account is disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'account-exists-with-different-credential':
        return 'This email is linked to another sign-in method.';
    }
    return e.message ?? 'Authentication failed.';
  }
  final s = e.toString().toLowerCase();
  if (s.contains('popup_closed') ||
      (s.contains('popup') && s.contains('closed'))) {
    return 'Google sign-in canceled.';
  }
  return 'Something went wrong.';
}

InputDecoration _deco(BuildContext context, String hint) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: isDark ? cs.surfaceVariant.withOpacity(.35) : cs.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

/// White “glass” spinner overlay
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({this.label = 'Working...'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return PositionedFill(
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          color: Colors.black.withOpacity(0.35),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
    );
  }
}

/// ========== Forgot Password ==========
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  Future<void> _doReset() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final hint = _hintCtrl.text.trim();

    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        _showSnack(context, 'No user found with that email.',
            icon: Icons.error_outline);
        return;
      }
      final storedHint = (q.docs.first.data()['hint'] ?? '').toString();
      if (storedHint != hint) {
        _showSnack(context, 'Wrong hint. Cannot reset password.',
            icon: Icons.error_outline);
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack(context, 'Password reset link sent to $email.',
          icon: Icons.mark_email_read_outlined);
    } catch (e) {
      _showSnack(context, _friendlyError(e), icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E7490), Color(0xFF082F49)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 12,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.key_outlined,
                                  size: 26,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Reset password',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'We’ll email you a reset link after verifying your hint.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        Text('Email',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _deco(context, 'you@example.com'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Email is required';
                            if (!v.contains('@') || !v.contains('.'))
                              return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Text('Hint',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _hintCtrl,
                          decoration: _deco(context, 'Your recovery hint'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Hint is required'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _doReset,
                          icon: const Icon(Icons.mail_outlined),
                          label: const Text('Send reset link'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ========== Login / Sign Up ==========
class LoginSignup extends StatefulWidget {
  const LoginSignup({super.key});

  @override
  State<LoginSignup> createState() => _LoginSignupState();
}

class _LoginSignupState extends State<LoginSignup> {
  bool _isLogin = true;
  bool _obscure = true;
  bool _loading = false;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();

  // Keep plugin for mobile; web uses Firebase Auth popup directly.
  final GoogleSignIn _google = GoogleSignIn(
    clientId: kIsWeb
        ? '28744048635-v1mjr7u8upjg04jjoh4hi8hpn7rbjlga.apps.googleusercontent.com'
        : null,
  );

  @override
  void initState() {
    super.initState();
    // Clear any lingering values (useful after hot reload)
    WidgetsBinding.instance.addPostFrameCallback((_) => _clearForm());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameCtrl.text = '';
    _emailCtrl.text = '';
    _passCtrl.text = '';
    _hintCtrl.text = '';
    _formKey.currentState?.reset();
  }

  void _setMode(bool login) {
    if (_isLogin == login) return;
    setState(() {
      _isLogin = login;
      _clearForm(); // clear inputs when toggling modes
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final hint = _hintCtrl.text.trim();

    try {
      setState(() => _loading = true);

      if (_isLogin) {
        final cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: pass);
        _clearForm();
        await _routeForUser(cred.user!.uid);
      } else {
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pass);
        final uid = cred.user!.uid;

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'hint': hint,
          'userType': 'User',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        _clearForm();
        setState(() => _isLogin = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSnack(context, 'Registered. You can sign in now.',
              icon: Icons.check_circle_outline);
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(context, _friendlyError(e), icon: Icons.error_outline);
    } catch (e) {
      if (!mounted) return;
      _showSnack(context, _friendlyError(e), icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _routeForUser(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final type = (doc.data()?['userType'] ?? 'User').toString();
    if (!mounted) return;
    if (type == 'Admin') {
      context.go('/admin');
    } else {
      context.go('/');
    }
  }

  /// Web: Firebase Auth popup with "select_account"; Mobile: plugin, forced chooser by signOut/disconnect.
  Future<void> _googleSignIn() async {
    try {
      setState(() => _loading = true);

      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters(
              {'prompt': 'select_account'}); // <-- always show chooser
        final userCred = await FirebaseAuth.instance.signInWithPopup(provider);
        final uid = userCred.user!.uid;

        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final isNew = !doc.exists;

        if (isNew) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'name': userCred.user?.displayName ?? 'No name',
            'email': userCred.user?.email ?? '',
            'hint': 'N/A',
            'userType': 'User',
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (mounted)
            _showSnack(context, 'Registered with Google. You’re all set!',
                icon: Icons.check_circle_outline);
        } else {
          if (mounted)
            _showSnack(context, 'Signed in with Google.', icon: Icons.login);
        }

        _clearForm();
        await _routeForUser(uid);
        return;
      }

      // ANDROID/iOS: ensure chooser appears by clearing previous session.
      await FirebaseAuth.instance
          .signOut(); // clear Firebase session just in case
      await _google.signOut(); // clear cached Google account
      try {
        await _google.disconnect();
      } catch (_) {} // revoke if possible

      final gUser = await _google.signIn(); // chooser should appear now
      if (gUser == null) {
        if (!mounted) return;
        _showSnack(context, 'Google sign-in canceled.',
            icon: Icons.info_outline);
        return;
      }

      final gAuth = await gUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final uid = userCred.user!.uid;

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final isNew = !doc.exists;
      if (isNew) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': userCred.user?.displayName ?? 'No name',
          'email': userCred.user?.email ?? '',
          'hint': 'N/A',
          'userType': 'User',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted)
          _showSnack(context, 'Registered with Google. You’re all set!',
              icon: Icons.check_circle_outline);
      } else {
        if (mounted)
          _showSnack(context, 'Signed in with Google.', icon: Icons.login);
      }

      _clearForm();
      await _routeForUser(uid);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(context, _friendlyError(e), icon: Icons.error_outline);
    } catch (e) {
      if (!mounted) return;
      _showSnack(context, _friendlyError(e), icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E7490), Color(0xFF082F49)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final double w = constraints.maxWidth;
                  final double maxCardWidth =
                      w < 420.0 ? w - 32.0 : (w < 720.0 ? 480.0 : 520.0);
                  final double vPad = w < 420.0 ? 16.0 : 24.0;
                  final double hPad = w < 420.0 ? 16.0 : 22.0;
                  final double radius = w < 420.0 ? 16.0 : 20.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxCardWidth),
                      child: Card(
                        elevation: 14,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                              horizontal: hPad, vertical: vPad),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo / Wordmark
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(Icons.sign_language_outlined,
                                        size: 26, color: cs.onPrimaryContainer),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'EthSL',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: cs.primary,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isLogin
                                    ? 'Welcome back'
                                    : 'Create your account',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),

                              // Toggle
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                      value: true,
                                      label: Text('Login'),
                                      icon: Icon(Icons.lock_open)),
                                  ButtonSegment(
                                      value: false,
                                      label: Text('Sign Up'),
                                      icon: Icon(Icons.person_add)),
                                ],
                                selected: {_isLogin},
                                onSelectionChanged: (s) => _setMode(s.first),
                                style: ButtonStyle(
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    return states.contains(WidgetState.selected)
                                        ? cs.primaryContainer
                                        : cs.surfaceVariant.withOpacity(.7);
                                  }),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Form
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (!_isLogin) ...[
                                      Text('Name',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _nameCtrl,
                                        decoration: _deco(context, 'Your name'),
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? 'Name is required'
                                                : null,
                                      ),
                                      const SizedBox(height: 12),
                                      Text('Hint',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _hintCtrl,
                                        decoration: _deco(
                                            context, 'Password recovery hint'),
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? 'Hint is required'
                                                : null,
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Text('Email',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _emailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration:
                                          _deco(context, 'name@example.com'),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty)
                                          return 'Email is required';
                                        if (!v.contains('@') ||
                                            !v.contains('.'))
                                          return 'Invalid email';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    Text('Password',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _passCtrl,
                                      obscureText: _obscure,
                                      decoration:
                                          _deco(context, 'Minimum 6 characters')
                                              .copyWith(
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                              () => _obscure = !_obscure),
                                          icon: Icon(_obscure
                                              ? Icons.visibility_off
                                              : Icons.visibility),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty)
                                          return 'Password is required';
                                        if (v.length < 6)
                                          return 'At least 6 characters';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              if (_isLogin) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordPage()),
                                    ),
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: _submit,
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(_isLogin ? 'Log in' : 'Sign up'),
                              ),
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                      child: Divider(color: cs.outlineVariant)),
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text('OR')),
                                  Expanded(
                                      child: Divider(color: cs.outlineVariant)),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Google button
                              OutlinedButton.icon(
                                onPressed: _googleSignIn,
                                icon: const Icon(Icons.g_mobiledata),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                label: const Text('Sign in with Google'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_loading) const _LoadingOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper for overlay fill
class PositionedFill extends StatelessWidget {
  const PositionedFill({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Positioned(top: 0, left: 0, right: 0, bottom: 0, child: child);
}
