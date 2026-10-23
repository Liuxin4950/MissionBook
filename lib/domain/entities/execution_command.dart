import 'execution_event.dart';

/// 一次执行动作的“意图”，不是已保存事件。
/// 页面先固定 id 和看到的序号，失败重试沿用同一个对象；时间和新序号由仓储决定。
class ExecutionCommand {
  const ExecutionCommand({
    required this.id,
    required this.missionId,
    required this.expectedSequence,
    required this.type,
    this.scheduleRevisionId,
    this.grantedDurationMinutes,
    this.reason,
    this.userReportedResult,
    this.userReasonCategory,
    this.userReasonText,
  });

  final String id;
  final String missionId;
  final int expectedSequence;
  final ExecutionEventType type;
  final String? scheduleRevisionId;
  final int? grantedDurationMinutes;
  final String? reason;
  final UserReportedResult? userReportedResult;
  // 未完成的用户原因保存在 FailureRecord，不混进 END.reason。
  final String? userReasonCategory;
  final String? userReasonText;
}

/// 冲突需先刷新事实，不能给旧命令换个序号后盲目重试。
class ExecutionConflict implements Exception {
  const ExecutionConflict(this.message);
  final String message;
  @override
  String toString() => message;
}
