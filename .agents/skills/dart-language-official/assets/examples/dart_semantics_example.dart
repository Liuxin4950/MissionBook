/// Dart 3 typed contracts, records, and exhaustive switch examples.

final class NonBlankTitle {
  NonBlankTitle._(this.value);                                      // 构造只供校验工厂调用。

  final String value;                                               // 有效标题在创建后不可更改。

  factory NonBlankTitle.parse(Object? candidate) {                 // 输入边界允许未知类型。
    if (candidate is! String) {                                     // 排除 null 与非 String 输入。
      throw const FormatException('Title must be a string');        // 显式表达错误原因。
    }
    final String trimmed = candidate.trim();                        // 使用标准化后的值校验。
    if (trimmed.isEmpty) {                                          // 不允许只有空白的字符串。
      throw const FormatException('Title must not be blank');       // 不静默填充默认值。
    }
    return NonBlankTitle._(trimmed);                                 // 创建符合约束的值对象。
  }

  @override
  String toString() => value;                                        // 文本展示与值保持一致。
}

enum ExecutionUiState { notStarted, running, paused, closed }       // 用枚举表达互斥 UI 投影。

String actionLabel(ExecutionUiState state) => switch (state) {      // 枚举 switch 不用默认分支吞掉新状态。
  ExecutionUiState.notStarted => '开始任务',                          // 已安排但未执行。
  ExecutionUiState.running => '暂停任务',                             // 正在运行的操作。
  ExecutionUiState.paused => '继续任务',                              // 暂停中的操作。
  ExecutionUiState.closed => '查看结果',                              // 已关闭后的操作。
};

({String missionId, int revisionNumber}) latestScheduleIdentity(  // 临时聚合用具名 Record。
  String missionId,                                                  // 任务身份。
  int revisionNumber,                                               // 快照版本号。
) {
  if (missionId.trim().isEmpty || revisionNumber < 1) {             // 显式校验跨字段不变量。
    throw const FormatException('Invalid schedule identity');      // 拒绝非法输入。
  }
  return (missionId: missionId, revisionNumber: revisionNumber);    // 返回结构化的不可变 Record。
}

void main() {                                                       // 独立示例入口，需 Dart 3 SDK。
  final NonBlankTitle title = NonBlankTitle.parse('  学习 Flutter  '); // 工厂校验 trim 结果。
  assert(title.value == '学习 Flutter');                             // 演示期断言，不是生产校验。
  assert(actionLabel(ExecutionUiState.paused) == '继续任务');         // 验证枚举映射的示意断言。
  final identity = latestScheduleIdentity('mission-1', 2);           // 创建仅供临时使用的 Record。
  assert(identity.revisionNumber == 2);                             // 验证具名字段语义。
}
