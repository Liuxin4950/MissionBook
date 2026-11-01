import '../../domain/entities/goal_package_import.dart';

/// 只读取用户主动选取的 JSON 文件；取消返回 null，正文由导入器按上限流读。
abstract interface class GoalFilePicker {
  Future<GoalImportSource?> pickSource();
}
