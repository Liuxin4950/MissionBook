/// 一条执行记录所表达的动作。
enum ExecutionEventType {
  start, // 开始，同时绑定当时采用的排期版本。
  pause, // 暂停，可以填写原因。
  resume, // 从暂停恢复执行。
  extend, // 增加投入额度，不改变执行或暂停状态。
  stop, // 固定日程到点停止计时，等待用户确认结果。
  end, // 结束执行，同时记录用户报告。
}

/// 用户在结束执行时报告的结果。
/// 没有 END 时就没有报告，用 null 表达，不增加“待报告”枚举。
enum UserReportedResult { completed, notCompleted }

/// 【业务实体】一条已经发生的执行动作。
/// 合法性由事件规则及写入事务校验；对象构造本身不代表已经入库。
class ExecutionEvent {
  const ExecutionEvent({
    required this.id,
    required this.missionId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.scheduleRevisionId,
    this.grantedDurationMinutes,
    this.reason,
    this.userReportedResult,
    this.submitOptionalEvidence,
    this.isRetrospective = false,
  });

  /// 本条事件的唯一编号。
  final String id;

  /// 所属任务编号，对应 Mission.id。
  final String missionId;

  /// 同一任务内从1开始连续递增；不是所有任务共用一个序号。
  final int sequence;

  /// 本条记录表达的动作。
  final ExecutionEventType type;

  /// 动作实际发生的时刻，统一使用UTC。
  final DateTime occurredAt;

  /// START或历史补报必填；引用同一任务当时最新的排期版本。
  /// 其他事件为空。
  final String? scheduleRevisionId;

  /// 仅 EXTEND 必填，单位为分钟，必须是正整数。
  /// 表示本次增加多少分钟，其他事件为空。
  final int? grantedDurationMinutes;

  /// PAUSE的可选原因，或历史补报必须保存的用户依据；其他事件为空。
  /// 结束时的未完成原因以后保存到 FailureRecord。
  final String? reason;

  /// 仅 END 必填，其他事件为空。
  final UserReportedResult? userReportedResult;

  /// 仅可选材料策略下、END报告完成时必填。
  /// true表示稍后提交材料，false表示直接结束；
  /// 其他情况为空，不能用false代替“不适用”。
  final bool? submitOptionalEvidence;
  // 独立的历史完成自报：没有 START，也不产生专注时长；reason 保存补记依据。
  final bool isRetrospective;
}
