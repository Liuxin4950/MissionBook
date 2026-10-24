/// 用枚举列出合法策略，避免在业务代码中随意拼写字符串。
enum VerificationPolicy {
  selfReport, // 用户自报
  optionalEvidence, // 可选材料
  requiredEvidence, // 强制材料
}

/// 当前只开放“再次尝试”：新任务关联来源，原任务的执行历史保持不变。
enum MissionRelationType { retry }

/// 【业务实体】一个任务的基本信息，由 missions 表保存。
///
/// 本类表达业务含义，不定义数据库列；例如策略用枚举，时间用 DateTime。
/// 表结构在 data/local/tables/missions.dart，存储类型由仓储负责转换。
class Mission {
  // 构造函数
  const Mission({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.why,
    this.cancelledAt,
    this.evidenceWaivedAt,
    this.sourceMissionId,
    this.relationType,
    this.verificationPolicy = VerificationPolicy.selfReport,
  });

  /// 任务的唯一身份；排期和执行方案通过 missionId 引用它。
  // final 固定对象创建后的字段值；业务修改需要构造新对象并经过写入入口。
  final String id;

  /// 去除首尾空白后的行动名称，由创建入口校验为非空。
  final String title;

  /// 可选的任务说明，未填写时为 null。
  final String? description;

  /// 为什么安排本次行动，未填写时为 null。
  final String? why;

  /// 完成报告后的材料要求，不表示材料已经提交或通过验证。
  final VerificationPolicy verificationPolicy;

  /// 任务创建的 UTC 时刻，数据库统一保存为毫秒时间戳。
  final DateTime createdAt;

  /// 最近业务修改的 UTC 时刻，创建时与 createdAt 相同。
  final DateTime updatedAt;

  /// null 表示没有取消；有值表示实际取消时刻。
  final DateTime? cancelledAt;

  /// 先选择补交、后来主动放弃可选材料的真实时刻；未放弃为 null。
  final DateTime? evidenceWaivedAt;

  /// 来自哪次已结束或已取消的任务；普通新建为 null，创建后不可修改。
  final String? sourceMissionId;
  final MissionRelationType? relationType;
}
