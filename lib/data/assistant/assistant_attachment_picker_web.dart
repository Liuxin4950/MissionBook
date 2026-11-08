import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../../application/assistant/assistant_attachment.dart';

Future<List<AssistantAttachment>> pickAssistantAttachments({
  required bool image,
  int maxCount = AssistantAttachment.maxCount,
  String confirmButtonText = '添加到对话',
  Future<AssistantAttachment?> Function(String name, Uint8List bytes)?
  onOversizedImage,
}) async {
  final result = Completer<List<AssistantAttachment>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = maxCount > 1
    ..accept =
        (image
                ? AssistantAttachment.imageExtensions
                : AssistantAttachment.textExtensions)
            .map((e) => '.$e')
            .join(',');
  input.style.display = 'none';
  input.onchange = ((web.Event event) {
    unawaited(() async {
      try {
        final count = input.files?.length ?? 0;
        if (count > maxCount) throw FormatException('本次最多还能添加 $maxCount 个附件');
        final attachments = <AssistantAttachment>[];
        var total = 0;
        for (var index = 0; index < count; index++) {
          final file = input.files!.item(index)!;
          final limit = image
              ? 20 * 1024 * 1024
              : AssistantAttachment.maxTextBytes;
          if (file.size > limit) {
            throw FormatException(
              image ? '原图不能超过 20 MiB，请先裁剪' : '文本文件不能超过 256 KiB',
            );
          }
          final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
          final attachment =
              image &&
                  bytes.length > AssistantAttachment.maxImageBytes &&
                  onOversizedImage != null
              ? await onOversizedImage(file.name, bytes)
              : AssistantAttachment.fromBytes(file.name, bytes);
          if (attachment == null) {
            result.complete([]);
            return;
          }
          total += attachment.bytes.length;
          if (total > AssistantAttachment.maxTotalBytes) {
            throw const FormatException('本条消息附件合计不能超过 24 MiB');
          }
          attachments.add(attachment);
        }
        result.complete(attachments);
      } catch (error, stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      }
    }());
  }).toJS;
  input.oncancel = ((web.Event event) {
    if (!result.isCompleted) result.complete([]);
  }).toJS;
  web.document.body!.append(input);
  try {
    input.click();
    return await result.future;
  } finally {
    input.remove();
  }
}

Future<AssistantAttachment?> pickAssistantAttachment({
  required bool image,
  String confirmButtonText = '添加到对话',
  Future<AssistantAttachment?> Function(String name, Uint8List bytes)?
  onOversizedImage,
}) async {
  final files = await pickAssistantAttachments(
    image: image,
    maxCount: 1,
    confirmButtonText: confirmButtonText,
    onOversizedImage: onOversizedImage,
  );
  return files.firstOrNull;
}
