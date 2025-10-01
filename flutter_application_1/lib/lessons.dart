import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/* ignore: avoid_web_libraries_in_flutter */
import 'dart:ui_web' as ui;
/* ignore: avoid_web_libraries_in_flutter */
import 'dart:html' as html;

import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  /// Make a clean range label like "A–D", "M–Q", "V–Z" even if the last is "P/Q" or "X/Y/Z".
  static String _compactRange(List<String> letters) {
    if (letters.isEmpty) return '';
    String first = _firstAlpha(letters.first).toUpperCase();
    String last = _lastAlpha(letters.last).toUpperCase();
    if (first.isEmpty || last.isEmpty) return letters.join(', ');
    return '$first–$last';
  }

  static String _firstAlpha(String s) {
    final m = RegExp(r'[A-Za-z]').firstMatch(s);
    return m?.group(0) ?? '';
  }

  static String _lastAlpha(String s) {
    final all = RegExp(r'[A-Za-z]').allMatches(s);
    return all.isNotEmpty ? all.last.group(0)! : '';
  }

  @override
  Widget build(BuildContext context) {
    final unitsCol = FirebaseFirestore.instance.collection('units');

    return _ScaffoldPad(
      title: 'Lessons to master sign language',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: unitsCol.orderBy('createdAt').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No units yet'),
              ),
            );
          }

          // Responsive, smooth on mobile (no nested scrollables)
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (_, i) {
              final unit = docs[i];
              final name = (unit.data()['name'] ?? 'Unit').toString();
              return _UnitTileFirestore(unitId: unit.id, unitName: name);
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: docs.length,
          );
        },
      ),
    );
  }
}

/// Unit tile that loads lessons from Firestore then navigates with lists.
class _UnitTileFirestore extends StatelessWidget {
  const _UnitTileFirestore({required this.unitId, required this.unitName});
  final String unitId;
  final String unitName;

  @override
  Widget build(BuildContext context) {
    final unitsCol = FirebaseFirestore.instance.collection('units');

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.menu_book)),
      title: Text(unitName, overflow: TextOverflow.ellipsis),
      trailing: FilledButton.tonal(
        onPressed: () async {
          // Fetch lessons for this unit (ordered)
          final q = await unitsCol
              .doc(unitId)
              .collection('lessons')
              .orderBy('createdAt')
              .get();

          if (q.docs.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No lessons in this unit yet.')),
            );
            return;
          }

          // Build lists for the player
          final letters = <String>[];
          final videoIds = <String>[];
          for (final d in q.docs) {
            final data = d.data();
            final t = (data['title'] ?? '').toString();
            final u = (data['videoUrl'] ?? '').toString();
            final id = _extractYouTubeId(u);
            if (t.isNotEmpty && id.isNotEmpty) {
              letters.add(t);
              videoIds.add(id);
            }
          }

          if (letters.isEmpty || videoIds.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lessons are missing video links.')),
            );
            return;
          }

          // Navigate using the same player (cosmetic unit index from name if possible)
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LessonPlayerScreen(
              unitIndex: _unitNumberFromName(unitName) - 1,
              letters: letters,
              videoIds: videoIds,
            ),
          ));
        },
        child: const Text('Start'),
      ),
    );
  }

  static int _unitNumberFromName(String name) {
    final m = RegExp(r'(\d+)').firstMatch(name);
    if (m != null) {
      return int.tryParse(m.group(1) ?? '1') ?? 1;
    }
    return 1;
  }

  static String _extractYouTubeId(String url) {
    final u = url.trim();
    final patterns = [
      RegExp(r'youtu\.be/([A-Za-z0-9\-_]{6,})'),
      RegExp(r'[?&]v=([A-Za-z0-9\-_]{6,})'),
      RegExp(r'embed/([A-Za-z0-9\-_]{6,})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(u);
      if (m != null) return m.group(1)!;
    }
    return '';
  }
}

class LessonPlayerScreen extends StatefulWidget {
  const LessonPlayerScreen({
    super.key,
    required this.unitIndex,
    required this.letters,
    required this.videoIds,
  });

  final int unitIndex;
  final List<String> letters;
  final List<String> videoIds;

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  int _index = 0;
  WebViewController? _mobileController;

  String get _currentId => widget.videoIds[_index];
  String get _currentLabel => widget.letters[_index];

  static final Set<String> _registeredWebViews = {};

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerWebIFrame(_currentId);
    } else {
      _initMobileWebView(_currentId);
    }
  }

  void _initMobileWebView(String videoId) {
    final url = Uri.parse(
      'https://www.youtube.com/embed/$videoId?rel=0&autoplay=1&controls=1',
    );
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(url);
    _mobileController = controller;
  }

  void _registerWebIFrame(String videoId) {
    final viewType = 'yt-$videoId';
    if (_registeredWebViews.contains(viewType)) return;
    _registeredWebViews.add(viewType);

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src =
            'https://www.youtube.com/embed/$videoId?rel=0&autoplay=1&controls=1'
        ..style.border = '0'
        ..allowFullscreen = true
        ..allow = 'autoplay; encrypted-media; picture-in-picture';
      return iframe;
    });
  }

  void _playAt(int i) {
    if (i < 0 || i >= widget.videoIds.length) return;
    setState(() => _index = i);
    final id = _currentId;
    if (kIsWeb) {
      _registerWebIFrame(id);
    } else {
      _mobileController?.loadRequest(
        Uri.parse(
          'https://www.youtube.com/embed/$id?rel=0&autoplay=1&controls=1',
        ),
      );
    }
  }

  void _next() => _playAt(_index + 1);
  void _prev() => _playAt(_index - 1);

  @override
  Widget build(BuildContext context) {
    final total = widget.videoIds.length;
    final unitRange = LessonsScreen._compactRange(widget.letters);
    final viewType = 'yt-$_currentId';

    return _ScaffoldPad(
      title:
          'Unit ${widget.unitIndex + 1}: $unitRange • ${_currentLabel} (${_index + 1}/$total)',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const reservedForControls = 170.0;
          final canFitWithoutScroll =
              constraints.maxHeight >= reservedForControls + 180.0;

          Widget playerSizedBox(double height) => SizedBox(
                width: double.infinity,
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: kIsWeb
                      ? HtmlElementView(viewType: viewType)
                      : (_mobileController == null
                          ? const Center(child: CircularProgressIndicator())
                          : WebViewWidget(controller: _mobileController!)),
                ),
              );

          Widget controls() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _index > 0 ? _prev : null,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Prev'),
                      ),
                      FilledButton.icon(
                        onPressed: _index + 1 < total ? _next : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(total, (i) {
                      final selected = i == _index;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(widget.letters[i]),
                        onSelected: (_) => _playAt(i),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
              );

          if (canFitWithoutScroll) {
            final width = constraints.maxWidth;
            final idealHeight = width / (16 / 9);
            final maxAllowed = constraints.maxHeight - reservedForControls;
            final playerHeight = idealHeight.clamp(180.0, maxAllowed);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to units'),
                  ),
                ),
                const SizedBox(height: 8),
                playerSizedBox(playerHeight),
                controls(),
              ],
            );
          } else {
            return ScrollConfiguration(
              behavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to units'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: kIsWeb
                            ? HtmlElementView(viewType: viewType)
                            : (_mobileController == null
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : WebViewWidget(
                                    controller: _mobileController!)),
                      ),
                    ),
                    controls(),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

// ===== shared scaffold =====
class _ScaffoldPad extends StatelessWidget {
  const _ScaffoldPad({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall!
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ]),
      ),
    );
  }
}
