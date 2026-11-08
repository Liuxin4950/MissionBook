import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../../application/assistant/assistant_attachment.dart';

Future<AssistantAttachment?> pickAssistantAttachment({
  required bool image,
  String confirmButtonText = '添加到对话',
  Future<AssistantAttachment?> Function(String name, Uint8List bytes)?
  onOversizedImage,
}) async {
  final result = Completer<AssistantAttachment?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
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
        final file = input.files?.item(0);
        if (file == null) {
          result.complete(null);
          return;
        }
        final limit = image
            ? 20 * 1024 * 1024
            : AssistantAttachment.maxTextBytes;
        if (file.size > limit) {
          throw FormatException(
            image ? '原图不能超过 20 MiB，请先裁剪' : '文本文件不能超过 256 KiB',
          );
        }
        final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
        if (image &&
            bytes.length > AssistantAttachment.maxImageBytes &&
            onOversizedImage != null) {
          result.complete(await onOversizedImage(file.name, bytes));
        } else {
          result.complete(AssistantAttachment.fromBytes(file.name, bytes));
        }
      } catch (error, stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      }
    }());
  }).toJS;
  input.oncancel = ((web.Event event) {
    if (!result.isCompleted) result.complete(null);
  }).toJS;
  web.document.body!.append(input);
  try {
    input.click();
    return await result.future;
  } finally {
    input.remove();
  }
}
