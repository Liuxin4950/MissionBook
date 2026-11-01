import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import '../../application/goals/goal_file_picker.dart';
import '../../domain/entities/goal_package_import.dart';

GoalFilePicker createGoalFilePicker() => NativeGoalFilePicker();

class NativeGoalFilePicker implements GoalFilePicker {
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
