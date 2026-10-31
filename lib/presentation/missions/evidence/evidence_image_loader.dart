import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'evidence_image_preview.dart';
import 'evidence_image_status.dart';

/// 图片读取状态统一呈现；Future 由页面缓存，重试由页面重新读取同一份材料。
class EvidenceImageLoader extends StatelessWidget {
  const EvidenceImageLoader({
    super.key,
    required this.future,
    required this.name,
    this.height = 148,
    this.onRetry,
    this.previewKey,
    this.compact = false,
  });

  final Future<Uint8List>? future;
  final String name;
  final double height;
  final VoidCallback? onRetry;
  final Key? previewKey;
  final bool compact;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return EvidenceImageStatus(
          name: name,
          height: height,
          failed: true,
          onRetry: onRetry,
          compact: compact,
        );
      }
      if (!snapshot.hasData) {
        return EvidenceImageStatus(
          name: name,
          height: height,
          compact: compact,
        );
      }
      if (compact) {
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          semanticLabel: name,
          errorBuilder: (_, error, stack) => EvidenceImageStatus(
            name: name,
            height: height,
            failed: true,
            compact: true,
            onRetry: onRetry,
          ),
        );
      }
      return EvidenceImagePreview(
        key: previewKey,
        bytes: snapshot.data!,
        name: name,
        height: height,
        onRetry: onRetry,
      );
    },
  );
}
