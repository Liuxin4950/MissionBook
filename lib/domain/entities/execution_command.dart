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
    this.submitOptionalEvidence,
    this.userReasonCategory,
    this.userReasonText,
    this.isRetrospective = false,
  });

  final String id; // 这次操作的编号，结果未确认时重试复用。
  final String missionId; // 操作哪一个任务，来自 detail.mission.id。
  final int expectedSequence; // 页面读到的最新事件序号；尚未开始时为0。
  final ExecutionEventType type; // 本次动作，例如 start（开始）。
  final String? scheduleRevisionId; // 仅开始携带 detail.schedule.id，防止使用旧计划。
  final int? grantedDurationMinutes;
  final String? reason;
  final UserReportedResult? userReportedResult;
  final bool? submitOptionalEvidence; // 仅可选材料且报告完成时，明确选择交或不交。
  // 未完成的用户原因保存在 FailureRecord，不混进 END.reason。
  final String? userReasonCategory;
  final String? userReasonText;
  final bool isRetrospective;
}

/// 冲突需先刷新事实，不能给旧命令换个序号后盲目重试。
class ExecutionConflict implements Exception {
  const ExecutionConflict(this.message);
  final String message;
  @override
  String toString() => message;
}
