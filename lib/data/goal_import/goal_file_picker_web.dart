import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../application/goals/goal_file_picker.dart';
import '../../domain/entities/goal_package_import.dart';

GoalFilePicker createGoalFilePicker() => WebGoalFilePicker();

class WebGoalFilePicker implements GoalFilePicker {
  @override
  Future<GoalImportSource?> pickSource() async {
    final result = Completer<GoalImportSource?>();
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
          if (file.size > GoalImportLimits.fileBytes) {
            throw const FormatException('文件超过 32 MiB 限制');
          }
          result.complete(
            GoalImportSource(
              name: file.name,
              length: file.size,
              openRead: () async* {
                for (var offset = 0; offset < file.size; offset += 65536) {
                  final end = (offset + 65536).clamp(0, file.size);
                  final blob = file.slice(offset, end);
                  yield (await blob.arrayBuffer().toDart).toDart.asUint8List();
                }
              },
            ),
          );
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
