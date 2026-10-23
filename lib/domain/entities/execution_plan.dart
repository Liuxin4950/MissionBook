/// 【业务实体】一个任务的执行方案，由 execution_plans 表保存。
///
/// 每个任务恰好有一个方案；任务开始后不再直接修改。
/// 本类的 steps 是文字列表，存储时才由仓储转换为 JSON；表结构在 data/local/tables/。
class ExecutionPlan {
  ExecutionPlan({
    required this.id,
    required this.missionId,
    required this.objective,
    required this.createdAt,
    required this.updatedAt,
    List<String> steps = const [],
    this.verificationCriteria,
    this.notes,
  }) : steps = List<String>.unmodifiable(steps);

  /// 执行方案自身的唯一编号。
  final String id;

  /// 所属任务的编号，对应 Mission.id。
  /// 同一个任务只允许有一个执行方案。
  final String missionId;

  /// 本次任务希望达到的具体目标，必须为去除首尾空白后的非空内容。
  /// 用户没有单独填写时，创建流程使用任务标题。
  final String objective;

  /// 有顺序的执行步骤，每个字符串表示一步。
  /// 未填写时使用空列表，表示没有列出步骤。
  final List<String> steps;

  /// 验收方向：用户准备用什么标准或材料说明任务结果。
  /// 自报策略允许为空；可选或强制材料策略要求非空。
  /// 它是一段用户填写的说明，不代表系统已经执行验证。
  final String? verificationCriteria;

  /// 其他补充说明，可以不填写。
  final String? notes;

  /// 方案首次创建的时刻，约定使用 UTC DateTime。
  final DateTime createdAt;

  /// 方案最近一次修改的时刻，约定使用 UTC DateTime。
  /// 首次创建时与 createdAt 相同。
  final DateTime updatedAt;
}
