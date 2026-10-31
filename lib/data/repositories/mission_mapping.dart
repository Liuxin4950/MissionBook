part of 'drift_mission_repository.dart';

/// 将任务转换为插入参数；枚举保存为稳定文本，绝对时刻保存为毫秒时间戳。
// Companion 只是写入参数；实际执行和提交由下方仓储负责。
MissionsCompanion missionToCompanion(Mission mission) {
  // 使用生成的构造函数，组装这次要写入的字段，再返回给调用者。
  return MissionsCompanion.insert(
    // 编号、标题都是字符串，直接取业务对象里的值。
    id: mission.id,
    title: mission.title,
    // Value 表示明确提供这一列的值：有文字就写文字，为 null 就写空值。
    // 它与 Value.absent()（省略这一列）不同。
    description: Value(mission.description),
    why: Value(mission.why),
    goalId: Value(mission.goalId),
    goalNodeId: Value(mission.goalNodeId),
    // 业务对象使用枚举，数据库约定保存下面这些文本。
    // switch 按任务的实际策略选出字符串，再包装成 Value 传给该列。
    verificationPolicy: Value(switch (mission.verificationPolicy) {
      VerificationPolicy.selfReport => 'SELF_REPORT',
      VerificationPolicy.optionalEvidence => 'OPTIONAL_EVIDENCE',
      VerificationPolicy.requiredEvidence => 'REQUIRED_EVIDENCE',
    }),
    // 时间列接收整数，所以把任务原有的 DateTime 转成毫秒时间戳。
    createdAt: mission.createdAt.millisecondsSinceEpoch,
    updatedAt: mission.updatedAt.millisecondsSinceEpoch,
    // 取消时刻可能为空：?. 在有时刻时取毫秒数，否则得到 null。
    cancelledAt: Value(mission.cancelledAt?.millisecondsSinceEpoch),
    evidenceWaivedAt: Value(mission.evidenceWaivedAt?.millisecondsSinceEpoch),
    sourceMissionId: Value(mission.sourceMissionId),
    relationType: Value(mission.relationType == null ? null : 'RETRY'),
  );
}

/// 将数据库行还原为任务，使用 UTC 时间；未知策略抛出 [FormatException]。
Mission missionFromRow(MissionRow row) {
  // 先取出可能为空的取消时间。
  final cancelledAt = row.cancelledAt;
  if ((row.sourceMissionId == null) != (row.relationType == null)) {
    throw const FormatException('再次尝试来源与关系类型必须同时存在');
  }
  return Mission(
    // 这些字段在两种对象中的类型一致，直接复制。
    id: row.id,
    title: row.title,
    description: row.description,
    why: row.why,
    goalId: row.goalId,
    goalNodeId: row.goalNodeId,
    sourceMissionId: row.sourceMissionId,
    relationType: switch (row.relationType) {
      null => null,
      'RETRY' => MissionRelationType.retry,
      _ => throw FormatException('未知任务关系：${row.relationType}'),
    },
    // 数据库存的是字符串，业务对象使用枚举。
    verificationPolicy: switch (row.verificationPolicy) {
      'SELF_REPORT' => VerificationPolicy.selfReport,
      'OPTIONAL_EVIDENCE' => VerificationPolicy.optionalEvidence,
      'REQUIRED_EVIDENCE' => VerificationPolicy.requiredEvidence,
      // _ 接住其他所有值。
      // 遇到不认识的存储值时明确报错，避免默默解释为另一种策略。
      _ => throw FormatException('未知的验证策略：${row.verificationPolicy}'),
    },
    // 将数据库中的整数毫秒数还原成 UTC 时间对象。
    // 第一个参数来自当前这行记录，isUtc 指定结果使用 UTC。
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    // 没有取消时间就保留 null；有值才执行时间转换。
    cancelledAt: cancelledAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(cancelledAt, isUtc: true),
    evidenceWaivedAt: row.evidenceWaivedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row.evidenceWaivedAt!,
            isUtc: true,
          ),
  );
}

/// 将排期行还原为业务对象，保留日历日期并还原 UTC 绝对时刻。
///
/// 时间策略未知或与固定开始时刻矛盾时抛出 [FormatException]。
MissionScheduleRevision scheduleFromRow(MissionScheduleRevisionRow row) {
  DateTime? utcTime(int? milliseconds) => milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  final policy = switch (row.timePolicy) {
    'FIXED' => TimePolicy.fixed,
    'FLEXIBLE' => TimePolicy.flexible,
    _ => throw FormatException('未知的时间策略：${row.timePolicy}'),
  };
  if ((policy == TimePolicy.fixed) != (row.fixedStartAt != null)) {
    throw const FormatException('时间策略与固定开始时刻不一致');
  }
  final schedule = MissionScheduleRevision(
    id: row.id,
    missionId: row.missionId,
    revisionNumber: row.revisionNumber,
    scheduledDate: row.scheduledDate,
    timeZone: row.timeZone,
    timePolicy: policy,
    fixedStartAt: utcTime(row.fixedStartAt),
    plannedDurationMinutes: row.plannedDurationMinutes,
    evidenceDeadlineAt: utcTime(row.evidenceDeadlineAt),
    changeReason: row.changeReason,
    changedAt: DateTime.fromMillisecondsSinceEpoch(row.changedAt, isUtc: true),
  );
  try {
    validateMissionSchedule(schedule);
  } on ArgumentError catch (error) {
    // 读取损坏的旧库时明确报错，不让坏日期拖到 Widget 解析阶段才崩溃。
    throw FormatException('排期数据无效：${error.message}');
  }
  return schedule;
}

/// 将排期转换为插入参数，保留日期字符串并将绝对时刻转换为毫秒。
MissionScheduleRevisionsCompanion scheduleToCompanion(
  MissionScheduleRevision schedule,
) {
  return MissionScheduleRevisionsCompanion.insert(
    id: schedule.id,
    missionId: schedule.missionId,
    revisionNumber: schedule.revisionNumber,
    scheduledDate: schedule.scheduledDate,
    timeZone: schedule.timeZone,
    // 枚举转成表中约定的文本；计划日期仍保留 YYYY-MM-DD 字符串。
    timePolicy: Value(switch (schedule.timePolicy) {
      TimePolicy.flexible => 'FLEXIBLE',
      TimePolicy.fixed => 'FIXED',
    }),
    fixedStartAt: Value(schedule.fixedStartAt?.millisecondsSinceEpoch),
    plannedDurationMinutes: schedule.plannedDurationMinutes,
    evidenceDeadlineAt: Value(
      schedule.evidenceDeadlineAt?.millisecondsSinceEpoch,
    ),
    changeReason: Value(schedule.changeReason),
    changedAt: schedule.changedAt.millisecondsSinceEpoch,
  );
}

/// 将方案转换为插入参数，步骤按原顺序编码为 JSON；不执行写入。
ExecutionPlansCompanion executionPlanToCompanion(ExecutionPlan plan) {
  return ExecutionPlansCompanion.insert(
    id: plan.id,
    missionId: plan.missionId,
    objective: plan.objective,
    // 表中的 steps 是文本列，把有序字符串列表编码成 JSON 文本。
    steps: Value(jsonEncode(plan.steps)),
    verificationCriteria: Value(plan.verificationCriteria),
    notes: Value(plan.notes),
    createdAt: plan.createdAt.millisecondsSinceEpoch,
    updatedAt: plan.updatedAt.millisecondsSinceEpoch,
  );
}

/// 将方案行还原为业务对象；步骤必须是只包含字符串的 JSON 数组。
ExecutionPlan executionPlanFromRow(ExecutionPlanRow row) {
  // 写入时 jsonEncode 把列表变成文本；读取时 jsonDecode 做反向转换。
  // JSON 也可能是数字、对象或混合数组，因此不能直接强制转换成 List<String>。
  // Object? 可以接住任意 JSON 值（包括 null）；检查后才把字符串收进 steps。
  final Object? decoded = jsonDecode(row.steps);
  if (decoded is! List<Object?>) {
    throw const FormatException('执行步骤必须是 JSON 数组');
  }
  final steps = <String>[];
  for (final step in decoded) {
    if (step is! String) {
      throw const FormatException('每个执行步骤必须是文字');
    }
    steps.add(step);
  }
  return ExecutionPlan(
    id: row.id,
    missionId: row.missionId,
    objective: row.objective,
    steps: steps,
    verificationCriteria: row.verificationCriteria,
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
  );
}
