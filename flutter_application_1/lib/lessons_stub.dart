// lib/lessons_stub.dart
// Stubs so mobile builds compile. They do nothing at runtime on mobile.

import 'package:flutter/widgets.dart';

class _DummyRegistry {
  // Accept any factory signature and ignore it.
  void registerViewFactory(String viewType, dynamic Function(int) _factory) {}
}

/// Fake stand-in for Flutter Web's platformViewRegistry
final _DummyRegistry platformViewRegistry = _DummyRegistry();

/// Minimal style object to satisfy property accesses in lessons.dart
class _Style {
  String border = '';
  String width = '';
  String height = '';
  String minHeight = '';
}

/// Fake stand-in for dart:html's IFrameElement with the exact members we set.
class IFrameElement {
  String src = '';
  final _Style style = _Style();
  bool allowFullscreen = false;
  String allow = '';
}

// NOTE: Do NOT define HtmlElementView here. We want Flutter's real
// HtmlElementView symbol to be visible so there’s no import conflict.
