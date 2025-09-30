import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/* ignore: avoid_web_libraries_in_flutter */
import 'dart:ui_web' as ui;
/* ignore: avoid_web_libraries_in_flutter */
import 'dart:html' as html;

import 'package:webview_flutter/webview_flutter.dart';

class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  /// Letters and video IDs grouped into 6 units.
  static final List<List<String>> lettersByUnit = [
    ['A', 'B', 'C', 'D'],
    ['E', 'F', 'G', 'H'],
    ['I', 'J', 'K', 'L'],
    ['M', 'N', 'O', 'P/Q'],
    ['R', 'S', 'T', 'U'],
    ['V/W', 'X/Y/Z'],
  ];

  static final List<List<String>> videoIdsByUnit = [
    // Unit 1: A–D
    ['rGK4KZ1Kro0', 'lljcDn1sCPw', 'jFIqV04G4Bc', 'aoiNumzoIVI'],
    // Unit 2: E–H
    ['tnEXOxu8DeQ', 'IidbDW47psg', 'IxKKgEHElnY', 'N7EMD6cW9QU'],
    // Unit 3: I–L
    ['yVa_ARg-xKs', '7_QS8eYcZ1M', 'BqFTAuBRsjE', 'fgmlI1R8s7s'],
    // Unit 4: M–P/Q  -> shown as M–Q
    ['dKmuuzSrggk', 'U3hZzMB17Z8', 'FjrhQvSfSjE', 'nYZo0w9XJhM'],
    // Unit 5: R–U
    ['lIpCHp3V5Do', 'i5GRs-jBUVQ', 'yscvNCapzE8', '3PZRau8NEUY'],
    // Unit 6: V/W–X/Y/Z -> shown as V–Z
    ['mKFTCcNwMAo', 'y3FGR_0Uv0c'],
  ];

  /// Make a clean range label like "A–D", "M–Q", "V–Z" even if the
  /// last item is "P/Q" or "X/Y/Z".
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
    return _ScaffoldPad(
      title: 'Lessons to master sign language',
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) {
          final letters = lettersByUnit[i];
          return ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text('Unit ${i + 1}: ${_compactRange(letters)}'),
            trailing: FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LessonPlayerScreen(
                    unitIndex: i,
                    letters: letters,
                    videoIds: videoIdsByUnit[i],
                  ),
                ));
              },
              child: const Text('Start'),
            ),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: videoIdsByUnit.length,
      ),
    );
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
          // Rough space the controls + chips need below the player.
          const reservedForControls = 170.0; // back btn + spacing + row + chips
          // If we have enough vertical room, use a fixed (no-scroll) layout.
          final canFitWithoutScroll = constraints.maxHeight >=
              reservedForControls + 180.0; // ~min player

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
            // Compute a player height that respects 16:9 and never exceeds available space.
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
            // Fallback: allow scrolling, but hide scrollbars for a cleaner feel.
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
                    // In scroll mode we can just use AspectRatio for simplicity.
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
    return Padding(
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
    );
  }
}
