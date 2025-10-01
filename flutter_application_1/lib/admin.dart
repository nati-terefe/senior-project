// lib/admin.dart
import 'dart:typed_data';
import 'dart:convert'; // base64
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'theme_controller.dart';

/* ============================
   Snackbars & small helpers
   ============================ */

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

void _toast(BuildContext context, String msg, {IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(_snack(msg, icon: icon));
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Delete',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, true),
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

bool _looksLikeEmail(String email) {
  return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email.trim());
}

/* ============================
   ADMIN: Responsive container
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
      QuizzesAdmin(),
      AdminSettings(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        final rail = NavigationRail(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(
                icon: Icon(Icons.menu_book), label: Text('Lessons')),
            NavigationRailDestination(
                icon: Icon(Icons.people), label: Text('Users')),
            NavigationRailDestination(
                icon: Icon(Icons.quiz), label: Text('Quizzes')),
            NavigationRailDestination(
                icon: Icon(Icons.settings), label: Text('Settings')),
          ],
        );

        final body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: pages[_tab],
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Panel'),
            scrolledUnderElevation: 0,
          ),
          body: isWide
              ? Row(
                  children: [
                    rail,
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
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
                        icon: Icon(Icons.quiz), label: 'Quizzes'),
                    NavigationDestination(
                        icon: Icon(Icons.settings), label: 'Settings'),
                  ],
                ),
        );
      },
    );
  }
}

/* ============================
   LESSONS: Units + Items (Firestore)
   /units
     - name, createdAt
   /units/{id}/lessons
     - title, videoUrl, createdAt
   ============================ */

class LessonsAdmin extends StatefulWidget {
  const LessonsAdmin({super.key});

  @override
  State<LessonsAdmin> createState() => _LessonsAdminState();
}

class _LessonsAdminState extends State<LessonsAdmin> {
  final _units = FirebaseFirestore.instance.collection('units');
  final _unitName = TextEditingController(text: 'Unit 1');

  final _itemTitle = TextEditingController();
  final _itemUrl = TextEditingController();

  int? _expandedIndex;
  bool _busy = false;

  Future<void> _addUnit() async {
    final name = _unitName.text.trim();
    if (name.isEmpty) {
      _toast(context, 'Unit name is required', icon: Icons.error_outline);
      return;
    }
    try {
      await _units.add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _unitName.text = 'Unit ${DateTime.now().millisecondsSinceEpoch % 1000}';
      _toast(context, 'Unit added', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to add unit', icon: Icons.error_outline);
    }
  }

  Future<void> _renameUnit(String unitId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit unit name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Unit name'),
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
    );
    if (ok != true) return;

    final newName = controller.text.trim();
    if (newName.isEmpty) {
      _toast(context, 'Unit name cannot be empty', icon: Icons.error_outline);
      return;
    }
    try {
      await _units.doc(unitId).update({'name': newName});
      _toast(context, 'Updated', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to update', icon: Icons.error_outline);
    }
  }

  Future<void> _deleteUnit(String unitId, String name) async {
    final ok = await _confirm(
      context,
      title: 'Delete "$name"?',
      message: 'This will remove the unit and all its lessons.',
    );
    if (!ok) return;

    try {
      setState(() => _busy = true);
      final lessons = await _units.doc(unitId).collection('lessons').get();
      for (final d in lessons.docs) {
        await d.reference.delete();
      }
      await _units.doc(unitId).delete();
      _toast(context, 'Unit deleted', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to delete', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addLessonTo(String unitId) async {
    final t = _itemTitle.text.trim();
    final u = _itemUrl.text.trim();

    if (t.isEmpty) {
      _toast(context, 'Lesson title is required', icon: Icons.error_outline);
      return;
    }
    if (!_looksLikeYoutubeUrl(u)) {
      _toast(context, 'Enter a valid YouTube URL', icon: Icons.error_outline);
      return;
    }

    try {
      await _units.doc(unitId).collection('lessons').add({
        'title': t,
        'videoUrl': u,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _itemTitle.clear();
      _itemUrl.clear();
      _toast(context, 'Lesson added', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to add lesson', icon: Icons.error_outline);
    }
  }

  Future<void> _editLesson(
      String unitId, String lessonId, String title, String url) async {
    final t = TextEditingController(text: title);
    final u = TextEditingController(text: url);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit lesson'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: t,
                decoration:
                    const InputDecoration(labelText: 'Title (e.g. A, B, P/Q)')),
            TextField(
                controller: u,
                decoration:
                    const InputDecoration(labelText: 'Video URL (YouTube)')),
          ],
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
    try {
      await _units
          .doc(unitId)
          .collection('lessons')
          .doc(lessonId)
          .update({'title': nt, 'videoUrl': nu});
      _toast(context, 'Updated', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to update', icon: Icons.error_outline);
    }
  }

  Future<void> _deleteLesson(
      String unitId, String lessonId, String title) async {
    final ok = await _confirm(
      context,
      title: 'Delete lesson "$title"?',
      message: 'This will remove the lesson from this unit.',
    );
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
      child: Column(
        children: [
          // Add Unit
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _unitName,
                      decoration: const InputDecoration(
                        labelText: 'Unit name (e.g. Unit 1)',
                        helperText: 'Create a new unit',
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _addUnit,
                    icon: const Icon(Icons.add),
                    label: const Text('Add unit'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Units & lessons list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _units.orderBy('createdAt').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No units yet'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final unit = docs[i];
                    final name = (unit.data()['name'] ?? 'Unit').toString();
                    final expanded = _expandedIndex == i;
                    return ExpansionTile(
                      key: ValueKey(unit.id),
                      initiallyExpanded: expanded,
                      onExpansionChanged: (e) =>
                          setState(() => _expandedIndex = e ? i : null),
                      title: Text(name),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Edit unit name',
                            onPressed: () => _renameUnit(unit.id, name),
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
                        // Add lesson to this unit
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 200,
                              child: TextField(
                                controller: _itemTitle,
                                decoration: const InputDecoration(
                                  labelText: 'Lesson title (A, B, P/Q)',
                                  helperText: 'Required',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 360,
                              child: TextField(
                                controller: _itemUrl,
                                decoration: const InputDecoration(
                                  labelText: 'Video URL (YouTube)',
                                  helperText: 'Paste a valid YouTube URL',
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _addLessonTo(unit.id),
                              icon: const Icon(Icons.add_link),
                              label: const Text('Add lesson'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Lessons list
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _units
                              .doc(unit.id)
                              .collection('lessons')
                              .orderBy('createdAt')
                              .snapshots(),
                          builder: (_, lsnap) {
                            final ldocs = lsnap.data?.docs ?? [];
                            if (ldocs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No lessons yet'),
                              );
                            }
                            return Column(
                              children: [
                                for (var j = 0; j < ldocs.length; j++)
                                  ListTile(
                                    dense: true,
                                    leading:
                                        CircleAvatar(child: Text('${j + 1}')),
                                    title: Text(
                                      (ldocs[j].data()['title'] ?? '')
                                          .toString(),
                                    ),
                                    subtitle: Text(
                                      (ldocs[j].data()['videoUrl'] ?? '')
                                          .toString(),
                                    ),
                                    trailing: Wrap(
                                      spacing: 4,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit lesson',
                                          onPressed: () => _editLesson(
                                            unit.id,
                                            ldocs[j].id,
                                            (ldocs[j].data()['title'] ?? '')
                                                .toString(),
                                            (ldocs[j].data()['videoUrl'] ?? '')
                                                .toString(),
                                          ),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete lesson',
                                          onPressed: () => _deleteLesson(
                                            unit.id,
                                            ldocs[j].id,
                                            (ldocs[j].data()['title'] ?? '')
                                                .toString(),
                                          ),
                                          icon:
                                              const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
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
   USERS: Firestore list/add/delete
   Adds HINT field (helper shown).
   Deleting from Admin deletes only the Firestore doc and first flags
   deletionRequested:true.
   ============================ */

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
  final _password = TextEditingController(); // kept for your flow
  final _hint = TextEditingController();
  UserRole _role = UserRole.client;
  bool _busy = false;

  Future<void> _addUser() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pw = _password.text; // not used for Auth here, but kept
    final hint = _hint.text.trim();

    if (name.isEmpty) {
      _toast(context, 'Name is required', icon: Icons.error_outline);
      return;
    }
    if (!_looksLikeEmail(email)) {
      _toast(context, 'Enter a valid email', icon: Icons.error_outline);
      return;
    }
    if (pw.isEmpty) {
      _toast(context, 'Password is required', icon: Icons.error_outline);
      return;
    }
    if (hint.isEmpty) {
      _toast(context, 'Recovery hint is required', icon: Icons.error_outline);
      return;
    }

    try {
      setState(() => _busy = true);
      await _users.add({
        'name': name,
        'email': email,
        'hint': hint,
        'userType': _role == UserRole.admin ? 'Admin' : 'User',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _name.clear();
      _email.clear();
      _password.clear();
      _hint.clear();
      _role = UserRole.client;
      setState(() {});
      _toast(context, 'User added (Firestore doc)',
          icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to add user', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String id, String name) async {
    final ok = await _confirm(
      context,
      title: 'Delete user "$name"?',
      message:
          'This removes the Firestore profile (AUTH not removed from client-side).',
    );
    if (!ok) return;
    try {
      setState(() => _busy = true);
      await _users.doc(id).update({'deletionRequested': true});
      await _users.doc(id).delete();
      _toast(context, 'User deleted (doc removed)', icon: Icons.check_circle);
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
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        helperText: 'Full name',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        helperText: 'name@example.com',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        helperText: 'For your records only',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _hint,
                      decoration: const InputDecoration(
                        labelText: 'Recovery hint',
                        helperText: 'Used for password reset verification',
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
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _users.orderBy('createdAt', descending: true).snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No users'));
                }
                return ListView.separated(
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
                        '$email  •  ${role.toUpperCase()}'
                        '${hint.isNotEmpty ? '  •  hint: $hint' : ''}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete (doc only)',
                        onPressed: _busy ? null : () => _delete(id, name),
                        icon: const Icon(Icons.delete_outline),
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
   QUIZZES: Base64 image storage + EDIT & DELETE
   /quizzes
     - imageBase64, choices[4], correctIndex, createdAt
   ============================ */

class QuizzesAdmin extends StatefulWidget {
  const QuizzesAdmin({super.key});

  @override
  State<QuizzesAdmin> createState() => _QuizzesAdminState();
}

class _QuizzesAdminState extends State<QuizzesAdmin> {
  final _quizzes = FirebaseFirestore.instance.collection('quizzes');

  Uint8List? _image;
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _c = TextEditingController();
  final _d = TextEditingController();
  int _correct = 0;
  bool _busy = false;

  static const int _maxBytes = 400 * 1024; // 400KB

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res != null && res.files.single.bytes != null) {
      final bytes = res.files.single.bytes!;
      if (bytes.length > _maxBytes) {
        _toast(context, 'Pick a smaller picture (≤ 400 KB).',
            icon: Icons.error_outline);
        return;
      }
      setState(() => _image = bytes);
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
    if (a.isEmpty || b.isEmpty || c.isEmpty || d.isEmpty) {
      _toast(context, 'All four choices are required',
          icon: Icons.error_outline);
      return;
    }

    try {
      setState(() => _busy = true);
      final base64Str = base64Encode(_image!);

      await _quizzes.add({
        'imageBase64': base64Str,
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
    // Pre-fill
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
    final a = TextEditingController(text: choices[0]);
    final b = TextEditingController(text: choices[1]);
    final c = TextEditingController(text: choices[2]);
    final d = TextEditingController(text: choices[3]);
    int correctIdx = correct;

    Future<void> pickInside() async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (res != null && res.files.single.bytes != null) {
        final bytes = res.files.single.bytes!;
        if (bytes.length > _maxBytes) {
          _toast(context, 'Pick a smaller picture (≤ 400 KB).',
              icon: Icons.error_outline);
          return;
        }
        newImage = bytes;
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
                  label: const Text('Replace image'),
                ),
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
      if (newImage != null) {
        update['imageBase64'] = base64Encode(newImage!);
      }
      await _quizzes.doc(id).update(update);
      _toast(context, 'Quiz updated', icon: Icons.check_circle_outline);
    } catch (_) {
      _toast(context, 'Failed to update quiz', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String quizId) async {
    final ok = await _confirm(
      context,
      title: 'Delete this quiz?',
      message: 'This will remove the quiz item permanently.',
    );
    if (!ok) return;

    try {
      setState(() => _busy = true);
      await _quizzes.doc(quizId).delete();
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
      child: Column(
        children: [
          Card(
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
                    label: const Text('Upload image'),
                  ),
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
                  SizedBox(
                      width: 200,
                      child: TextField(
                          controller: _a,
                          decoration: const InputDecoration(
                            labelText: 'Choice A',
                            helperText: 'Required',
                          ))),
                  SizedBox(
                      width: 200,
                      child: TextField(
                          controller: _b,
                          decoration: const InputDecoration(
                            labelText: 'Choice B',
                            helperText: 'Required',
                          ))),
                  SizedBox(
                      width: 200,
                      child: TextField(
                          controller: _c,
                          decoration: const InputDecoration(
                            labelText: 'Choice C',
                            helperText: 'Required',
                          ))),
                  SizedBox(
                      width: 200,
                      child: TextField(
                          controller: _d,
                          decoration: const InputDecoration(
                            labelText: 'Choice D',
                            helperText: 'Required',
                          ))),
                  DropdownButton<int>(
                    value: _correct,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Correct: A')),
                      DropdownMenuItem(value: 1, child: Text('Correct: B')),
                      DropdownMenuItem(value: 2, child: Text('Correct: C')),
                      DropdownMenuItem(value: 3, child: Text('Correct: D')),
                    ],
                    onChanged: (v) => setState(() => _correct = v ?? 0),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save quiz'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  _quizzes.orderBy('createdAt', descending: true).snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No quizzes yet'));
                }
                return ListView.separated(
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
   SETTINGS + ADMIN PROFILE
   - Edit Display name + Recovery hint
   - Delete current account (Auth) + remove Firestore doc (self)
   - Sign out -> /auth
   ============================ */
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

    final ok = await _confirm(
      context,
      title: 'Delete your account?',
      message:
          'This permanently deletes your authentication account and your profile document.',
      confirmText: 'Delete account',
    );
    if (!ok) return;

    try {
      setState(() => _busy = true);
      final uid = u.uid;

      await u.delete(); // may require recent login
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      if (!mounted) return;
      _toast(context, 'Account deleted', icon: Icons.check_circle_outline);
      context.go('/auth');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _toast(
          context,
          'For security, sign in again, then retry delete.',
          icon: Icons.info_outline,
        );
      } else {
        _toast(context, e.message ?? 'Failed to delete', icon: Icons.error);
      }
    } catch (_) {
      _toast(context, 'Failed to delete account', icon: Icons.error_outline);
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
        children: [
          // Admin profile card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
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
                          decoration: const InputDecoration(
                            labelText: 'Recovery hint',
                            helperText:
                                'Used for password reset verification screens',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Theme row
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
          const ListTile(
            title: Text('Language'),
            subtitle: Text('English'),
          ),
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
                        context.go('/auth');
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

/* ============================
   Shared padded header
   ============================ */
class _Pad extends StatelessWidget {
  const _Pad({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Expanded(child: child),
        ],
      ),
    );
  }
}
