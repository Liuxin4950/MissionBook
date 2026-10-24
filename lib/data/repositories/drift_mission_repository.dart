import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/execution_plan.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../../domain/entities/mission_detail.dart';
import '../local/app_database.dart';
import 'execution_event_mapping.dart';
import '../../domain/entities/execution_command.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/failure_record.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/rules/execution_event_rules.dart';

import '../../domain/repositories/mission_repository.dart';

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

/// 使用同一数据库连接完成原子创建、列表查询与详情读取。
class DriftMissionRepository implements MissionRepository {
  /// 接收应用持有的连接；本仓储不自行创建或关闭数据库。
  DriftMissionRepository(this.database, {this.clock = DateTime.now});

  /// 创建与查询共用的数据库连接。
  final AppDatabase database;
  // 只用于捕获实际操作时刻；测试注入可控时钟，不允许命令指定 occurredAt。
  final DateTime Function() clock;

  Future<void> _acquireWrite(String missionId) async {
    // 显式在读取事实前执行写语句，字段值不变；同库连接受 SQLite 写锁约束。
    // 当前 Native/Wasm 驱动也使用 BEGIN IMMEDIATE，不能误认为 transaction 默认都为延迟事务。
    await database.customStatement(
      'UPDATE missions SET updated_at = updated_at WHERE id = ?',
      [missionId],
    );
  }

  @override
  Future<ExecutionEvent> execute(ExecutionCommand command) async {
    String? clean(String? text) {
      final value = text?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    if (command.id.trim().isEmpty ||
        command.missionId.trim().isEmpty ||
        command.expectedSequence < 0) {
      throw ArgumentError('操作编号、任务编号和预期序号无效');
    }
    final reason = clean(command.reason);
    final category = command.userReasonCategory;
    final reasonText = clean(command.userReasonText);
    if (category != null && !failureReasonLabels.containsKey(category)) {
      throw ArgumentError('未完成原因类别无效');
    }
    if ((category != null || reasonText != null) &&
        (command.type != ExecutionEventType.end ||
            command.userReportedResult != UserReportedResult.notCompleted)) {
      throw ArgumentError('只有报告未完成时可以填写未完成原因');
    }
    return database.transaction(() async {
      await _acquireWrite(command.missionId);
      // 先查身份，再检查当前序号；成功后丢失响应的重试不会再次执行。
      final existingQuery = database.select(database.executionEvents)
        ..where((table) => table.id.equals(command.id));
      final existing = await existingQuery.getSingleOrNull();
      if (existing != null) {
        final event = eventFromRow(existing);
        final failures =
            await (database.select(database.failureRecords)..where(
                  (table) =>
                      table.missionId.equals(event.missionId) &
                      table.trigger.equals('USER_MARKED_NOT_COMPLETED'),
                ))
                .get();
        final oldFailure = failures.isEmpty ? null : failures.single;
        final needsFailure =
            event.type == ExecutionEventType.end &&
            event.userReportedResult == UserReportedResult.notCompleted;
        if (event.missionId != command.missionId ||
            event.type != command.type ||
            event.sequence != command.expectedSequence + 1 ||
            event.scheduleRevisionId != command.scheduleRevisionId ||
            event.grantedDurationMinutes != command.grantedDurationMinutes ||
            event.reason != reason ||
            event.userReportedResult != command.userReportedResult ||
            (needsFailure &&
                (oldFailure == null ||
                    oldFailure.userReasonCategory != category ||
                    oldFailure.userReasonText != reasonText))) {
          throw const ExecutionConflict('同一操作编号对应的输入不同，请刷新后重新操作');
        }
        return event;
      }
      // 这里读取的是一整份任务详情：既要检查旧序号/阶段，也要核对开始绑定的排期。
      // 排期描述“打算什么时候做、做多久”；事件描述“实际开始/暂停过什么”。
      final detail = await findDetail(command.missionId);
      if (detail == null) throw const ExecutionConflict('任务已不存在，请刷新');
      if (detail.mission.verificationPolicy != VerificationPolicy.selfReport) {
        throw const ExecutionConflict('材料任务尚未开放执行，请先使用自报任务');
      }
      if (detail.lastSequence != command.expectedSequence) {
        throw const ExecutionConflict('执行记录已变化，请刷新后重新操作');
      }
      if (command.type == ExecutionEventType.start &&
          command.scheduleRevisionId != detail.schedule.id) {
        // 页面若看的是旧排期，不能悄悄换成新排期替用户开始，必须刷新后再确认。
        throw const ExecutionConflict('排期已变化，请刷新并确认新计划后开始');
      }
      if (command.type == ExecutionEventType.start ||
          command.type == ExecutionEventType.resume) {
        final running = await findActive();
        for (final other in running) {
          if (other.mission.id != command.missionId &&
              other.phase == MissionPhase.running) {
            throw ExecutionConflict('“${other.mission.title}”正在执行，请先暂停或结束它');
          }
        }
      }
      // 已取得写锁、重读事实后才捕获时间，精度与持久化统一到毫秒。
      final now = DateTime.fromMillisecondsSinceEpoch(
        clock().toUtc().millisecondsSinceEpoch,
        isUtc: true,
      );
      if (detail.events.isNotEmpty &&
          now.isBefore(detail.events.last.occurredAt)) {
        throw const ExecutionConflict('系统时间早于上一条记录，请校正系统时间后重试');
      }
      final event = ExecutionEvent(
        id: command.id,
        missionId: command.missionId,
        sequence: command.expectedSequence + 1,
        type: command.type,
        occurredAt: now,
        scheduleRevisionId: command.scheduleRevisionId,
        grantedDurationMinutes: command.grantedDurationMinutes,
        reason: reason,
        userReportedResult: command.userReportedResult,
      );
      // 复用已有唯一推演核心；非法 START/END、取消后开始等均不能写入。
      validateExecutionHistory(detail.mission, [...detail.events, event]);
      await database
          .into(database.executionEvents)
          .insert(eventToCompanion(event));
      if (event.type == ExecutionEventType.end &&
          event.userReportedResult == UserReportedResult.notCompleted) {
        await database
            .into(database.failureRecords)
            .insert(
              FailureRecordsCompanion.insert(
                id: '${event.id}:failure',
                missionId: event.missionId,
                trigger: 'USER_MARKED_NOT_COMPLETED',
                occurredAt: now.millisecondsSinceEpoch,
                createdAt: now.millisecondsSinceEpoch,
                userReasonCategory: Value(category),
                userReasonText: Value(reasonText),
              ),
            );
      }
      return event;
    });
  }

  @override
  Future<List<MissionDetail>> findActive() => _findByExecution(ended: false);

  @override
  Future<List<MissionDetail>> findFinished() => _findByExecution(ended: true);

  @override
  Future<List<MissionDetail>> findCancelled() => database.transaction(() async {
    final rows =
        await (database.select(database.missions)
              ..where((row) => row.cancelledAt.isNotNull())
              ..orderBy([
                (row) => OrderingTerm.desc(row.cancelledAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final result = <MissionDetail>[];
    for (final row in rows) {
      final detail = await findDetail(row.id);
      if (detail == null) throw const FormatException('取消记录所属任务缺失');
      result.add(detail);
    }
    return result;
  });

  Future<List<MissionDetail>> _findByExecution({required bool ended}) {
    return database.transaction(() async {
      final rows = await database
          .customSelect(
            "SELECT DISTINCT mission_id FROM execution_events WHERE type = 'START' AND mission_id ${ended ? 'IN' : 'NOT IN'} (SELECT mission_id FROM execution_events WHERE type = 'END')",
            readsFrom: {database.executionEvents},
          )
          .get();
      final details = <MissionDetail>[];
      for (final row in rows) {
        final detail = await findDetail(row.read<String>('mission_id'));
        if (detail == null) throw const FormatException('执行事件所属任务缺失');
        details.add(detail);
      }
      details.sort((a, b) {
        if (!ended && a.phase != b.phase) {
          return a.phase == MissionPhase.running ? -1 : 1;
        }
        final timeOrder = b.events.last.occurredAt.compareTo(
          a.events.last.occurredAt,
        );
        return timeOrder != 0
            ? timeOrder
            : a.mission.id.compareTo(b.mission.id);
      });
      return details;
    });
  }

  @override
  Future<void> edit({
    required MissionDetail original,
    required String title,
    required String objective,
    required MissionScheduleRevision schedule,
  }) async {
    final missionId = original.mission.id;
    if (missionId.trim().isEmpty ||
        title.trim().isEmpty ||
        objective.trim().isEmpty ||
        schedule.missionId != missionId) {
      throw ArgumentError('任务编号、名称、具体目标或排期关联无效');
    }
    await database.transaction(() async {
      await _acquireWrite(missionId);
      // 重读的是事务内最新快照，不能依靠编辑页打开时的状态放行。
      final current = await findDetail(missionId);
      if (current == null) {
        throw const MissionEditConflict('任务已不存在，请返回列表刷新');
      }
      if (current.mission.cancelledAt != null) {
        throw const MissionEditConflict('任务已取消，不能再编辑，请返回详情刷新');
      }
      if (current.mission.verificationPolicy != VerificationPolicy.selfReport) {
        throw const MissionEditConflict('任务完成方式已变化，请返回详情刷新');
      }
      if (current.events.isNotEmpty) {
        throw const MissionEditConflict('任务已经开始，不能再修改任务与排期');
      }
      final scheduleChanged = !_sameSchedule(current.schedule, schedule);
      final titleChanged = current.mission.title != title;
      final objectiveChanged = current.executionPlan.objective != objective;
      // 无改动、双击或重试同一份已成功的内容都不制造新版本或修改时间。
      if (!scheduleChanged && !titleChanged && !objectiveChanged) return;

      final oldMission = original.mission;
      final oldPlan = original.executionPlan;
      if (current.schedule.id != original.schedule.id ||
          current.mission.updatedAt != oldMission.updatedAt ||
          current.mission.title != oldMission.title ||
          current.executionPlan.id != oldPlan.id ||
          current.executionPlan.updatedAt != oldPlan.updatedAt ||
          current.executionPlan.objective != oldPlan.objective) {
        throw const MissionEditConflict('任务已被修改，输入已保留；请返回详情刷新后重新编辑');
      }
      if (scheduleChanged &&
          (schedule.revisionNumber != current.schedule.revisionNumber + 1 ||
              schedule.timeZone != current.schedule.timeZone ||
              schedule.evidenceDeadlineAt != null ||
              schedule.plannedDurationMinutes <= 0 ||
              (schedule.timePolicy == TimePolicy.fixed) !=
                  (schedule.fixedStartAt != null))) {
        throw ArgumentError('排期提案与当前任务不一致');
      }
      final now = schedule.changedAt.millisecondsSinceEpoch;
      // 只写本次开放的字段；说明、Why、策略及身份信息不会被表单旧值覆盖。
      final missionUpdate = database.update(database.missions);
      missionUpdate.where((table) => table.id.equals(missionId));
      await missionUpdate.write(
        MissionsCompanion(title: Value(title), updatedAt: Value(now)),
      );
      if (objectiveChanged) {
        final planUpdate = database.update(database.executionPlans);
        planUpdate.where((table) => table.id.equals(current.executionPlan.id));
        await planUpdate.write(
          ExecutionPlansCompanion(
            objective: Value(objective),
            updatedAt: Value(now),
          ),
        );
      }
      if (scheduleChanged) {
        // insert 追加完整快照，绝不 update 旧排期；任一步失败会回滚上面的修改。
        await database
            .into(database.missionScheduleRevisions)
            .insert(scheduleToCompanion(schedule));
      }
    });
  }

  // 比较日期、时区、策略、时刻、时长与截止；身份和生成信息不代表内容变化。
  bool _sameSchedule(MissionScheduleRevision a, MissionScheduleRevision b) =>
      a.scheduledDate == b.scheduledDate &&
      a.timeZone == b.timeZone &&
      a.timePolicy == b.timePolicy &&
      a.fixedStartAt == b.fixedStartAt &&
      a.plannedDurationMinutes == b.plannedDurationMinutes &&
      a.evidenceDeadlineAt == b.evidenceDeadlineAt;

  @override
  Future<void> cancel(String missionId) async {
    if (missionId.trim().isEmpty) {
      throw ArgumentError('任务编号不能为空');
    }

    // 页面展示的是旧快照；在同一写事务内重读，再决定是否修改。
    await database.transaction(() async {
      await _acquireWrite(missionId);
      final missions = database.missions;
      final query = database.select(missions);
      query.where((table) => table.id.equals(missionId));
      final row = await query.getSingleOrNull();
      if (row == null) {
        throw StateError('任务不存在，无法取消');
      }
      // 重复请求不覆盖第一次取消的时间，也不更新 updatedAt。
      if (row.cancelledAt != null) return;

      final events =
          await (database.select(database.executionEvents)
                ..where((table) => table.missionId.equals(missionId))
                ..limit(1))
              .get();
      if (events.isNotEmpty) {
        throw const ExecutionConflict('任务已经开始，请通过结束报告选择未完成');
      }
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final update = database.update(missions);
      update.where(
        (table) => table.id.equals(missionId) & table.cancelledAt.isNull(),
      );
      // 普通 Companion 只写这两个字段；标题、排期历史和方案保持原样。
      final changed = await update.write(
        MissionsCompanion(cancelledAt: Value(now), updatedAt: Value(now)),
      );
      if (changed != 1) {
        throw StateError('任务状态已变化，请刷新后重试');
      }
    });
  }

  @override
  Future<MissionDetail?> findDetail(String missionId) async {
    return database.transaction(() async {
      // 以下变量是表的引用，用于组织查询；此时还没有读出某个任务的数据。
      final missions = database.missions;
      final schedules = database.missionScheduleRevisions;
      final plans = database.executionPlans;

      // ① 按同一个 missionId 关联“任务本身＋排期＋行动方案”。
      // 查排期是为了详情展示和 START 的计划绑定，不是用计划日期判断执行中。
      // 一个任务可以有多个排期版本，所以按版本倒序，只取最新的一条。
      // leftOuterJoin 会保留任务本身，即使它缺少排期/方案，也能与“任务不存在”区分。
      final query = database.select(missions).join([
        leftOuterJoin(schedules, schedules.missionId.equalsExp(missions.id)),
        leftOuterJoin(plans, plans.missionId.equalsExp(missions.id)),
      ]);
      query.where(missions.id.equals(missionId));
      query.orderBy([OrderingTerm.desc(schedules.revisionNumber)]);
      query.limit(1);

      // 到这里才执行 SQL；同一条语句读取三表，避免分开读时混入不同次修改的结果。
      final joinedRow = await query.getSingleOrNull();
      if (joinedRow == null) return null;

      final scheduleRow = joinedRow.readTableOrNull(schedules);
      final planRow = joinedRow.readTableOrNull(plans);
      if (scheduleRow == null || planRow == null) {
        throw const FormatException('任务缺少排期或执行方案');
      }

      // ② 查这个任务的全部执行事件，按 sequence 从1向后读，不按计划日期截断。
      // eventRows 是数据库行；下面转换得到的 events 才是业务对象列表。
      final eventRows =
          await (database.select(database.executionEvents)
                ..where((table) => table.missionId.equals(missionId))
                ..orderBy([(table) => OrderingTerm.asc(table.sequence)]))
              .get();
      // ③ 失败事实供已结束任务校验报告；刚创建或刚开始时通常为空。
      final failureRows = await (database.select(
        database.failureRecords,
      )..where((table) => table.missionId.equals(missionId))).get();
      // ④ 行对象 → 业务对象。下面五个变量正好对应 MissionDetail 的五个成员。
      final mission = missionFromRow(joinedRow.readTable(missions));
      final schedule = scheduleFromRow(scheduleRow);
      final executionPlan = executionPlanFromRow(planRow);
      final events = List<ExecutionEvent>.unmodifiable(
        eventRows.map(eventFromRow),
      );
      final failures = List<FailureRecord>.unmodifiable(
        failureRows.map(failureFromRow),
      );
      // 查询中的坏历史在 Future 内报错，由页面显示读取失败，不等到排版时崩溃。
      deriveSelfReportMissionPhase(mission, events, failures);
      // ⑤ 打包成一次查询结果，不新增一张详情表，也不向数据库写入阶段。
      return MissionDetail(
        mission: mission,
        schedule: schedule,
        executionPlan: executionPlan,
        events: events,
        failures: failures,
      );
    });
  }

  @override
  // 调用者：MissionService.findScheduledOn。
  // 输入：计划日期。过程：关联 → 筛选 → 排序 → 执行 → 转换。输出：业务列表。
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate) async {
    return database.transaction(() async {
      // 1. 指定要读取的两张表，并说明它们通过任务编号关联。
      // 这一步构造查询对象，尚未执行 SQL。
      final missions = database.missions;
      final schedules = database.missionScheduleRevisions;
      final query = database.select(missions).join([
        innerJoin(schedules, schedules.missionId.equalsExp(missions.id)),
      ]);

      // 2. 筛选当前排期与所选日期。比如A/1排在周一、A/2改到周二：
      // 先确定最新是A/2，再比较周二，不能因A/1曾排在周一就仍显示在周一。
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
        // 日期已经选好任务；再读取它的执行事实，用同一套规则计算列表阶段。
        final detail = await findDetail(mission.id);
        final item = ScheduledMission(
          mission: mission,
          schedule: schedule,
          phase: detail!.phase,
          events: detail.events,
        );
        result.add(item);
      }

      // 6. 交回查询业务入口，再由它把同一份列表交给今天页。
      return result;
    });
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
    if ((mission.sourceMissionId == null) != (mission.relationType == null) ||
        mission.sourceMissionId == mission.id) {
      throw ArgumentError('再次尝试必须关联另一个来源任务');
    }

    // 把下面的函数交给 Drift，由它在事务中执行。
    // 外层 await 等待整个事务完成。
    // 三次写入全部成功才提交，任意一次失败就一起回滚。
    await database.transaction(() async {
      if (mission.sourceMissionId != null) {
        final source = await findDetail(mission.sourceMissionId!);
        if (source == null ||
            (source.phase != MissionPhase.closed &&
                source.phase != MissionPhase.cancelled)) {
          throw ArgumentError('只能从已结束或已取消任务创建再次尝试');
        }
      }
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
