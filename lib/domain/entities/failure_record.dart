/// 已提交的未完成/材料超时事实。当前生产流程只开放自报任务未完成记录。
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

const failureReasonLabels = <String, String>{
  'TIME_INSUFFICIENT': '时间不足',
  'TOO_DIFFICULT': '难度较大',
  'URGENT_EVENT': '临时有事',
  'BAD_STATE': '状态不佳',
  'DO_NOT_WANT_CONTINUE': '不想继续',
  'ENVIRONMENT_PROBLEM': '环境影响',
  'OTHER': '其他',
};
