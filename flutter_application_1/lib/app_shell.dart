// app_shell.dart
import 'dart:async'; // <-- for Timer

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

/// Defer navigation to the next frame (prevents web white screens / lifecycle asserts)
void _safeGo(BuildContext context, String location) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) GoRouter.of(context).go(location);
  });
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
/// App Shell (responsive AppBar + search)
/// ===============================================================
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  void _openSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _LessonSearchSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 980;
    final showInlineSearch = width >= 700;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 8,
        title: Row(
          children: [
            const Text('EthSL', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            if (showInlineSearch)
              Expanded(
                child: InkWell(
                  onTap: () => _openSearch(context),
                  borderRadius: BorderRadius.circular(16),
                  child: IgnorePointer(
                    ignoring: true,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search units or lessons…',
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
          ],
        ),
        actions: [
          if (!showInlineSearch)
            IconButton(
              tooltip: 'Search',
              onPressed: () => _openSearch(context),
              icon: const Icon(Icons.search),
            ),
          const SizedBox(width: 8),
          const _UserMenu(),
          const SizedBox(width: 8),
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

/// ---------- Search sheet: Units + Lessons ----------
class _LessonSearchSheet extends StatefulWidget {
  const _LessonSearchSheet();

  @override
  State<_LessonSearchSheet> createState() => _LessonSearchSheetState();
}

class _LessonSearchSheetState extends State<_LessonSearchSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  bool _loading = false;
  List<_SearchHit> _hits = [];

  // Turn search tips (index hints) ON/OFF globally
  static const bool _SHOW_SEARCH_TIPS = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 240), () => _run(q));
    setState(() {}); // update clear button visibility
  }

  /// Try an indexed prefix search on any of [fields]; if that fails (missing index),
  /// we do a small client-side filter as a graceful fallback.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _prefixTry(
    Query<Map<String, dynamic>> colOrGroup,
    List<String> fields,
    String q, {
    int limit = 20,
    void Function(String msg)? onIndexHint,
  }) async {
    for (final f in fields) {
      try {
        final snap = await colOrGroup
            .orderBy(f)
            .startAt([q])
            .endAt(['$q\uf8ff'])
            .limit(limit)
            .get();
        return snap.docs;
      } catch (e) {
        onIndexHint?.call('Consider an index on “$f” for faster search.');
      }
    }

    try {
      final snap = await colOrGroup.limit(50).get();
      final lowerQ = q.toLowerCase();
      final filtered = snap.docs
          .where((d) {
            final m = d.data();
            for (final f in fields) {
              final raw = (m[f] ?? m[f.replaceAll('normalized', 'title')] ?? '')
                  .toString();
              if (raw.toLowerCase().startsWith(lowerQ)) return true;
            }
            final alt =
                (m['name'] ?? m['title'] ?? '').toString().toLowerCase();
            return alt.startsWith(lowerQ);
          })
          .take(limit)
          .toList();
      return filtered;
    } catch (_) {
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }
  }

  /// Optional keywords search (arrayContainsAny on tokens)
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _keywordTry(
    Query<Map<String, dynamic>> colOrGroup,
    List<String> tokens, {
    int limit = 20,
  }) async {
    if (tokens.isEmpty) return [];
    try {
      final snap = await colOrGroup
          .where('keywords', arrayContainsAny: tokens.take(10).toList())
          .limit(limit)
          .get();
      return snap.docs;
    } catch (_) {
      return [];
    }
  }

  Future<void> _run(String raw) async {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _hits = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    final unitsCol = FirebaseFirestore.instance.collection('units');
    final lessonsGroup = FirebaseFirestore.instance.collectionGroup('lessons');

    final tokens =
        q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).take(10).toList();

    String? firstHint;

    // 1) Units
    final unitPrefixDocs = await _prefixTry(
      unitsCol,
      const ['normalizedName', 'nameLower', 'name'],
      q,
      limit: 12,
      onIndexHint:
          _SHOW_SEARCH_TIPS ? (msg) => firstHint ??= 'Units: $msg' : null,
    );
    final unitKwDocs = await _keywordTry(unitsCol, tokens, limit: 12);

    // 2) Lessons (collection group)
    final lessonPrefixDocs = await _prefixTry(
      lessonsGroup,
      const ['normalizedTitle', 'titleLower', 'title'],
      q,
      limit: 24,
      onIndexHint:
          _SHOW_SEARCH_TIPS ? (msg) => firstHint ??= 'Lessons: $msg' : null,
    );
    final lessonKwDocs = await _keywordTry(lessonsGroup, tokens, limit: 24);

    // Map → hits
    final hits = <_SearchHit>[
      ...unitPrefixDocs.map(_mapUnitDoc),
      ...unitKwDocs.map(_mapUnitDoc),
      ...lessonPrefixDocs.map(_mapLessonDoc),
      ...lessonKwDocs.map(_mapLessonDoc),
    ];

    // De-dup
    final seen = <String>{};
    final deduped = <_SearchHit>[];
    for (final h in hits) {
      if (seen.add(h.uniqueKey)) deduped.add(h);
    }

    if (!mounted) return;
    setState(() {
      _hits = deduped;
      _loading = false;
    });

    if (_SHOW_SEARCH_TIPS && firstHint != null) {
      _showSnack(context, firstHint!, icon: Icons.info_outline);
    }
  }

  _SearchHit _mapUnitDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final name = (data['name'] ?? '').toString();
    final title = name.isEmpty ? d.id : name;
    final route = '/lessons/${d.id}'; // Unit page
    return _SearchHit(
      uniqueKey: d.reference.path,
      title: title,
      subtitle: 'Unit',
      route: route,
      kind: _HitKind.unit,
    );
  }

  _SearchHit _mapLessonDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final title = (data['title'] ?? '').toString();
    final normalizedTitle = (data['normalizedTitle'] ?? '').toString();

    // Path like: units/<unitId>/lessons/<lessonId>
    final parts = d.reference.path.split('/');
    String unitId = '';
    String lessonId = d.id;
    if (parts.length >= 4) {
      unitId = parts[1];
      lessonId = parts[3];
    }

    final route = '/lessons/$unitId/$lessonId'; // Lesson page

    return _SearchHit(
      uniqueKey: d.reference.path,
      title: title.isEmpty
          ? (normalizedTitle.isEmpty ? lessonId : normalizedTitle)
          : title,
      subtitle: 'Lesson',
      route: route,
      kind: _HitKind.lesson,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Search units & lessons',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _run,
            decoration: InputDecoration(
              hintText: 'Try “Unit 2”, “H”, …',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _ctrl.clear();
                        _onChanged('');
                      },
                    ),
              filled: true,
              fillColor: isDark
                  ? cs.surfaceVariant.withOpacity(.35)
                  : cs.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading) const LinearProgressIndicator(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final h in _hits)
                  ListTile(
                    leading: Icon(h.kind == _HitKind.unit
                        ? Icons.folder
                        : Icons.menu_book),
                    title: Text(h.title),
                    subtitle: Text(h.subtitle),
                    onTap: () {
                      Navigator.pop(context); // close sheet
                      _safeGo(context, h.route);
                    },
                  ),
                if (!_loading && _hits.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.search_off),
                    title: Text('No matches found'),
                    subtitle: Text('Try another keyword (e.g., “Unit 1”).'),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _HitKind { unit, lesson }

class _SearchHit {
  final String uniqueKey;
  final String title;
  final String subtitle;
  final String route;
  final _HitKind kind;
  _SearchHit({
    required this.uniqueKey,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.kind,
  });
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

        if (user == null) {
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () => _safeGo(context, '/auth'),
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
            onForegroundImageError: (_, __) {},
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
                  await FirebaseAuth.instance.signOut();
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

// Intercept protected routes, prompt login using ROOT navigator, and always close drawer
  Future<void> _goOrPrompt(BuildContext context, String path) async {
    // Close the drawer if it's the temporary one
    if (!permanent && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Normalize translate alias
    final normalizedPath = (path == '/translate') ? '/instant_translate' : path;

    // Which routes require login?
    final requiresLogin = normalizedPath == '/instant_translate' ||
        normalizedPath.startsWith('/lessons') ||
        normalizedPath.startsWith('/quiz');

    if (requiresLogin) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Friendly feature name for the dialog title/body
        String featureName = 'this feature';
        if (normalizedPath == '/instant_translate')
          featureName = 'Instant Translate';
        else if (normalizedPath.startsWith('/lessons'))
          featureName = 'Lessons';
        else if (normalizedPath.startsWith('/quiz')) featureName = 'Quiz';

        final wantsLogin = await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Sign in required'),
            content: Text('You need to be signed in to use $featureName.'),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(_, rootNavigator: true).pop(false), // Cancel
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(_, rootNavigator: true).pop(true), // Login
                child: const Text('Login'),
              ),
            ],
          ),
        );

        if (wantsLogin == true) {
          _safeGo(context, '/auth');
        }
        // Cancel/no → do nothing
        return;
      }
    }

    // Signed in or not protected → go
    _safeGo(context, normalizedPath);
  }

  @override
  Widget build(BuildContext context) {
    final nav = [
      _Nav('Home', Icons.home, '/'),
      _Nav('Instant Translate', Icons.camera_alt, '/instant_translate'),
      _Nav('Vocabulary', Icons.grid_view, '/vocab'),
      _Nav('Lessons', Icons.menu_book, '/lessons'),
      _Nav('Quiz', Icons.quiz, '/quiz'),
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
              onTap: () => _goOrPrompt(context, n.path),
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
/// Account Info Sheet — responsive (draggable + scrollable)
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
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) {
          final isNarrow = MediaQuery.of(ctx).size.width < 480;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Account info',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    children: [
                      _kv('Name', name.isEmpty ? '—' : name),
                      _kv('Email', email.isEmpty ? '—' : email),
                      _kv('User type', userType),
                      _kv('Hint', hint.isEmpty ? '—' : hint),
                      _kv('Created', created),
                      _kv('Last sign-in', lastSignIn),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (isNarrow)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(ctx).colorScheme.error,
                            foregroundColor: Theme.of(ctx).colorScheme.onError,
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final ok = await _confirmDeleteAccount(ctx);
                            if (ok) await _deleteAccountFlow(ctx);
                          },
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete account'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(ctx).colorScheme.error,
                            foregroundColor: Theme.of(ctx).colorScheme.onError,
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final ok = await _confirmDeleteAccount(ctx);
                            if (ok) await _deleteAccountFlow(ctx);
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
/// Edit Profile Page (unchanged)
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
                final double maxW = w < 600.0 ? w - 24.0 : 560.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        MediaQuery.of(context).viewInsets.bottom + 24,
                      ),
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
