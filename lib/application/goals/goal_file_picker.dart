import 'dart:typed_data';
import '../../domain/entities/goal_package_import.dart';

/// 只读取用户主动选取的 JSON 文件；取消返回 null，不保存草稿或目标。
abstract interface class GoalFilePicker {
  Future<Uint8List?> pickBytes();
}

/// 新文件入口返回可流读来源；保留旧接口供已有调用及测试使用。
abstract interface class GoalSourcePicker implements GoalFilePicker {
  Future<GoalImportSource?> pickSource();
}
