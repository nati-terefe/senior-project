// lib/admin.dart
import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'theme_controller.dart';

/* ============================
   Safe navigation helper
   ============================ */

extension _SafeGo on BuildContext {
  /// Schedule navigation to the next frame to avoid lifecycle asserts/white flashes.
  void safeGo(String location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final el = this as Element;
      if (!el.mounted) return;
      GoRouter.of(this).go(location);
    });
  }
}

/* ============================
   Small helpers
   ============================ */

SnackBar _snack(String msg, {IconData? icon}) => SnackBar(
      content: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(child: Text(msg)),
      ]),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
void _toast(BuildContext c, String m, {IconData? icon}) =>
    ScaffoldMessenger.of(c)
      ..clearSnackBars()
      ..showSnackBar(_snack(m, icon: icon));

Future<bool> _confirm(
  BuildContext c, {
  required String title,
  required String message,
  String confirmText = 'Delete',
}) async {
  final ok = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error),
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return ok ?? false;
}

bool _looksLikeYoutubeUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('https://youtu.be/') ||
      u.startsWith('http://youtu.be/') ||
      u.contains('youtube.com/watch') ||
      u.contains('youtube.com/embed/');
}

bool _looksLikeEmail(String e) =>
    RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(e.trim());

/* ============================
   Admin Shell (responsive)
   ============================ */

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      LessonsAdmin(),
      UsersAdmin(),
      VocabularyAdmin(),
      QuizzesAdmin(),
      MessagesAdmin(),
      AdminSettings(),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 960;

        final navRail = NavigationRail(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(
                icon: Icon(Icons.menu_book), label: Text('Lessons')),
            NavigationRailDestination(
                icon: Icon(Icons.people), label: Text('Users')),
            NavigationRailDestination(
                icon: Icon(Icons.grid_view), label: Text('Vocabulary')),
            NavigationRailDestination(
                icon: Icon(Icons.quiz), label: Text('Quizzes')),
            NavigationRailDestination(
                icon: Icon(Icons.mail_outline), label: Text('Messages')),
            NavigationRailDestination(
                icon: Icon(Icons.settings), label: Text('Settings')),
          ],
        );

        final body = AnimatedSwitcher(
            duration: const Duration(milliseconds: 180), child: pages[_tab]);

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text('Admin Panel'),
            scrolledUnderElevation: 0,
          ),
          body: SafeArea(
            child: isWide
                ? Row(children: [
                    navRail,
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ])
                : body,
          ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.menu_book), label: 'Lessons'),
                    NavigationDestination(
                        icon: Icon(Icons.people), label: 'Users'),
                    NavigationDestination(
                        icon: Icon(Icons.grid_view), label: 'Vocabulary'),
                    NavigationDestination(
                        icon: Icon(Icons.quiz), label: 'Quizzes'),
                    NavigationDestination(
                        icon: Icon(Icons.mail_outline), label: 'Messages'),
                    NavigationDestination(
                        icon: Icon(Icons.settings), label: 'Settings'),
                  ],
                ),
        );
      },
    );
  }
}

/* =========================================================
   LESSONS (duplicate-safe) • /units + /units/{id}/lessons
   ========================================================= */

class LessonsAdmin extends StatefulWidget {
  const LessonsAdmin({super.key});
  @override
  State<LessonsAdmin> createState() => _LessonsAdminState();
}

class _LessonsAdminState extends State<LessonsAdmin>
    with TickerProviderStateMixin {
  final _units = FirebaseFirestore.instance.collection('units');
  final _unitName = TextEditingController(text: 'Unit 1');
  String? _unitCategory; // NEW: selected category for new unit

  // per-unit inputs (so each expanded unit has its own controllers)
  final Map<String, TextEditingController> _titleCtrls = {};
  final Map<String, TextEditingController> _urlCtrls = {};
  final Map<String, String?> _lessonCategory =
      {}; // NEW: per-unit lesson category

  int? _expandedIndex;
  bool _busy = false;

  TextEditingController _titleCtrlFor(String id) =>
      _titleCtrls.putIfAbsent(id, () => TextEditingController());
  TextEditingController _urlCtrlFor(String id) =>
      _urlCtrls.putIfAbsent(id, () => TextEditingController());
  String? _lessonCatFor(String id) => _lessonCategory[id];

  Future<void> _addUnit() async {
    final name = _unitName.text.trim();
    final category = _unitCategory?.trim();
    if (name.isEmpty) {
      _toast(context, 'Unit name is required', icon: Icons.error_outline);
      return;
    }
    if (category == null || category.isEmpty) {
      _toast(context, 'Select a category', icon: Icons.error_outline);
      return;
    }
    final norm = name.toLowerCase();
    try {
      final dup =
          await _units.where('normalizedName', isEqualTo: norm).limit(1).get();
      if (dup.docs.isNotEmpty) {
        _toast(context, 'Unit "$name" already exists',
            icon: Icons.info_outline);
        return;
      }
      await _units.add({
        'name': name,
        'normalizedName': norm,
        'category': category,
        'normalizedCategory': category.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _unitName.text = 'Unit ${DateTime.now().millisecondsSinceEpoch % 1000}';
      _unitCategory = null;
      setState(() {});
      _toast(context, 'Unit added', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to add unit', icon: Icons.error_outline);
    }
  }

  Future<void> _renameUnit(
      String id, String current, String? currentCat) async {
    final c = TextEditingController(text: current);
    String category = currentCat ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit unit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: c,
                  decoration: const InputDecoration(hintText: 'Unit name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category.isEmpty ? null : category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'english', child: Text('English')),
                    DropdownMenuItem(value: 'amharic', child: Text('Amharic')),
                  ],
                  onChanged: (v) => setS(() => category = v ?? ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final newName = c.text.trim();
    if (newName.isEmpty) {
      _toast(context, 'Unit name cannot be empty', icon: Icons.error_outline);
      return;
    }
    if (category.isEmpty) {
      _toast(context, 'Select a category', icon: Icons.error_outline);
      return;
    }
    final norm = newName.toLowerCase();

    final dup =
        await _units.where('normalizedName', isEqualTo: norm).limit(1).get();
    if (dup.docs.isNotEmpty && dup.docs.first.id != id) {
      _toast(context, 'Another unit already uses that name',
          icon: Icons.info_outline);
      return;
    }

    try {
      await _units.doc(id).update({
        'name': newName,
        'normalizedName': norm,
        'category': category,
        'normalizedCategory': category.toLowerCase(),
      });
      _toast(context, 'Updated', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to update', icon: Icons.error_outline);
    }
  }

  Future<void> _deleteUnit(String id, String name) async {
    final ok = await _confirm(context,
        title: 'Delete "$name"?',
        message: 'This will remove the unit and all its lessons.');
    if (!ok) return;

    try {
      setState(() => _busy = true);
      final lessons = await _units.doc(id).collection('lessons').get();
      for (final d in lessons.docs) {
        await d.reference.delete();
      }
      await _units.doc(id).delete();
      _titleCtrls.remove(id)?.dispose();
      _urlCtrls.remove(id)?.dispose();
      _lessonCategory.remove(id);
      _toast(context, 'Unit deleted', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to delete', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addLessonTo(String unitId) async {
    final t = _titleCtrlFor(unitId).text.trim();
    final u = _urlCtrlFor(unitId).text.trim();
    final cat = _lessonCatFor(unitId)?.trim();

    if (t.isEmpty) {
      _toast(context, 'Lesson title is required', icon: Icons.error_outline);
      return;
    }
    if (!_looksLikeYoutubeUrl(u)) {
      _toast(context, 'Enter a valid YouTube URL', icon: Icons.error_outline);
      return;
    }
    if (cat == null || cat.isEmpty) {
      _toast(context, 'Select a lesson category', icon: Icons.error_outline);
      return;
    }

    final nt = t.toLowerCase();
    final nu = u.toLowerCase();

    final col = _units.doc(unitId).collection('lessons');
    final dupTitle =
        await col.where('normalizedTitle', isEqualTo: nt).limit(1).get();
    if (dupTitle.docs.isNotEmpty) {
      _toast(context, 'A lesson with that title already exists in this unit',
          icon: Icons.info_outline);
      return;
    }
    final dupUrl =
        await col.where('normalizedUrl', isEqualTo: nu).limit(1).get();
    if (dupUrl.docs.isNotEmpty) {
      _toast(context, 'This video URL already exists in this unit',
          icon: Icons.info_outline);
      return;
    }

    try {
      await col.add({
        'title': t,
        'normalizedTitle': nt,
        'videoUrl': u,
        'normalizedUrl': nu,
        'category': cat,
        'normalizedCategory': cat.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _titleCtrlFor(unitId).clear();
      _urlCtrlFor(unitId).clear();
      _lessonCategory[unitId] = null;
      setState(() {});
      _toast(context, 'Lesson added', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to add lesson', icon: Icons.error_outline);
    }
  }

  Future<void> _editLesson(String unitId, String lessonId, String title,
      String url, String? cat) async {
    final t = TextEditingController(text: title);
    final u = TextEditingController(text: url);
    String category = (cat ?? '').trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit lesson'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: t,
                    decoration: const InputDecoration(
                        labelText: 'Title (e.g. A, B, P/Q)')),
                TextField(
                    controller: u,
                    decoration: const InputDecoration(
                        labelText: 'Video URL (YouTube)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category.isEmpty ? null : category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'english', child: Text('English')),
                    DropdownMenuItem(value: 'amharic', child: Text('Amharic')),
                  ],
                  onChanged: (v) => setS(() => category = v ?? ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final nt = t.text.trim();
    final nu = u.text.trim();
    if (nt.isEmpty) {
      _toast(context, 'Lesson title is required', icon: Icons.error_outline);
      return;
    }
    if (!_looksLikeYoutubeUrl(nu)) {
      _toast(context, 'Enter a valid YouTube URL', icon: Icons.error_outline);
      return;
    }
    if (category.isEmpty) {
      _toast(context, 'Select a category', icon: Icons.error_outline);
      return;
    }

    final col = _units.doc(unitId).collection('lessons');
    final ntLower = nt.toLowerCase(), nuLower = nu.toLowerCase();

    final tDup =
        await col.where('normalizedTitle', isEqualTo: ntLower).limit(1).get();
    if (tDup.docs.isNotEmpty && tDup.docs.first.id != lessonId) {
      _toast(context, 'Another lesson already uses that title',
          icon: Icons.info_outline);
      return;
    }
    final uDup =
        await col.where('normalizedUrl', isEqualTo: nuLower).limit(1).get();
    if (uDup.docs.isNotEmpty && uDup.docs.first.id != lessonId) {
      _toast(context, 'Another lesson already uses that URL',
          icon: Icons.info_outline);
      return;
    }

    try {
      await col.doc(lessonId).update({
        'title': nt,
        'normalizedTitle': ntLower,
        'videoUrl': nu,
        'normalizedUrl': nuLower,
        'category': category,
        'normalizedCategory': category.toLowerCase(),
      });
      _toast(context, 'Updated', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to update', icon: Icons.error_outline);
    }
  }

  Future<void> _deleteLesson(
      String unitId, String lessonId, String title) async {
    final ok = await _confirm(context,
        title: 'Delete lesson "$title"?',
        message: 'This will remove the lesson from this unit.');
    if (!ok) return;
    try {
      await _units.doc(unitId).collection('lessons').doc(lessonId).delete();
      _toast(context, 'Lesson deleted', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to delete', icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Pad(
      title: 'Lessons • Units & Items',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _units.orderBy('createdAt').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final docs = snap.data?.docs ?? [];

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: 1 + docs.length, // Add-unit card + each unit
            itemBuilder: (context, index) {
              // Add unit card
              if (index == 0) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: TextField(
                            controller: _unitName,
                            decoration: const InputDecoration(
                              labelText: 'Unit name (e.g. Unit 1)',
                              helperText: 'Create a new unit',
                            ),
                          ),
                        ),
                        DropdownButton<String>(
                          value: _unitCategory,
                          hint: const Text('Select category'),
                          items: const [
                            DropdownMenuItem(
                                value: 'english', child: Text('English')),
                            DropdownMenuItem(
                                value: 'amharic', child: Text('Amharic')),
                          ],
                          onChanged: (v) => setState(() => _unitCategory = v),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _addUnit,
                          icon: const Icon(Icons.add),
                          label: const Text('Add unit'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No units yet')),
                );
              }

              final i = index - 1;
              final unit = docs[i];
              final name = (unit.data()['name'] ?? 'Unit').toString();
              final cat = (unit.data()['category'] ?? '—').toString();
              final expanded = _expandedIndex == i;

              // Narrow-safe add-lesson row
              Widget addLessonRow(BoxConstraints cst) {
                final isWide = cst.maxWidth > 620;

                final titleFieldCore = Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: TextField(
                    controller: _titleCtrlFor(unit.id),
                    scrollPadding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 160,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Lesson title (A, B, P/Q)',
                      helperText: 'Required',
                    ),
                  ),
                );

                final urlFieldCore = Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: TextField(
                    controller: _urlCtrlFor(unit.id),
                    scrollPadding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 160,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Video URL (YouTube)',
                      helperText: 'No duplicates',
                    ),
                  ),
                );

                final categoryDrop = Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: DropdownButton<String>(
                    value: _lessonCategory[unit.id],
                    hint: const Text('Category'),
                    items: const [
                      DropdownMenuItem(
                          value: 'english', child: Text('English')),
                      DropdownMenuItem(
                          value: 'amharic', child: Text('Amharic')),
                    ],
                    onChanged: (v) =>
                        setState(() => _lessonCategory[unit.id] = v),
                  ),
                );

                final addBtn = Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.tonalIcon(
                    onPressed: () => _addLessonTo(unit.id),
                    icon: const Icon(Icons.add_link),
                    label: const Text('Add lesson'),
                  ),
                );

                if (isWide) {
                  return Row(children: [
                    Expanded(flex: 4, child: titleFieldCore),
                    Expanded(flex: 6, child: urlFieldCore),
                    categoryDrop,
                    addBtn,
                  ]);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleFieldCore,
                    urlFieldCore,
                    categoryDrop,
                    addBtn
                  ],
                );
              }

              // Lessons list as a simple Column (no ListView)
              Widget lessonsList() {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _units
                      .doc(unit.id)
                      .collection('lessons')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (_, lsnap) {
                    final ldocs = lsnap.data?.docs ?? [];
                    if (lsnap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (ldocs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No lessons yet'),
                      );
                    }
                    return Column(
                      children: [
                        for (var j = 0; j < ldocs.length; j++) ...[
                          if (j > 0) const Divider(height: 1),
                          Builder(builder: (__) {
                            final d = ldocs[j];
                            final data = d.data();
                            final lessonCat =
                                (data['category'] ?? '—').toString();
                            return ListTile(
                              key: ValueKey('lesson-${d.id}'),
                              dense: true,
                              leading: CircleAvatar(child: Text('${j + 1}')),
                              title: Text(
                                (data['title'] ?? '').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${(data['videoUrl'] ?? '').toString()}  •  ${lessonCat.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit lesson',
                                    onPressed: () => _editLesson(
                                      unit.id,
                                      d.id,
                                      (data['title'] ?? '').toString(),
                                      (data['videoUrl'] ?? '').toString(),
                                      (data['category'] ?? '').toString(),
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete lesson',
                                    onPressed: () => _deleteLesson(
                                      unit.id,
                                      d.id,
                                      (data['title'] ?? '').toString(),
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    );
                  },
                );
              }

              return ExpansionTile(
                key: ValueKey(unit.id),
                maintainState: true,
                initiallyExpanded: expanded,
                onExpansionChanged: (e) =>
                    setState(() => _expandedIndex = e ? i : null),
                title: Text('$name (${cat.toUpperCase()})'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Edit unit name',
                      onPressed: () => _renameUnit(unit.id, name, cat),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete unit',
                      onPressed:
                          _busy ? null : () => _deleteUnit(unit.id, name),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  LayoutBuilder(builder: (_, c) => addLessonRow(c)),
                  const SizedBox(height: 4),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.topCenter,
                    child: lessonsList(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/* ==========================================
   USERS (real Auth via secondary app) + docs
   ========================================== */

enum UserRole { admin, client }

class UsersAdmin extends StatefulWidget {
  const UsersAdmin({super.key});
  @override
  State<UsersAdmin> createState() => _UsersAdminState();
}

class _UsersAdminState extends State<UsersAdmin> {
  final _users = FirebaseFirestore.instance.collection('users');
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _hint = TextEditingController();
  UserRole _role = UserRole.client;
  bool _busy = false;

  Future<void> _addUser() async {
    final name = _name.text.trim(),
        email = _email.text.trim(),
        pw = _password.text,
        hint = _hint.text.trim();

    if (name.isEmpty) {
      _toast(context, 'Name is required', icon: Icons.error_outline);
      return;
    }
    if (!_looksLikeEmail(email)) {
      _toast(context, 'Enter a valid email', icon: Icons.error_outline);
      return;
    }
    if (pw.length < 6) {
      _toast(context, 'Password must be at least 6 chars',
          icon: Icons.error_outline);
      return;
    }
    if (hint.isEmpty) {
      _toast(context, 'Recovery hint is required', icon: Icons.error_outline);
      return;
    }

    try {
      setState(() => _busy = true);
      final primary = Firebase.app();
      final tmp = await Firebase.initializeApp(
        name: 'admin-helper-${DateTime.now().microsecondsSinceEpoch}()',
        options: primary.options,
      );
      final tmpAuth = FirebaseAuth.instanceFor(app: tmp);

      final cred = await tmpAuth.createUserWithEmailAndPassword(
          email: email, password: pw);
      await cred.user?.updateDisplayName(name);
      final uid = cred.user?.uid;

      await _users.doc(uid).set({
        'name': name,
        'email': email,
        'hint': hint,
        'userType': _role == UserRole.admin ? 'Admin' : 'User',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await tmpAuth.signOut();
      await tmp.delete();

      _name.clear();
      _email.clear();
      _password.clear();
      _hint.clear();
      _role = UserRole.client;
      setState(() {});

      _toast(context, 'User created (Auth + Firestore)',
          icon: Icons.check_circle_outline);
    } on FirebaseAuthException catch (e) {
      _toast(context, e.message ?? 'Failed to create user',
          icon: Icons.error_outline);
    } catch (_) {
      _toast(context, 'Failed to create user', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String id, String name) async {
    final ok = await _confirm(context,
        title: 'Delete user "$name"?',
        message: 'This removes the Firestore profile only.');
    if (!ok) return;
    try {
      setState(() => _busy = true);
      await _users.doc(id).delete();
      _toast(context, 'User document deleted', icon: Icons.check_circle);
    } catch (_) {
      _toast(context, 'Failed to delete', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Pad(
      title: 'Users • Add & Manage',
      // Whole page scrolls
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _users.orderBy('createdAt', descending: true).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            helperText: 'Full name',
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: TextField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            helperText: 'name@example.com',
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: TextField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            helperText: 'Min 6 chars',
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: TextField(
                          controller: _hint,
                          decoration: const InputDecoration(
                            labelText: 'Recovery hint',
                            helperText: 'Used in reset flow',
                          ),
                        ),
                      ),
                      DropdownButton<UserRole>(
                        value: _role,
                        items: const [
                          DropdownMenuItem(
                              value: UserRole.client, child: Text('Client')),
                          DropdownMenuItem(
                              value: UserRole.admin, child: Text('Admin')),
                        ],
                        onChanged: (v) =>
                            setState(() => _role = v ?? UserRole.client),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _addUser,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add user'),
                      ),
                    ],
                  ),
                ),
              ),
              if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()))
              else if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No users')),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final id = docs[i].id;
                    final name = (d['name'] ?? '').toString();
                    final email = (d['email'] ?? '').toString();
                    final role = (d['userType'] ?? 'User').toString();
                    final hint = (d['hint'] ?? '').toString();
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(role == 'Admin'
                            ? Icons.admin_panel_settings
                            : Icons.person),
                      ),
                      title: Text(name.isEmpty ? '(no name)' : name),
                      subtitle: Text(
                          '$email  •  ${role.toUpperCase()}${hint.isNotEmpty ? '  •  hint: $hint' : ''}'),
                      trailing: IconButton(
                        tooltip: 'Delete document',
                        onPressed: _busy ? null : () => _delete(id, name),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/* =============================================
   VOCABULARY (image + word/sentence) • /vocab
   ============================================= */

class VocabularyAdmin extends StatefulWidget {
  const VocabularyAdmin({super.key});
  @override
  State<VocabularyAdmin> createState() => _VocabularyAdminState();
}

class _VocabularyAdminState extends State<VocabularyAdmin> {
  final _vocab = FirebaseFirestore.instance.collection('vocab');
  Uint8List? _image;
  final _text = TextEditingController();
  bool _busy = false;
  static const int _maxBytes = 400 * 1024;

  Future<void> _pickImage() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (res != null && res.files.single.bytes != null) {
      final b = res.files.single.bytes!;
      if (b.length > _maxBytes) {
        _toast(context, 'Pick a smaller picture (≤ 400 KB).',
            icon: Icons.error_outline);
        return;
      }
      setState(() => _image = b);
    }
  }

  Future<void> _save() async {
    final label = _text.text.trim();
    if (_image == null) {
      _toast(context, 'Upload an image', icon: Icons.error_outline);
      return;
    }
    if (label.isEmpty) {
      _toast(context, 'Enter a word or sentence', icon: Icons.error_outline);
      return;
    }
    try {
      setState(() => _busy = true);
      await _vocab.add({
        'imageBase64': base64Encode(_image!),
        'text': label,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _image = null;
      _text.clear();
      setState(() {});
      _toast(context, 'Vocabulary saved', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to save', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(String id, Map<String, dynamic> data) async {
    final label = TextEditingController(text: (data['text'] ?? '').toString());
    Uint8List? img;
    final b64 = (data['imageBase64'] ?? '').toString();
    if (b64.isNotEmpty) {
      try {
        img = base64Decode(b64);
      } catch (_) {
        img = null;
      }
    }

    Future<void> pickInside() async {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: true);
      if (res != null && res.files.single.bytes != null) {
        final b = res.files.single.bytes!;
        if (b.length > _maxBytes) {
          _toast(context, 'Pick a smaller picture (≤ 400 KB).',
              icon: Icons.error_outline);
          return;
        }
        img = b;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit vocabulary'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                if (img != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(img!,
                        width: 220, height: 120, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await pickInside();
                    setS(() {});
                  },
                  icon: const Icon(Icons.image),
                  label: const Text('Replace image'),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: label,
                    decoration:
                        const InputDecoration(labelText: 'Word/Sentence')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      setState(() => _busy = true);
      final update = {'text': label.text.trim()};
      if (img != null) update['imageBase64'] = base64Encode(img!);
      await _vocab.doc(id).update(update);
      _toast(context, 'Vocabulary updated', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to update', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm(context,
        title: 'Delete vocabulary item?',
        message: 'This will remove the item permanently.');
    if (!ok) return;
    try {
      setState(() => _busy = true);
      await _vocab.doc(id).delete();
      _toast(context, 'Deleted', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to delete', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _Pad(
      title: 'Vocabulary • Image + Word/Sentence',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _vocab.orderBy('createdAt', descending: true).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                          onPressed: _busy ? null : _pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text('Upload image')),
                      if (_image != null)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: cs.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Image.memory(_image!,
                              width: 120, height: 80, fit: BoxFit.cover),
                        ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: TextField(
                          controller: _text,
                          decoration: const InputDecoration(
                            labelText: 'Word or sentence',
                            helperText: 'Shown to clients for training',
                          ),
                        ),
                      ),
                      FilledButton.icon(
                          onPressed: _busy ? null : _save,
                          icon: const Icon(Icons.save),
                          label: const Text('Save')),
                    ],
                  ),
                ),
              ),
              if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()))
              else if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No vocabulary yet')),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320, // responsive cards
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 4 / 3,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final data = d.data();
                    final txt = (data['text'] ?? '').toString();
                    Uint8List? img;
                    final b64 = (data['imageBase64'] ?? '').toString();
                    if (b64.isNotEmpty) {
                      try {
                        img = base64Decode(b64);
                      } catch (_) {
                        img = null;
                      }
                    }
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _edit(d.id, data),
                        child: Column(
                          children: [
                            Expanded(
                              child: img != null
                                  ? Image.memory(img,
                                      width: double.infinity, fit: BoxFit.cover)
                                  : Container(
                                      color: cs.surfaceVariant,
                                      child: const Icon(Icons.touch_app_rounded,
                                          size: 36),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      txt,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => _edit(d.id, data),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _delete(d.id),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/* =============================
   QUIZZES (image + choices)
   ============================= */

class QuizzesAdmin extends StatefulWidget {
  const QuizzesAdmin({super.key});
  @override
  State<QuizzesAdmin> createState() => _QuizzesAdminState();
}

class _QuizzesAdminState extends State<QuizzesAdmin> {
  final _quizzes = FirebaseFirestore.instance.collection('quizzes');
  Uint8List? _image;
  final _a = TextEditingController(),
      _b = TextEditingController(),
      _c = TextEditingController(),
      _d = TextEditingController();
  int _correct = 0;
  bool _busy = false;
  static const int _maxBytes = 400 * 1024;

  Future<void> _pickImage() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (res != null && res.files.single.bytes != null) {
      final b = res.files.single.bytes!;
      if (b.length > _maxBytes) {
        _toast(context, 'Pick a smaller picture (≤ 400 KB).',
            icon: Icons.error_outline);
        return;
      }
      setState(() => _image = b);
    }
  }

  Future<void> _save() async {
    if (_image == null) {
      _toast(context, 'Please upload an image', icon: Icons.error_outline);
      return;
    }
    final a = _a.text.trim(),
        b = _b.text.trim(),
        c = _c.text.trim(),
        d = _d.text.trim();
    if ([a, b, c, d].any((e) => e.isEmpty)) {
      _toast(context, 'All four choices are required',
          icon: Icons.error_outline);
      return;
    }
    try {
      setState(() => _busy = true);
      await _quizzes.add({
        'imageBase64': base64Encode(_image!),
        'choices': [a, b, c, d],
        'correctIndex': _correct,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _image = null;
      _a.clear();
      _b.clear();
      _c.clear();
      _d.clear();
      setState(() {});
      _toast(context, 'Quiz saved', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to save quiz', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(String id, Map<String, dynamic> data) async {
    final choices = (data['choices'] as List).map((e) => e.toString()).toList();
    final correct = (data['correctIndex'] ?? 0) as int;
    final b64 = (data['imageBase64'] ?? '').toString();

    Uint8List? existing;
    if (b64.isNotEmpty) {
      try {
        existing = base64Decode(b64);
      } catch (_) {}
    }

    Uint8List? newImage = existing;
    final a = TextEditingController(text: choices[0]),
        b = TextEditingController(text: choices[1]),
        c = TextEditingController(text: choices[2]),
        d = TextEditingController(text: choices[3]);
    int correctIdx = correct;

    Future<void> pickInside() async {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: true);
      if (res != null && res.files.single.bytes != null) {
        final bb = res.files.single.bytes!;
        if (bb.length > _maxBytes) {
          _toast(context, 'Pick a smaller picture (≤ 400 KB).',
              icon: Icons.error_outline);
          return;
        }
        newImage = bb;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit quiz'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                if (newImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(newImage!,
                        width: 220, height: 120, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: () async {
                      await pickInside();
                      setS(() {});
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('Replace image')),
                const SizedBox(height: 12),
                TextField(
                    controller: a,
                    decoration: const InputDecoration(labelText: 'Choice A')),
                TextField(
                    controller: b,
                    decoration: const InputDecoration(labelText: 'Choice B')),
                TextField(
                    controller: c,
                    decoration: const InputDecoration(labelText: 'Choice C')),
                TextField(
                    controller: d,
                    decoration: const InputDecoration(labelText: 'Choice D')),
                const SizedBox(height: 8),
                DropdownButton<int>(
                  value: correctIdx,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Correct: A')),
                    DropdownMenuItem(value: 1, child: Text('Correct: B')),
                    DropdownMenuItem(value: 2, child: Text('Correct: C')),
                    DropdownMenuItem(value: 3, child: Text('Correct: D')),
                  ],
                  onChanged: (v) => setS(() => correctIdx = v ?? 0),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      setState(() => _busy = true);
      final update = {
        'choices': [a.text.trim(), b.text.trim(), c.text.trim(), d.text.trim()],
        'correctIndex': correctIdx,
      };
      if (newImage != null) update['imageBase64'] = base64Encode(newImage!);
      await _quizzes.doc(id).update(update);
      _toast(context, 'Quiz updated', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to update quiz', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm(context,
        title: 'Delete this quiz?',
        message: 'This will remove the quiz item permanently.');
    if (!ok) return;
    try {
      setState(() => _busy = true);
      await _quizzes.doc(id).delete();
      _toast(context, 'Quiz deleted', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to delete quiz', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _Pad(
      title: 'Quizzes • Image + Choices',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _quizzes.orderBy('createdAt', descending: true).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                          onPressed: _busy ? null : _pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text('Upload image')),
                      if (_image != null)
                        Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: cs.outlineVariant),
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.all(6),
                          child: Image.memory(_image!,
                              width: 120, height: 80, fit: BoxFit.cover),
                        ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: TextField(
                          controller: _a,
                          decoration: const InputDecoration(
                              labelText: 'Choice A', helperText: 'Required'),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: TextField(
                          controller: _b,
                          decoration: const InputDecoration(
                              labelText: 'Choice B', helperText: 'Required'),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: TextField(
                          controller: _c,
                          decoration: const InputDecoration(
                              labelText: 'Choice C', helperText: 'Required'),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: TextField(
                          controller: _d,
                          decoration: const InputDecoration(
                              labelText: 'Choice D', helperText: 'Required'),
                        ),
                      ),
                      DropdownButton<int>(
                          value: _correct,
                          items: const [
                            DropdownMenuItem(
                                value: 0, child: Text('Correct: A')),
                            DropdownMenuItem(
                                value: 1, child: Text('Correct: B')),
                            DropdownMenuItem(
                                value: 2, child: Text('Correct: C')),
                            DropdownMenuItem(
                                value: 3, child: Text('Correct: D')),
                          ],
                          onChanged: (v) => setState(() => _correct = v ?? 0)),
                      FilledButton.icon(
                          onPressed: _busy ? null : _save,
                          icon: const Icon(Icons.save),
                          label: const Text('Save quiz')),
                    ],
                  ),
                ),
              ),
              if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()))
              else if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No quizzes yet')),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final data = d.data();
                    final b64 = (data['imageBase64'] ?? '').toString();
                    Uint8List bytes = Uint8List(0);
                    if (b64.isNotEmpty) {
                      try {
                        bytes = base64Decode(b64);
                      } catch (_) {}
                    }
                    final choices = (data['choices'] as List)
                        .map((e) => e.toString())
                        .toList();
                    final correct = (data['correctIndex'] ?? 0) as int;

                    return ListTile(
                      leading: bytes.isNotEmpty
                          ? CircleAvatar(backgroundImage: MemoryImage(bytes))
                          : const CircleAvatar(
                              child: Icon(Icons.image_not_supported)),
                      title: const Text('What does this sign mean?'),
                      subtitle: Text(
                        'A) ${choices[0]} • B) ${choices[1]} • C) ${choices[2]} • D) ${choices[3]} — '
                        'Correct: ${String.fromCharCode(65 + correct)}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: _busy ? null : () => _edit(d.id, data),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: _busy ? null : () => _delete(d.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/* =============================
   SETTINGS + ADMIN PROFILE
   ============================= */

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});
  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  final _nameCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = u?.displayName ?? '';
    _loadHint(u?.uid);
  }

  Future<void> _loadHint(String? uid) async {
    if (uid == null) return;
    final d =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    _hintCtrl.text = (d.data()?['hint'] ?? '').toString();
    if (mounted) setState(() {});
  }

  Future<void> _saveProfile() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final name = _nameCtrl.text.trim();
    final hint = _hintCtrl.text.trim();
    if (name.isEmpty) {
      _toast(context, 'Name required', icon: Icons.error_outline);
      return;
    }
    try {
      setState(() => _busy = true);
      await u.updateDisplayName(name);
      final users = FirebaseFirestore.instance.collection('users').doc(u.uid);
      final snap = await users.get();
      if (snap.exists) {
        await users.update({'name': name, 'hint': hint});
      } else {
        await users.set({
          'name': name,
          'email': u.email ?? '',
          'hint': hint,
          'userType': 'Admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      _toast(context, 'Profile updated', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to update profile', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteMyAccount() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final ok = await _confirm(context,
        title: 'Delete your account?',
        message:
            'This permanently deletes your authentication account and your profile document.',
        confirmText: 'Delete account');
    if (!ok) return;
    try {
      setState(() => _busy = true);
      final uid = u.uid;
      await u.delete();
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      if (!mounted) return;
      _toast(context, 'Account deleted', icon: Icons.check_circle_outline);
      // Safe navigation after destructive action
      context.safeGo('/auth');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _toast(context, 'For security, sign in again, then retry delete.',
            icon: Icons.info_outline);
      } else {
        _toast(context, e.message ?? 'Failed to delete', icon: Icons.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeControllerProvider.of(context);
    final u = FirebaseAuth.instance.currentUser;
    final email = u?.email ?? '';

    return _Pad(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (ctx, c) {
                  final isWide = c.maxWidth >= 640;

                  final avatar = CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage:
                        (u?.photoURL != null && u!.photoURL!.isNotEmpty)
                            ? NetworkImage(u.photoURL!)
                            : null,
                    child: (u?.photoURL == null || u!.photoURL!.isEmpty)
                        ? const Icon(Icons.person, size: 28)
                        : null,
                  );

                  final form = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin profile',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          helperText: 'Shown across the app',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        readOnly: true,
                        controller: TextEditingController(text: email),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _hintCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Recovery hint',
                          helperText:
                              'Used for password reset verification screens',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isWide)
                        Row(children: [
                          FilledButton.icon(
                            onPressed: _busy ? null : _saveProfile,
                            icon: const Icon(Icons.save),
                            label: const Text('Save changes'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _deleteMyAccount,
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: const Text('Delete account'),
                          ),
                        ])
                      else
                        Column(children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _saveProfile,
                              icon: const Icon(Icons.save),
                              label: const Text('Save changes'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _deleteMyAccount,
                              icon: const Icon(Icons.delete_forever_outlined),
                              label: const Text('Delete account'),
                            ),
                          ),
                        ]),
                    ],
                  );

                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            avatar,
                            const SizedBox(width: 16),
                            Expanded(child: form),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: avatar),
                            const SizedBox(height: 12),
                            form,
                          ],
                        );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(title: Text('Theme')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('System'),
                  selected: theme.mode == ThemeMode.system,
                  onSelected: (_) =>
                      setState(() => theme.setMode(ThemeMode.system)),
                ),
                ChoiceChip(
                  label: const Text('Light'),
                  selected: theme.mode == ThemeMode.light,
                  onSelected: (_) =>
                      setState(() => theme.setMode(ThemeMode.light)),
                ),
                ChoiceChip(
                  label: const Text('Dark'),
                  selected: theme.mode == ThemeMode.dark,
                  onSelected: (_) =>
                      setState(() => theme.setMode(ThemeMode.dark)),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          const ListTile(title: Text('Language'), subtitle: Text('English')),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      try {
                        setState(() => _busy = true);
                        await FirebaseAuth.instance.signOut();
                        if (!mounted) return;
                        _toast(context, 'Signed out',
                            icon: Icons.logout_outlined);
                        // Take admin to login page safely
                        context.safeGo('/auth');
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

/* =============================
   MESSAGES (from Contact Us)
   ============================= */

class MessagesAdmin extends StatefulWidget {
  const MessagesAdmin({super.key});
  @override
  State<MessagesAdmin> createState() => _MessagesAdminState();
}

class _MessagesAdminState extends State<MessagesAdmin> {
  final _col = FirebaseFirestore.instance.collection('contact_messages');
  final _searchCtrl = TextEditingController();
  bool _onlyOpen = false; // show only status=open

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus(String id, String current) async {
    final next = (current == 'resolved') ? 'open' : 'resolved';
    try {
      await _col.doc(id).update({'status': next});
      if (mounted) _toast(context, 'Marked as $next', icon: Icons.flag_circle);
    } catch (_) {
      if (mounted)
        _toast(context, 'Failed to update', icon: Icons.error_outline);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm(
      context,
      title: 'Delete this message?',
      message: 'This cannot be undone.',
    );
    if (!ok) return;
    try {
      await _col.doc(id).delete();
      if (mounted) _toast(context, 'Deleted', icon: Icons.check_circle_outline);
    } catch (_) {
      if (mounted)
        _toast(context, 'Failed to delete', icon: Icons.error_outline);
    }
  }

  String _fmtDate(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate().toLocal();
    // Short, readable
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _Pad(
      title: 'Messages • Contact form',
      child: Column(
        children: [
          // --- Filters / Search ---
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Search (name, email, message)',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Only open'),
                    selected: _onlyOpen,
                    onSelected: (v) => setState(() => _onlyOpen = v),
                  ),
                ],
              ),
            ),
          ),

          // --- List (Stream) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _col.orderBy('createdAt', descending: true).snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                // client-side filter: search + status
                final q = _searchCtrl.text.trim().toLowerCase();
                final filtered = docs.where((d) {
                  final m = d.data();
                  final status =
                      (m['status'] ?? 'open').toString().toLowerCase();
                  if (_onlyOpen && status != 'open') return false;

                  if (q.isEmpty) return true;
                  final name = (m['name'] ?? '').toString().toLowerCase();
                  final email = (m['email'] ?? '').toString().toLowerCase();
                  final msg = (m['message'] ?? '').toString().toLowerCase();
                  return name.contains(q) ||
                      email.contains(q) ||
                      msg.contains(q);
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    final id = d.id;
                    final m = d.data();

                    final name = (m['name'] ?? '').toString();
                    final email = (m['email'] ?? '').toString();
                    final message = (m['message'] ?? '').toString();
                    final createdAt = d.data()['createdAt'] as Timestamp?;
                    final status = (m['status'] ?? 'open').toString();

                    final initials = (() {
                      final base = name.isNotEmpty ? name : email;
                      if (base.isEmpty) return 'U';
                      final parts = base.trim().split(RegExp(r'\s+'));
                      return parts
                          .take(2)
                          .map((p) => p[0].toUpperCase())
                          .join();
                    })();

                    final statusColor = status == 'resolved'
                        ? cs.primaryContainer
                        : cs.tertiaryContainer;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor,
                        child: Text(initials),
                      ),
                      title: Text(
                        name.isNotEmpty
                            ? name
                            : (email.isNotEmpty ? email : '(no name)'),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${email.isNotEmpty ? email : '—'}  •  ${_fmtDate(createdAt)}  •  ${status.toUpperCase()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: status == 'resolved'
                                ? 'Mark open'
                                : 'Mark resolved',
                            onPressed: () => _toggleStatus(id, status),
                            icon: Icon(
                              status == 'resolved'
                                  ? Icons.flag_outlined
                                  : Icons.flag_circle_outlined,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _delete(id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================
   Shared page wrapper
   ============================ */
class _Pad extends StatelessWidget {
  const _Pad({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            // child is always a single scrollable (ListView/CustomScrollView)
            Expanded(child: child),
          ],
        ),
      );
}
