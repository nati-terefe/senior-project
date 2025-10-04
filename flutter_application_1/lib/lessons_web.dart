// lib/lessons_web.dart
// Real bindings for Flutter Web.

import 'dart:ui_web' as ui; // platformViewRegistry
import 'dart:html' as html; // IFrameElement

// Re-export names expected by lessons.dart
final platformViewRegistry = ui.platformViewRegistry;
typedef IFrameElement = html.IFrameElement;
// No HtmlElementView re-export needed; Flutter provides the real widget.
