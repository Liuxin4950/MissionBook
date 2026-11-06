import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures a bounded screenshot of the visible Flutter surface.
Future<Uint8List?> captureAssistantScreen(
  GlobalKey boundaryKey, {
  required double devicePixelRatio,
}) async {
  final renderObject = boundaryKey.currentContext?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary || !renderObject.attached) {
    return null;
  }

  final size = renderObject.size;
  if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
    return null;
  }

  const maxPixels = 4000000.0;
  final area = size.width * size.height;
  final pixelRatio = math.min(devicePixelRatio, math.sqrt(maxPixels / area));
  final image = await renderObject.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}
