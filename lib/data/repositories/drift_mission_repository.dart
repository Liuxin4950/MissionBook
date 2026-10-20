import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/execution_plan.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_schedule_revision.dart';
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
