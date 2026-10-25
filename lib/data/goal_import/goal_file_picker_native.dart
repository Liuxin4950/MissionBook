import 'dart:typed_data';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import '../../application/goals/goal_file_picker.dart';
import '../../application/goals/goal_outline_parser.dart';

GoalFilePicker createGoalFilePicker() => NativeGoalFilePicker();

class NativeGoalFilePicker implements GoalFilePicker {
  @override
  Future<Uint8List?> pickBytes() async {
    final file = await FileSelectorPlatform.instance.openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '目标大纲 JSON',
          extensions: ['json'],
          mimeTypes: ['application/json', 'text/json'],
        ),
      ],
      confirmButtonText: '导入目标大纲',
    );
    if (file == null) return null;
    if (!file.name.toLowerCase().endsWith('.json')) {
      throw const FormatException('请选择 .json 文件');
    }
    if (await file.length() > GoalOutlineParser.maxBytes) {
      throw const FormatException('文件超过 2 MiB 限制');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (builder.length + chunk.length > GoalOutlineParser.maxBytes) {
        throw const FormatException('文件超过 2 MiB 限制');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
