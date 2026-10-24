/// 用户手动决定的目标状态；任务完成数量不会自动改变它。
enum GoalStatus { active, paused, achieved, dropped }

/// 表达一个长期方向或希望达到的结果，不依赖 Flutter、Drift 或数据库行。
class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.why,
  });

  final String id; // 全局唯一身份；改名后仍是同一个目标。
  final String title; // 已去除首尾空白的非空名称。
  final String? description; // 目标说明；不填为 null。
  final String? why; // 希望实现它的原因；不填为 null。
  final GoalStatus status; // 初始为 active（正在推进）。
  final DateTime createdAt; // UTC 创建时刻。
  final DateTime updatedAt; // UTC 最近修改时刻。

  /// 在真正写入前检查创建约束，防止绕过表单的调用保存非法目标。
  void validateForCreation() {
    if (id.trim().isEmpty || id != id.trim()) {
      throw ArgumentError('目标编号不能为空或带有首尾空白');
    }
    if (title.trim().isEmpty || title != title.trim()) {
      throw ArgumentError('请填写目标名称，并去除首尾空白');
    }
    for (final value in [description, why]) {
      if (value != null && (value.isEmpty || value != value.trim())) {
        throw ArgumentError('可选说明为空时应使用 null，有内容时去除首尾空白');
      }
    }
    if (status != GoalStatus.active) {
      throw ArgumentError('新目标必须从正在推进开始');
    }
    if (!createdAt.isUtc || !updatedAt.isUtc || createdAt != updatedAt) {
      throw ArgumentError('新目标的创建与修改时间必须是同一个 UTC 时刻');
    }
  }
}
