import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../../application/goals/goal_file_picker.dart';
import '../../application/goals/goal_outline_parser.dart';

GoalFilePicker createGoalFilePicker() => WebGoalFilePicker();

class WebGoalFilePicker implements GoalFilePicker {
  @override
  Future<Uint8List?> pickBytes() async {
    final result = Completer<Uint8List?>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.json,application/json';
    input.style.display = 'none';
    input.onchange = ((web.Event event) {
      unawaited(() async {
        try {
          final file = input.files?.item(0);
          if (file == null) {
            result.complete(null);
            return;
          }
          if (!file.name.toLowerCase().endsWith('.json')) {
            throw const FormatException('请选择 .json 文件');
          }
          if (file.size > GoalOutlineParser.maxBytes) {
            throw const FormatException('文件超过 2 MiB 限制');
          }
          final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
          if (bytes.length > GoalOutlineParser.maxBytes) {
            throw const FormatException('文件超过 2 MiB 限制');
          }
          result.complete(bytes);
        } catch (error, stack) {
          result.completeError(error, stack);
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
}
