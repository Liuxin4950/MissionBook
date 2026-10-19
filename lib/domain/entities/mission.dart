// 用枚举列出合法策略，避免在业务代码中随意拼写字符串。
enum VerificationPolicy {
  selfReport, // 用户自报
  optionalEvidence, // 可选材料
  requiredEvidence, // 强制材料
}

// 一个任务的基本业务信息。
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
    this.verificationPolicy = VerificationPolicy.selfReport,
  });

  // final 表示对象创建后，不能直接重新赋值这些字段。
  final String id;
  final String title;
  final String? description; // 任务描述
  final String? why; //为什么
  final VerificationPolicy verificationPolicy;
  // 业务层使用 DateTime；数据库怎样存储由 data 层负责。
  final DateTime createdAt;
  final DateTime updatedAt;
  // null 表示没有取消；有值表示实际取消时刻。
  final DateTime? cancelledAt;
}
