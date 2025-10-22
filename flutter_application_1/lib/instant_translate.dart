import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'dart:io' show Platform; // to know the platform its using

/* ===================== CONFIG ===================== */
String get kWsUrl {
  if (kIsWeb) return 'ws://localhost:8000/ws/predict';
  if (Platform.isAndroid)
    return 'ws://10.0.2.2:8000/ws/predict'; // emulator → host
  return 'ws://localhost:8000/ws/predict'; // iOS sim / desktop
} // FastAPI WS endpoint

const double kDefaultHoldTimeSec = 0.8; // initial hold time
const int kFpsMs = 200; // ~5 FPS
/* =================================================== */

class InstantTranslateScreen extends StatefulWidget {
  const InstantTranslateScreen({super.key});
  @override
  State<InstantTranslateScreen> createState() => _InstantTranslateScreenState();
}

class _InstantTranslateScreenState extends State<InstantTranslateScreen>
    with SingleTickerProviderStateMixin {
  // Camera
  CameraController? _cam;
  Future<void>? _camInit;
  Timer? _frameTimer;
  bool _sending = false;

  // WebSocket
  WebSocketChannel? _ws;
  bool _connected = false;

  // Toggles
  bool _showAmharic = true;
  bool _showSuggestions = true;

  // Hold time
  double _holdTime = kDefaultHoldTimeSec;

  // Stats
  int _framesSent = 0;
  int _wordsCompleted = 0;
  final List<double> _processTimes = [];

  // Results
  String _letter = '-';
  double _confidence = 0;
  double _letterProgress = 0;
  String _currentWord = '-';
  List<String> _suggestions = const [];

  // Completed words
  final List<_CompletedWord> _completed = [];

  // Console
  final ScrollController _logCtl = ScrollController();
  final List<String> _logs = [];

  // Landmarks (normalized 0..1) from server
  List<Offset>? _normLandmarks;

  // Tabs (for narrow)
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _camInit = null; // don’t auto-start
  }

  @override
  void dispose() {
    _stopFrameTimer();
    _disposeCamera();
    _ws?.sink.close(ws_status.normalClosure);
    _tabs.dispose();
    _logCtl.dispose();
    super.dispose();
  }

  /* ---------------- Camera ---------------- */

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    final cam = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );

    _cam = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _cam!.initialize();
    try {
      await _cam!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _startCamera() {
    if (_cam != null && _cam!.value.isInitialized) {
      _log('Camera already started');
      return;
    }
    _log('Starting camera…');
    _camInit = _initCamera();
    setState(() {});
  }

  void _disposeCamera() {
    if (_cam != null) {
      try {
        _cam!.dispose();
      } catch (_) {}
      _cam = null;
    }
    _camInit = null;
  }

  void _stopCamera() {
    _log('Stopping camera…');
    _stopFrameTimer();
    _disposeCamera();
    setState(() {});
  }

  void _startFrameTimer() {
    if (_frameTimer != null) return;
    if (_cam == null || !_cam!.value.isInitialized) {
      _log('Start camera first');
      return;
    }
    _log('Starting recognition…');
    _frameTimer =
        Timer.periodic(const Duration(milliseconds: kFpsMs), (_) async {
      if (!mounted || _sending || _ws == null || !_connected) return;
      if (_cam == null || !_cam!.value.isInitialized) return;

      _sending = true;
      try {
        final shot = await _cam!.takePicture();
        final bytes = await shot.readAsBytes(); // JPEG
        _framesSent++;
        final b64 = base64Encode(bytes);
        _ws!.sink.add(jsonEncode({'type': 'frame', 'data': b64}));
        setState(() {});
      } catch (e) {
        _log('Frame send error: $e');
      } finally {
        _sending = false;
      }
    });
  }

  void _stopFrameTimer() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _log('Recognition stopped');
  }

  /* ---------------- WebSocket ---------------- */

  void _connect() {
    if (_ws != null) {
      _log('Already connected');
      return;
    }
    try {
      _log('Connecting to $kWsUrl …');
      final ch = WebSocketChannel.connect(Uri.parse(kWsUrl));
      _ws = ch;
      _connected = true;
      setState(() {});
      _log('WebSocket connected');

      ch.stream.listen(
        _onWsMessage,
        onError: (e) {
          _log('WS error: $e');
          _connected = false;
          _ws = null;
          setState(() {});
        },
        onDone: () {
          _log('WebSocket closed');
          _connected = false;
          _ws = null;
          setState(() {});
        },
      );
    } catch (e) {
      _log('Connect failed: $e');
    }
  }

  void _disconnect() {
    _ws?.sink.close(ws_status.normalClosure);
    _ws = null;
    _connected = false;
    _stopFrameTimer();
    setState(() {});
    _log('Disconnected');
  }

  void _onWsMessage(dynamic event) {
    try {
      final Map<String, dynamic> resp = jsonDecode(event as String);

      if (resp['type'] == 'prediction') {
        final data = (resp['data'] as Map<String, dynamic>?) ?? {};
        _letter = (data['letter'] ?? '-') as String;
        _confidence = ((data['confidence'] ?? 0.0) as num).toDouble();
        _letterProgress = ((data['letter_progress'] ?? 0.0) as num).toDouble();
        _currentWord = (data['current_word'] ?? '-') as String;

        final ws = (data['word_suggestions'] as List?)?.cast<String>() ??
            const <String>[];
        _suggestions = ws.take(3).toList();

        final lms = data['landmarks'];
        if (lms is List && lms.isNotEmpty) {
          final parsed = <Offset>[];
          for (final item in lms) {
            if (item is List && item.length >= 2) {
              parsed.add(Offset(
                (item[0] as num).toDouble(),
                (item[1] as num).toDouble(),
              ));
            }
          }
          _normLandmarks = parsed.isEmpty ? null : parsed;
        } else {
          _normLandmarks = null;
        }

        final pt = (data['processing_time_ms'] ?? 0);
        final ptDouble = (pt is num) ? pt.toDouble() : 0.0;
        if (ptDouble > 0) {
          _processTimes.add(ptDouble);
          if (_processTimes.length > 100) _processTimes.removeAt(0);
        }

        // -------- CHANGE: always store Amharic translation from server --------
        final completed = data['word_completed'] as String?;
        if (completed != null && completed.isNotEmpty) {
          final amh = data['amharic_translation'] as String?;
          _completed.insert(0, _CompletedWord(word: completed, amharic: amh));
          if (_completed.length > 10) _completed.removeLast();
          _wordsCompleted++;
        }
        // ---------------------------------------------------------------------

        final err = data['error'] as String?;
        if (err != null && err.isNotEmpty) _log('Error: $err');

        setState(() {});
        return;
      }

      if (resp['type'] == 'error') {
        _log('Server error: ${resp['message']}');
      } else if (resp['type'] == 'reset_confirmed') {
        _log('Word tracker reset confirmed');
      } else if (resp['type'] == 'config_updated') {
        _log('Config updated: ${resp['message']}');
      } else {
        _log('Unknown message: ${resp['type']}');
      }
    } catch (e) {
      _log('Failed to parse WS message: $e');
    }
  }

  void _sendConfig() {
    if (_ws == null || !_connected) return;
    _ws!.sink.add(jsonEncode({
      'type': 'config',
      'data': {'hold_time': _holdTime}
    }));
    _log('Sent hold_time=${_holdTime.toStringAsFixed(1)}s');
  }

  void _resetWord() {
    if (_ws == null || !_connected) {
      _log('WebSocket not connected');
      return;
    }
    _ws!.sink.add(jsonEncode({'type': 'reset'}));
    _log('Reset word sent');
  }

  /* ---------------- UI helpers ---------------- */

  void _log(String s) {
    final t = TimeOfDay.now();
    final line = '[${t.format(context)}] $s';
    _logs.add(line);
    if (_logs.length > 400) _logs.removeAt(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logCtl.hasClients) {
        _logCtl.jumpTo(_logCtl.position.maxScrollExtent);
      }
    });
    setState(() {});
  }

  String get _avgMs {
    if (_processTimes.isEmpty) return '0';
    final avg = _processTimes.reduce((a, b) => a + b) / _processTimes.length;
    return avg.toStringAsFixed(0);
  }

  Color _statusColor(ColorScheme cs) => _connected ? Colors.green : cs.error;

  ButtonStyle _solid(Color bg, {Color fg = Colors.white}) =>
      FilledButton.styleFrom(backgroundColor: bg, foregroundColor: fg);

  /* ---------------- Build ---------------- */

  @override
  Widget build(BuildContext context) {
    final status = _statusBar(context);

    return _ScaffoldPad(
      title: 'Instant translate',
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final isNarrow = w < 980;

        // rule: mobile shows letter under camera, web shows in results
        final showLetterInLeft = isNarrow; // only mobile
        final showLetterInRight = !isNarrow && kIsWeb; // only wide web

        final leftPane = _leftColumn(
          context,
          showLetterInLeft: showLetterInLeft,
          availableWidth: w,
        );
        final rightPane =
            _rightColumn(context, showLetterInRight: showLetterInRight);

        if (isNarrow) {
          // -------- MOBILE (header is NOT sticky; scrolls with content) --------
          final tabLabelStyle =
              Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  );
          final tabUnselected =
              Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.color
                        ?.withOpacity(.75),
                  );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                status,
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabs,
                  tabs: const [Tab(text: 'Camera'), Tab(text: 'Results')],
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  labelStyle: tabLabelStyle, // avoid style interpolation bug
                  unselectedLabelStyle:
                      tabUnselected, // same base, different weight
                ),
                const SizedBox(height: 8),
                // Render the selected tab inline so the whole page scrolls together.
                AnimatedBuilder(
                  animation: _tabs,
                  builder: (_, __) {
                    final idx = _tabs.index;
                    return idx == 0 ? leftPane : rightPane;
                  },
                ),
              ],
            ),
          );
        }

        // -------- WEB (wide) --------
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            primary: true,
            child: Column(
              children: [
                status,
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftPane),
                    const SizedBox(width: 16),
                    Expanded(child: rightPane),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /* ---------------- Status Bar ---------------- */

  Widget _statusBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(cs);

    Widget group(String title, List<Widget> children) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(.8),
                  ),
            ),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      );
    }

    // EDIT #1: slimmer padding so Start/Stop fit side-by-side
    final camButtons = [
      FilledButton.icon(
        onPressed: _startCamera,
        style: _solid(Colors.green).copyWith(
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        icon: const Icon(Icons.videocam),
        label: const Text('Start Camera'),
      ),
      FilledButton.icon(
        onPressed: _stopCamera,
        style: _solid(Colors.red).copyWith(
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        icon: const Icon(Icons.videocam_off),
        label: const Text('Stop Camera'),
      ),
    ];

    final wsButtons = [
      FilledButton.icon(
        onPressed: _connect,
        style: _solid(Colors.green).copyWith(
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        icon: const Icon(Icons.link),
        label: const Text('Connect'),
      ),
      FilledButton.icon(
        onPressed: _disconnect,
        style: _solid(Colors.red).copyWith(
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        icon: const Icon(Icons.link_off),
        label: const Text('Disconnect'),
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final isTight = w < 560;
      final isMedium = w >= 560 && w < 840;

      final headerRow = Row(
        children: [
          Icon(_connected ? Icons.check_circle : Icons.error,
              color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _connected ? 'Connected to WebSocket' : 'Disconnected',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

      final groupsNarrow = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          group('Camera', camButtons),
          const SizedBox(height: 10),
          group('Connection', wsButtons),
        ],
      );

      final groupsMedium = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: group('Camera', camButtons)),
          const SizedBox(width: 12),
          Expanded(child: group('Connection', wsButtons)),
        ],
      );

      final groupsWide = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: headerRow),
          const SizedBox(width: 12),
          group('Camera', camButtons),
          const SizedBox(width: 16),
          group('Connection', wsButtons),
        ],
      );

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _connected
              ? Colors.green.withOpacity(.15)
              : cs.errorContainer.withOpacity(.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(.5)),
        ),
        child: isTight
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  headerRow,
                  const SizedBox(height: 12),
                  groupsNarrow,
                ],
              )
            : (isMedium
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerRow,
                      const SizedBox(height: 12),
                      groupsMedium,
                    ],
                  )
                : groupsWide),
      );
    });
  }

  /* ---------------- Helpers ---------------- */

  bool _useSideBySideLetter(double availableWidth) =>
      kIsWeb && availableWidth > 1100;

  /* ---------------- Left Column ---------------- */

  Widget _leftColumn(
    BuildContext context, {
    required bool showLetterInLeft,
    required double availableWidth,
  }) {
    final cs = Theme.of(context).colorScheme;
    final sideBySideLetter = _useSideBySideLetter(availableWidth);

    return Padding(
      padding: const EdgeInsets.only(right: 2, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Camera',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),

          // Camera
          FutureBuilder(
            future: _camInit,
            builder: (context, snap) {
              final waitingInit = _camInit != null &&
                  snap.connectionState != ConnectionState.done;

              Widget camChild;
              if (_cam == null || !_cam!.value.isInitialized) {
                camChild = Container(
                  height: kIsWeb ? 280 : 360,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: waitingInit
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.videocam_off, size: 64),
                );
              } else {
                final wideAR = kIsWeb ? (20 / 9) : (4 / 3);
                final logicalWidth = kIsWeb ? 720.0 : 360.0;
                final logicalHeight = logicalWidth / wideAR;

                final preview = AspectRatio(
                  aspectRatio: wideAR,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: logicalWidth,
                            height: logicalHeight,
                            child: CameraPreview(_cam!),
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _HandPainter(normPoints: _normLandmarks),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                camChild = ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: kIsWeb ? 320 : 420),
                  child: preview,
                );
              }

              if (!sideBySideLetter) return camChild;
              return camChild;
            },
          ),

          const SizedBox(height: 12),

          // Controls
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _startFrameTimer,
                style: _solid(Colors.green),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Recognition'),
              ),
              FilledButton.icon(
                onPressed: _stopFrameTimer,
                style: _solid(Colors.red),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
              OutlinedButton.icon(
                onPressed: _resetWord,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset Word'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _framesSent = 0;
                  _wordsCompleted = 0;
                  _processTimes.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Clear Stats'),
              ),
            ],
          ),

          // -------- Mobile-only Current Letter (with subtle divider) --------
          if (showLetterInLeft) ...[
            const SizedBox(height: 14),
            // EDIT #2: make center label Flexible to avoid 17px overflow
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(.6),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Current Letter',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _currentLetterCard(context),
          ],

          const SizedBox(height: 12),

          // Settings
          _settingsRow(context),
          const SizedBox(height: 12),

          // Stats
          _statsWrap(context),
          const SizedBox(height: 12),

          // Console
          Text(
            'Console',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(minHeight: 140, maxHeight: 280),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Scrollbar(
              controller: _logCtl,
              child: ListView.builder(
                controller: _logCtl,
                itemCount: _logs.length,
                itemBuilder: (_, i) => Text(
                  _logs[i],
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- Right Column ---------------- */

  Widget _rightColumn(BuildContext context, {required bool showLetterInRight}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLetterInRight) _currentLetterCard(context),
          if (showLetterInRight) const SizedBox(height: 10),

          // Current Word
          _card(
            context,
            title: 'Current Word',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(.4),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _currentWord.isEmpty ? '-' : _currentWord,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Word Suggestions
          if (_showSuggestions)
            _card(
              context,
              title: 'Word Suggestions',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((s) {
                  return ActionChip(
                    label: Text(s.toUpperCase()),
                    onPressed: () {
                      _completed.insert(
                          0, _CompletedWord(word: s, amharic: null));
                      if (_completed.length > 10) _completed.removeLast();
                      _wordsCompleted++;
                      _resetWord();
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
            ),
          if (_showSuggestions) const SizedBox(height: 10),

          // Completed Words
          _card(
            context,
            title: 'Completed Words',
            child: _completed.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: Opacity(
                      opacity: .7,
                      child: Text(
                        'No words completed yet',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Column(
                    children: _completed.map((e) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.word.toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            if (_showAmharic && (e.amharic ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  e.amharic!,
                                  style: const TextStyle(color: Colors.amber),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  /* ---------------- Shared cards/helpers ---------------- */

  Widget _currentLetterCard(BuildContext context) {
    return _card(
      context,
      title: 'Current Letter',
      child: Column(
        children: [
          Text(
            _letter,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(blurRadius: 12, color: Colors.white)],
            ),
          ),
          const SizedBox(height: 8),
          Text('Confidence: ${(100 * _confidence).round()}%'),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _confidence.clamp(0, 1),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text('Progress: ${(100 * _letterProgress).round()}%'),
        ],
      ),
    );
  }

  Widget _settingsRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: const Text('Amharic Translation'),
          selected: _showAmharic,
          onSelected: (v) => setState(() => _showAmharic = v),
          selectedColor: cs.primary.withOpacity(.15),
        ),
        FilterChip(
          label: const Text('Word Suggestions'),
          selected: _showSuggestions,
          onSelected: (v) => setState(() => _showSuggestions = v),
          selectedColor: cs.primary.withOpacity(.15),
        ),

        // Hold Time control kept responsive to avoid overflow
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Hold Time:'),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: SizedBox(
                width: 160,
                child: Slider(
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  value: _holdTime,
                  label: '${_holdTime.toStringAsFixed(1)}s',
                  onChanged: (v) => setState(() => _holdTime = v),
                  onChangeEnd: (_) => _sendConfig(),
                ),
              ),
            ),
            Text(
              '${_holdTime.toStringAsFixed(1)}s',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statsWrap(BuildContext context) {
    Widget stat(String v, String label) => Container(
          width: 180,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          margin: const EdgeInsets.only(right: 10, bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                v,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );

    return Wrap(
      children: [
        stat('$_framesSent', 'Frames Sent'),
        stat(_avgMs, 'Avg Time (ms)'),
        stat('$_wordsCompleted', 'Words Completed'),
        stat('${_holdTime.toStringAsFixed(1)}s', 'Hold Time'),
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/* --------------------------- Models --------------------------- */

class _CompletedWord {
  final String word;
  final String? amharic;
  _CompletedWord({required this.word, this.amharic});
}

/* --------------------------- Hand overlay painter --------------------------- */

class _HandPainter extends CustomPainter {
  _HandPainter({required this.normPoints});
  final List<Offset>? normPoints;

  static const List<List<int>> _edges = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [0, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [0, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [0, 17],
    [17, 18],
    [18, 19],
    [19, 20],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final pts = normPoints;
    if (pts == null || pts.length < 21) return;

    Offset toPx(Offset n) => Offset(n.dx * size.width, n.dy * size.height);

    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (final e in _edges) {
      final a = toPx(pts[e[0]]);
      final b = toPx(pts[e[1]]);
      canvas.drawLine(a, b, linePaint);
    }

    for (final p in pts) {
      canvas.drawCircle(toPx(p), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HandPainter oldDelegate) {
    final a = oldDelegate.normPoints, b = normPoints;
    if (a == null && b == null) return false;
    if (a == null || b == null) return true;
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if ((a[i].dx - b[i].dx).abs() > 1e-6 ||
          (a[i].dy - b[i].dy).abs() > 1e-6) {
        return true;
      }
    }
    return false;
  }
}

/* --------------------------- Shared scaffold --------------------------- */

class _ScaffoldPad extends StatelessWidget {
  const _ScaffoldPad({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
