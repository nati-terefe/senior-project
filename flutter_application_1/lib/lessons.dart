import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart'; // in-app browser fallback

// ✅ Conditional import: mobile gets stubs; web gets real bindings.
import 'lessons_stub.dart' if (dart.library.html) 'lessons_web.dart';

import 'dart:io' show Platform;

/// ------------------------------------------------------------
/// HARD-CODED DATA for first-run seeding (keep for reference; not called)
/// ------------------------------------------------------------

// ENGLISH: 6 units, 1 lesson each, in this order.
const List<_EnglishLessonSeed> _englishLessonsSeed = [
  _EnglishLessonSeed(
    unitIndex: 1,
    title: 'First 25 ASL signs',
    url: 'https://youtu.be/0FcwzMq4iWg?si=stIHwHYZbOVBLyvL',
  ),
  _EnglishLessonSeed(
    unitIndex: 2,
    title: 'How to sign questions',
    url: 'https://youtu.be/BopX7gr1BJ8?si=KVZPyQGqcujVxMZK',
  ),
  _EnglishLessonSeed(
    unitIndex: 3,
    title: 'How to sign colors',
    url: 'https://youtu.be/--lqNRmkusg?si=wZyI1VK2rcXbMh2l',
  ),
  _EnglishLessonSeed(
    unitIndex: 4,
    title: 'How to sign animals',
    url: 'https://youtu.be/eZtBJbdrJSg?si=HkPwMYlRdjzrvQIc',
  ),
  _EnglishLessonSeed(
    unitIndex: 5,
    title: 'How to sign the alphabet',
    url: 'https://youtu.be/50g-OJzP5Vg?si=xxGRWX82DXB1sh7b',
  ),
  _EnglishLessonSeed(
    unitIndex: 6,
    title: 'How to sign numbers',
    url: 'https://youtu.be/e48sS09jl8U?si=AxBYQ6NQMjyVyiqN',
  ),
];

// AMHARIC: 6 units. Units 1–5 have 4 lessons each; unit 6 has 2 lessons.
const List<List<_AmhLessonSeed>> _amharicUnitsSeed = [
  // Unit 1: A–D
  [
    _AmhLessonSeed('A', 'rGK4KZ1Kro0'),
    _AmhLessonSeed('B', 'lljcDn1sCPw'),
    _AmhLessonSeed('C', 'jFIqV04G4Bc'),
    _AmhLessonSeed('D', 'aoiNumzoIVI'),
  ],
  // Unit 2: E–H
  [
    _AmhLessonSeed('E', 'tnEXOxu8DeQ'),
    _AmhLessonSeed('F', 'IidbDW47psg'),
    _AmhLessonSeed('G', 'IxKKgEHElnY'),
    _AmhLessonSeed('H', 'N7EMD6cW9QU'),
  ],
  // Unit 3: I–L
  [
    _AmhLessonSeed('I', 'yVa_ARg-xKs'),
    _AmhLessonSeed('J', '7_QS8eYcZ1M'),
    _AmhLessonSeed('K', 'BqFTAuBRsjE'),
    _AmhLessonSeed('L', 'fgmlI1R8s7s'),
  ],
  // Unit 4: M–Q
  [
    _AmhLessonSeed('M', 'dKmuuzSrggk'),
    _AmhLessonSeed('N', 'U3hZzMB17Z8'),
    _AmhLessonSeed('O', 'FjrhQvSfSjE'),
    _AmhLessonSeed('P', 'nYZo0w9XJhM'),
  ],
  // Unit 5: R–U
  [
    _AmhLessonSeed('R', 'lIpCHp3V5Do'),
    _AmhLessonSeed('S', 'i5GRs-jBUVQ'),
    _AmhLessonSeed('T', 'yscvNCapzE8'),
    _AmhLessonSeed('U', '3PZRau8NEUY'),
  ],
  // Unit 6: V–Z (2 lessons)
  [
    _AmhLessonSeed('V–W', 'mKFTCcNwMAo'),
    _AmhLessonSeed('X–Z', 'y3FGR_0Uv0c'),
  ],
];

class _EnglishLessonSeed {
  final int unitIndex;
  final String title;
  final String url;
  const _EnglishLessonSeed({
    required this.unitIndex,
    required this.title,
    required this.url,
  });
}

class _AmhLessonSeed {
  final String title; // A, B, C … or ranges like V–W
  final String videoId; // YouTube id
  const _AmhLessonSeed(this.title, this.videoId);
}

/// ------------------------------------------------------------
/// SCREEN
/// ------------------------------------------------------------
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key, this.unitId, this.lessonId});

  final String? unitId;
  final String? lessonId;

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
    // You ALREADY seeded. Stop calling the seeder:
    // _maybeSeedInitialData();

    if (unitId != null) {
      return FutureBuilder<_LoadedUnit>(
        future: _loadUnit(unitId!, lessonId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.letters.isEmpty || data.videoIds.isEmpty) {
            return const Center(child: Text('No lessons in this unit.'));
          }

          return LessonPlayerScreen(
            unitIndex: data.unitIndex,
            letters: data.letters,
            videoIds: data.videoIds,
            category: data.category, // pass category so we can format title
            initialIndex: data.startIndex,
          );
        },
      );
    }

    // Units HOME with category filter
    return const _UnitsHome();
  }

  Future<_LoadedUnit> _loadUnit(String unitId, String? lessonId) async {
    final unitsCol = FirebaseFirestore.instance.collection('units');

    // Find index for header numbering
    final unitsQ = await unitsCol.orderBy('createdAt').get();

    int unitIndex = 0;
    for (int i = 0; i < unitsQ.docs.length; i++) {
      if (unitsQ.docs[i].id == unitId) {
        unitIndex = i;
        break;
      }
    }

    // Read this unit's category (english / amharic)
    final unitSnap = await unitsCol.doc(unitId).get();
    final String category =
        (unitSnap.data()?['category'] ?? 'amharic').toString();

    final lessonsQ = await unitsCol
        .doc(unitId)
        .collection('lessons')
        .orderBy('createdAt')
        .get();

    final letters = <String>[];
    final videoIds = <String>[];
    int startIndex = 0;

    for (int i = 0; i < lessonsQ.docs.length; i++) {
      final d = lessonsQ.docs[i];
      final data = d.data();
      final t = (data['title'] ?? '').toString();
      final u = (data['videoUrl'] ?? '').toString();
      final id = _UnitTileFirestore._extractYouTubeId(u);
      if (t.isNotEmpty && id.isNotEmpty) {
        if (lessonId != null && d.id == lessonId) {
          startIndex = letters.length;
        }
        letters.add(t);
        videoIds.add(id);
      }
    }

    return _LoadedUnit(
      unitIndex: unitIndex,
      letters: letters,
      videoIds: videoIds,
      startIndex: startIndex,
      category: category, // <-- include category
    );
  }
}

/// Units home with filter All / English / Amharic
class _UnitsHome extends StatefulWidget {
  const _UnitsHome();

  @override
  State<_UnitsHome> createState() => _UnitsHomeState();
}

enum _Cat { all, english, amharic }

class _UnitsHomeState extends State<_UnitsHome> {
  _Cat _cat = _Cat.all;

  @override
  Widget build(BuildContext context) {
    final unitsCol = FirebaseFirestore.instance.collection('units');

    return _ScaffoldPad(
      title: 'Lessons to master sign language',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: DropdownButton<_Cat>(
              value: _cat,
              onChanged: (v) => setState(() => _cat = v ?? _Cat.all),
              items: const [
                DropdownMenuItem(value: _Cat.all, child: Text('All')),
                DropdownMenuItem(
                    value: _Cat.english, child: Text('English only')),
                DropdownMenuItem(
                    value: _Cat.amharic, child: Text('Amharic only')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: unitsCol.orderBy('createdAt').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allDocs = snap.data?.docs ?? [];

                if (allDocs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No units yet'),
                    ),
                  );
                }

                final english = allDocs
                    .where((d) =>
                        (d.data()['category'] ?? '').toString() == 'english')
                    .toList();
                final amharic = allDocs
                    .where((d) =>
                        (d.data()['category'] ?? '').toString() == 'amharic')
                    .toList();

                if (_cat == _Cat.english) {
                  return _UnitsList(docs: english);
                } else if (_cat == _Cat.amharic) {
                  return _UnitsList(docs: amharic);
                }

                // All: English block first, then a divider, then Amharic
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (english.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6.0, horizontal: 4.0),
                        child: Text(
                          'English lessons',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    _UnitsList(docs: english, shrinkWrap: true),
                    if (english.isNotEmpty && amharic.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                'Amharic lessons',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                      ),
                    _UnitsList(docs: amharic, shrinkWrap: true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitsList extends StatelessWidget {
  const _UnitsList({required this.docs, this.shrinkWrap = false});
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) return const SizedBox.shrink();
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(0),
      itemBuilder: (_, i) {
        final unit = docs[i];
        final name = (unit.data()['name'] ?? 'Unit').toString();
        return _UnitTileFirestore(
          unitId: unit.id,
          unitName: name,
          unitIndex: (unit.data()['index'] ?? i) as int,
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: docs.length,
    );
  }
}

/// ------------------------ Seeder (NOT CALLED) ------------------------
Future<void> _maybeSeedInitialData() async {
  final db = FirebaseFirestore.instance;
  final flagRef = db.collection('meta').doc('seed_v1_lessons');

  // If already seeded, do nothing
  final flag = await flagRef.get();
  if (flag.exists) return;

  // OPTIONAL: delete existing units if you want a clean seed (comment out if not desired)
  final existing = await db.collection('units').get();
  for (final u in existing.docs) {
    final lessons = await u.reference.collection('lessons').get();
    for (final l in lessons.docs) {
      await l.reference.delete();
    }
    await u.reference.delete();
  }

  // Seed ENGLISH
  for (final e in _englishLessonsSeed) {
    final unitRef = await db.collection('units').add({
      'name': 'Unit ${e.unitIndex}',
      'category': 'english',
      'index': e.unitIndex,
      'normalizedName': 'unit ${e.unitIndex}'.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await unitRef.collection('lessons').add({
      'title': e.title,
      'videoUrl': e.url,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Seed AMHARIC
  for (int i = 0; i < _amharicUnitsSeed.length; i++) {
    final unitIndex = i + 1;
    final unitRef = await db.collection('units').add({
      'name': 'Unit $unitIndex',
      'category': 'amharic',
      'index': unitIndex,
      'normalizedName': 'unit $unitIndex',
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final lesson in _amharicUnitsSeed[i]) {
      final url = 'https://www.youtube.com/watch?v=${lesson.videoId}';
      await unitRef.collection('lessons').add({
        'title': lesson.title,
        'videoUrl': url,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  await flagRef.set({
    'done': true,
    'at': FieldValue.serverTimestamp(),
    'note': 'Units/lessons seeded (english + amharic)',
  });
}

/// ------------------------------------------------------------
/// Existing classes below
/// ------------------------------------------------------------
class _LoadedUnit {
  final int unitIndex;
  final List<String> letters;
  final List<String> videoIds;
  final int startIndex;
  final String category; // english / amharic
  _LoadedUnit({
    required this.unitIndex,
    required this.letters,
    required this.videoIds,
    required this.startIndex,
    required this.category,
  });
}

class _UnitTileFirestore extends StatelessWidget {
  const _UnitTileFirestore({
    required this.unitId,
    required this.unitName,
    required this.unitIndex,
  });
  final String unitId;
  final String unitName;
  final int unitIndex;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.menu_book)),
      title: Text(unitName, overflow: TextOverflow.ellipsis),
      trailing: FilledButton.tonal(
        onPressed: () => context.push('/lessons/$unitId'),
        child: const Text('Start'),
      ),
      onTap: () => context.push('/lessons/$unitId'),
    );
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
    required this.category, // <-- added
    this.initialIndex = 0,
  });

  final int unitIndex;
  final List<String> letters;
  final List<String> videoIds;
  final String category; // english / amharic
  final int initialIndex;

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  late int _index;
  WebViewController? _mobileController;

  String get _currentId => widget.videoIds[_index];
  String get _currentLabel => widget.letters[_index];

  static final Set<String> _registeredWebViews = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    if (kIsWeb) {
      _registerWebIFrame(_currentId);
    } else {
      _initMobileWebView(_currentId);
    }
  }

  Future<void> _openYouTubeInApp(String id) async {
    final url = Uri.parse('https://www.youtube.com/watch?v=$id');
    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
  }

  void _initMobileWebView(String videoId) {
    final url = Uri.parse(
      'https://www.youtube-nocookie.com/embed/$videoId'
      '?playsinline=1&modestbranding=1&rel=0&autoplay=1&controls=1',
    );

    late final WebViewController controller;

    if (Platform.isAndroid) {
      final params = const PlatformWebViewControllerCreationParams();
      final androidController =
          WebViewController.fromPlatformCreationParams(params)
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0x00000000))
            ..setNavigationDelegate(
              NavigationDelegate(
                onNavigationRequest: (request) {
                  final u = request.url;
                  final isWatch = u.contains('youtube.com/watch') ||
                      u.contains('youtu.be/');
                  if (isWatch) {
                    _openYouTubeInApp(_currentId);
                    return NavigationDecision.prevent;
                  }
                  return NavigationDecision.navigate;
                },
              ),
            )
            ..loadRequest(url);

      (androidController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);

      controller = androidController;
    } else {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              final u = request.url;
              final isWatch =
                  u.contains('youtube.com/watch') || u.contains('youtu.be/');
              if (isWatch) {
                _openYouTubeInApp(_currentId);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(url);
    }

    _mobileController = controller;
  }

  void _registerWebIFrame(String videoId) {
    final viewType = 'yt-$videoId';
    if (_registeredWebViews.contains(viewType)) return;
    _registeredWebViews.add(viewType);

    platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = IFrameElement()
        ..src =
            'https://www.youtube.com/embed/$videoId?rel=0&autoplay=1&controls=1'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.minHeight = '360px'
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

  void _smartBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go('/lessons');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.videoIds.length;
    final unitRange = LessonsScreen._compactRange(widget.letters);
    final viewType = 'yt-$_currentId';

    // Title: show range only for Amharic
    final titleText = widget.category == 'amharic'
        ? 'Unit ${widget.unitIndex + 1}: $unitRange'
        : 'Unit ${widget.unitIndex + 1}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _smartBack(context),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: .2,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                _miniChip(_currentLabel),
                const SizedBox(width: 6),
                _miniChip('${_index + 1}/$total'),
              ],
            ),
            const SizedBox(height: 10),

            // Player + in-app fallback button
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: kIsWeb
                    ? HtmlElementView(viewType: viewType)
                    : Stack(
                        children: [
                          if (_mobileController == null)
                            const Center(child: CircularProgressIndicator())
                          else
                            WebViewWidget(controller: _mobileController!),

                          // always-available fallback
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black.withOpacity(0.65),
                              ),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text(
                                'Open in YouTube',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _openYouTubeInApp(_currentId),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

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
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}

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
