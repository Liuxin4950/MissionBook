import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../application/assistant/assistant_attachment.dart';

Future<AssistantAttachment?> pickAssistantAttachment({
  required bool image,
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
            ? AssistantAttachment.maxImageBytes
            : AssistantAttachment.maxTextBytes;
        if (file.size > limit) {
          throw FormatException(image ? '单张图片不能超过 4 MiB' : '文本文件不能超过 256 KiB');
        }
        final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
        result.complete(AssistantAttachment.fromBytes(file.name, bytes));
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
