import 'dart:typed_data';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import '../../application/goals/goal_file_picker.dart';
import '../../application/goals/goal_outline_parser.dart';
import '../../domain/entities/goal_package_import.dart';

GoalFilePicker createGoalFilePicker() => NativeGoalFilePicker();

class NativeGoalFilePicker implements GoalSourcePicker {
  @override
  Future<Uint8List?> pickBytes() async {
    final source = await pickSource();
    if (source == null) return null;
    if (source.length! > GoalOutlineParser.maxBytes) {
      throw const FormatException('文件超过 2 MiB 限制');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in source.openRead()) {
      if (builder.length + chunk.length > GoalOutlineParser.maxBytes) {
        throw const FormatException('文件超过 2 MiB 限制');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @override
  Future<GoalImportSource?> pickSource() async {
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
    final length = await file.length();
    if (length > GoalImportLimits.fileBytes) {
      throw const FormatException('文件超过 32 MiB 限制');
    }
    return GoalImportSource(
      name: file.name,
      length: length,
      openRead: file.openRead,
    );
  }
}
