import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'backup_archive.dart';

Future<Uint8List?> pickBackupFile() async {
  final result = Completer<Uint8List?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.zip,application/zip';
  input.style.display = 'none';
  input.onchange = ((web.Event _) {
    unawaited(() async {
      try {
        final file = input.files?.item(0);
        if (file == null) {
          result.complete(null);
          return;
        }
        if (!file.name.toLowerCase().endsWith('.zip') ||
            file.size > maxBackupBytes) {
          throw const FormatException('请选择不超过 256 MiB 的 ZIP 备份');
        }
        result.complete((await file.arrayBuffer().toDart).toDart.asUint8List());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    }());
  }).toJS;
  input.oncancel = ((web.Event _) {
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
