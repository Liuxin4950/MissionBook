import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/execution_plan.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../local/app_database.dart';

import '../../domain/repositories/mission_repository.dart';

// 执行数据库操作需要Companion对象，这里提前写好，避免修改，更新的时候现写
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
  );
}

// 将数据库里读出的一条任务记录，还原为业务对象。反序列化数据
Mission missionFromRow(MissionRow row) {
  // 先取出可能为空的取消时间。
  final cancelledAt = row.cancelledAt;

  return Mission(
    // 这些字段在两种对象中的类型一致，直接复制。
    id: row.id,
    title: row.title,
    description: row.description,
    why: row.why,

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
  );
}

// 查询返回的排期行转回业务对象；日期仍保留计划时区下的日历日期。
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

  return MissionScheduleRevision(
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
}

// 把一条排期转换为数据库写入对象，返回给仓储使用。
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

// 把一份执行方案转换为数据库写入对象，不在这里保存。
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

// 实现类实现MissionRepository接口
class DriftMissionRepository implements MissionRepository {
  // 创建仓储对象
  DriftMissionRepository(this.database);
  // 数据库连接器
  final AppDatabase database;

  @override
  // 调用者：GetScheduledMissions.execute。
  // 输入：计划日期。过程：关联 → 筛选 → 排序 → 执行 → 转换。输出：业务列表。
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate) async {
    // 1. 指定要读取的两张表，并说明它们通过任务编号关联。
    // 这一步构造查询对象，尚未执行 SQL。
    final missions = database.missions;
    final schedules = database.missionScheduleRevisions;
    final query = database.select(missions).join([
      innerJoin(schedules, schedules.missionId.equalsExp(missions.id)),
    ]);

    // 2. 筛选当前排期与所选日期。
    // history 是排期表的别名；子查询针对当前任务找最大版本，不限制日期。
    final history = database.alias(schedules, 'schedule_history');
    final latestVersionForMission = database.selectOnly(history)
      ..addColumns([history.revisionNumber.max()])
      ..where(history.missionId.equalsExp(missions.id));
    final isLatestSchedule = schedules.revisionNumber.equalsExp(
      subqueryExpression<int>(latestVersionForMission),
    );
    final isSelectedDate = schedules.scheduledDate.equals(scheduledDate);
    query.where(isLatestSchedule & isSelectedDate);

    // 3. 固定任务先排，自选随后；两类分别使用各自的时间字段，再按 id 稳定排序。
    // caseMatch 将这条条件表达成 SQL 的 CASE；此时仍在描述查询规则。
    final fixedBeforeFlexible = schedules.timePolicy.caseMatch<int>(
      when: {const Constant('FIXED'): const Constant(0)},
      orElse: const Constant(1),
    );
    final timeWithinGroup = schedules.timePolicy.caseMatch<int>(
      when: {const Constant('FIXED'): schedules.fixedStartAt},
      orElse: missions.createdAt,
    );
    query.orderBy([
      OrderingTerm.asc(fixedBeforeFlexible),
      OrderingTerm.asc(timeWithinGroup),
      OrderingTerm.asc(missions.id),
    ]);

    // 4. get() 才真正执行一次 SQL。await 完成后，rows 是 List<TypedResult>。
    // 每个 TypedResult 同时带着关联到的任务行和排期行。
    final rows = await query.get();

    // 5. 逐条转换：关联结果 → 两张表的行对象 → 两个业务对象 → 一项列表数据。
    final result = <ScheduledMission>[];
    for (final row in rows) {
      final missionRow = row.readTable(missions); // MissionRow
      final scheduleRow = row.readTable(
        schedules,
      ); // MissionScheduleRevisionRow

      final mission = missionFromRow(missionRow); // 用户已有的反向转换函数
      final schedule = scheduleFromRow(scheduleRow);
      final item = ScheduledMission(mission: mission, schedule: schedule);
      result.add(item);
    }

    // 6. 交回查询业务入口，再由它把同一份列表交给今天页。
    return result;
  }

  @override
  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  }) async {
    // 先检查关联关系：排期、方案必须属于传入的这个任务。
    // || 表示“或者”，任意一个编号不一致就报错并停止执行。
    if (initialSchedule.missionId != mission.id ||
        executionPlan.missionId != mission.id) {
      throw ArgumentError('排期和执行方案必须属于当前任务');
    }

    // 接口要求：第一次创建的排期，版本号必须为 1。
    if (initialSchedule.revisionNumber != 1) {
      throw ArgumentError('首次排期版本号必须为 1');
    }

    // 新任务不能带着已取消的时间。
    if (mission.cancelledAt != null) {
      throw ArgumentError('新任务不能已经取消');
    }

    // 把下面的函数交给 Drift，由它在事务中执行。
    // 外层 await 等待整个事务完成。
    // 三次写入全部成功才提交，任意一次失败就一起回滚。
    await database.transaction(() async {
      // into 指定写入任务表。
      // 转换函数返回 Companion 对象，insert 接收它并执行写入。
      // await 等待任务保存完成，再继续保存引用它的排期。
      await database
          .into(database.missions)
          .insert(missionToCompanion(mission));

      // 保存同一任务的第一条排期。
      await database
          .into(database.missionScheduleRevisions)
          .insert(scheduleToCompanion(initialSchedule));

      // 保存同一任务的执行方案。
      await database
          .into(database.executionPlans)
          .insert(executionPlanToCompanion(executionPlan));
    });
  }
}
