import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'assistant_attachment.dart';

/// 只压缩用户选择发送的副本；原文件和记录材料保持原样。
Future<AssistantAttachment> compressAssistantImage(
  String name,
  Uint8List bytes,
) async {
  final compressed = await compute(_compress, bytes);
  final base = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
  return AssistantAttachment.fromBytes('$base-compressed.jpg', compressed);
}

Uint8List _compress(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null) throw const FormatException('图片无法解码，请重新选择');
  if (info.width * info.height > 40000000) {
    throw const FormatException('图片像素过大，请先裁剪后再发送');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) throw const FormatException('图片无法解码，请重新选择');
  var image = img.bakeOrientation(decoded);
  for (final edge in [2400, 1800, 1280, 960]) {
    final longest = image.width > image.height ? image.width : image.height;
    final scaled = longest > edge
        ? img.copyResize(
            image,
            width: image.width >= image.height ? edge : null,
            height: image.height > image.width ? edge : null,
          )
        : image;
    final encoded = img.encodeJpg(scaled, quality: 85);
    if (encoded.length <= AssistantAttachment.maxImageBytes) return encoded;
    image = scaled;
  }
  throw const FormatException('压缩后仍超过 4 MiB，请裁剪图片后再发送');
}
