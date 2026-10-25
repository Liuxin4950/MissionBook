import 'dart:typed_data';

/// 只读取用户主动选取的 JSON 文件；取消返回 null，不保存草稿或目标。
abstract interface class GoalFilePicker {
  Future<Uint8List?> pickBytes();
}
