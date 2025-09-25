import 'package:flutter/material.dart';

// NEW imports for camera + networking
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart'; // for DeviceOrientation

class InstantTranslateScreen extends StatelessWidget {
  const InstantTranslateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _ScaffoldPad(
      title: 'Instant translate',
      child: Center(
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Stack(
            children: [
              // ▼▼ replaced the static box with a live camera preview box ▼▼
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: const _CameraBox(),
              ),
              // ▲▲ preview keeps your same rounded look ▲▲

              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(.9),
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('ዛሬ እንዴት ነህ?',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimaryContainer)),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                          onPressed: () {}, child: const Icon(Icons.volume_up)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScaffoldPad extends StatelessWidget {
  const _ScaffoldPad({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall!
                .copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Expanded(child: child),
      ]),
    );
  }
}

/// A self-contained camera preview that auto-starts and (optionally)
/// sends JPEG frames to your backend (disabled for now; flip the flag later).
///
/// Web: works on localhost/https. Make sure your backend has CORS enabled.
class _CameraBox extends StatefulWidget {
  const _CameraBox();

  @override
  State<_CameraBox> createState() => _CameraBoxState();
}

class _CameraBoxState extends State<_CameraBox> {
  CameraController? _controller;
  Future<void>? _init;
  Timer? _sender;
  bool _busy = false;

  // Flip this to true when your Python API is ready
  static const bool kSendToBackend = false;

  // Set to your FastAPI/Flask endpoint when enabling uploads
  static const String _backendUrl = 'http://127.0.0.1:8000/infer';

  @override
  void initState() {
    super.initState();
    _init = _initCamera();
  }

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    final cam = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );

    _controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // supported on web/mobile
    );

    await _controller!.initialize();

    // Some platforms/plugins may not support locking orientation (esp. web),
    // so guard this call.
    try {
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (_) {}

    // capture a JPEG every 800ms (ready for when backend is enabled)
    _sender = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      if (!mounted || _busy || !(_controller?.value.isInitialized ?? false))
        return;
      _busy = true;
      try {
        final shot = await _controller!.takePicture();
        final bytes = await shot.readAsBytes(); // JPEG bytes
        if (kSendToBackend) {
          await _sendToBackend(bytes);
        }
      } catch (_) {
        // optional: add logging
      } finally {
        _busy = false;
      }
    });
  }

  Future<void> _sendToBackend(Uint8List jpgBytes) async {
    final req = http.MultipartRequest('POST', Uri.parse(_backendUrl))
      ..files.add(http.MultipartFile.fromBytes(
        'frame', // field name expected by your backend
        jpgBytes,
        filename: 'frame.jpg',
      ));
    await req.send();
  }

  @override
  void dispose() {
    _sender?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: cs.surfaceVariant,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }
        if (!(_controller?.value.isInitialized ?? false)) {
          return Container(
            color: cs.surfaceVariant,
            alignment: Alignment.center,
            child: const Icon(Icons.videocam_off, size: 56),
          );
        }
        return CameraPreview(_controller!);
      },
    );
  }
}
