/// 已提交的未完成/材料超时事实。
///
/// 两类 trigger 都已接通生产写入：用户报告未完成与 END 事件同事务写入，
/// 材料超时由截止补算或“提交时已过期”分支写入；两类都不伪造 END 事件。
class FailureRecord {
  const FailureRecord({
    required this.id,
    required this.missionId,
    required this.trigger,
    required this.occurredAt,
    required this.createdAt,
    this.userReasonCategory,
    this.userReasonText,
  });

  final String id;
  final String missionId;
  final String trigger;
  final DateTime occurredAt;
  final DateTime createdAt;
  final String? userReasonCategory;
  final String? userReasonText;
}

/// 失败记录 trigger 的持久化取值。
///
/// 这两个字符串会写进数据库，并被 failure_records 表的 CHECK 约束认可
/// （见 lib/data/local/tables/failure_records.dart）；改动取值等于改变
/// 历史数据语义，必须同步表约束与迁移。业务代码一律引用这两个常量，
/// 不再各自手写字符串，避免拼写不一致导致静默的数据分歧。
const userMarkedNotCompletedTrigger = 'USER_MARKED_NOT_COMPLETED';
const evidenceDeadlineMissedTrigger = 'EVIDENCE_DEADLINE_MISSED';

/// 失败记录编号由同一次 END 事件编号派生。
///
/// 一次 END 的每一类事实只有一个编号，配合 (mission_id, trigger) 唯一约束
/// 实现幂等：重复补算或重试不会写出第二条同类记录。
String userMarkedFailureId(String endEventId) => '$endEventId:failure';
String evidenceDeadlineFailureId(String endEventId) =>
    '$endEventId:evidence-deadline';

const failureReasonLabels = <String, String>{
  'TIME_INSUFFICIENT': '时间不足',
  'TOO_DIFFICULT': '难度较大',
  'URGENT_EVENT': '临时有事',
  'BAD_STATE': '状态不佳',
  'DO_NOT_WANT_CONTINUE': '不想继续',
  'ENVIRONMENT_PROBLEM': '环境影响',
  'OTHER': '其他',
};
