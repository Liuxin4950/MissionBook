import 'dart:convert';
import '../../domain/entities/mission_ownership.dart';
import 'drift_goal_repository.dart';

import 'package:drift/drift.dart';
import 'package:timezone/data/latest.dart' as tzdata;

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
import '../../domain/entities/evidence.dart';
import '../../domain/rules/evidence_rules.dart';
import 'evidence_mapping.dart';
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
  DriftMissionRepository(this.database, {this.clock = DateTime.now}) {
    tzdata.initializeTimeZones();
  }

  /// 创建与查询共用的数据库连接。
  final AppDatabase database;
  // 只用于捕获实际操作时刻；测试注入可控时钟，不允许命令指定 occurredAt。
  final DateTime Function() clock;

  @override
  Future<List<MissionGoalChoices>> findGoalChoices() =>
      database.transaction(() async {
        final rows =
            await (database.select(database.goals)
                  ..where((table) => table.status.equals('ACTIVE'))
                  ..orderBy([
                    (table) => OrderingTerm.desc(table.createdAt),
                    (table) => OrderingTerm.asc(table.id),
                  ]))
                .get();
        final goals = DriftGoalRepository(database); // 复用已有的目标转换和节点树完整性检查。
        final result = <MissionGoalChoices>[];
        for (final row in rows) {
          result.add(
            MissionGoalChoices(
              goal: (await goals.findById(row.id))!,
              nodes: await goals.findNodes(row.id),
            ),
          );
        }
        return result;
      });

  @override
  Future<MissionOwnershipInfo?> findOwnershipInfo(MissionOwnership ownership) =>
      database.transaction(() async {
        ownership.validate();
        if (ownership.goalId == null) return null; // 独立任务不需要目标或节点也能保存和执行。
        final goals = DriftGoalRepository(database);
        final goal = await goals.findById(ownership.goalId!);
        if (goal == null) throw StateError('关联的目标不存在，请重新选择归属');
        final choices = MissionGoalChoices(
          goal: goal,
          nodes: await goals.findNodes(goal.id),
        );
        return choices.resolve(ownership);
      });

  Future<void> _validateNewOwnership(MissionOwnership ownership) async {
    final info = await findOwnershipInfo(ownership);
    if (info != null && !info.available) {
      throw ArgumentError('目标暂未推进或节点已归档，请重新选择有效归属，或改为独立任务');
    }
  }

  @override
  Future<List<MissionDetail>> findForGoal(String goalId) =>
      database.transaction(() async {
        final rows =
            await (database.select(database.missions)
                  ..where((table) => table.goalId.equals(goalId))
                  ..orderBy([
                    (table) => OrderingTerm.desc(table.createdAt),
                    (table) => OrderingTerm.asc(table.id),
                  ]))
                .get();
        final result = <MissionDetail>[];
        for (final row in rows) {
          result.add((await findDetail(row.id))!); // 复用唯一的阶段、材料和执行时间线查询。
        }
        return result;
      });

  Future<void> _acquireWrite(String missionId) async {
    // 显式在读取事实前执行写语句，字段值不变；同库连接受 SQLite 写锁约束。
    // 当前 Native/Wasm 驱动也使用 BEGIN IMMEDIATE，不能误认为 transaction 默认都为延迟事务。
    await database.customStatement(
      'UPDATE missions SET updated_at = updated_at WHERE id = ?',
      [missionId],
    );
  }

  /// 补算等“作用于全部任务”的入口用空编号的空更新取得全局写锁，
  /// 与任何单任务的提交/执行串行，双方不会各按旧快照同时判定超时。
  Future<void> _acquireGlobalWrite() => _acquireWrite('');

  DateTime _now() => DateTime.fromMillisecondsSinceEpoch(
    clock().toUtc().millisecondsSinceEpoch,
    isUtc: true,
  );

  /// 超时发生时刻和实际落库时刻分开；晚 END 不能制造早于 END 的关闭时间。
  Future<void> _insertEvidenceDeadline(
    MissionDetail detail,
    ExecutionEvent end,
    DateTime now,
  ) async {
    final deadline = detail.schedule.evidenceDeadlineAt!;
    final occurredAt = deadline.isAfter(end.occurredAt)
        ? deadline
        : end.occurredAt;
    await database
        .into(database.failureRecords)
        .insert(
          FailureRecordsCompanion.insert(
            // 编号由 END 事件派生，同一次 END 的超时事实永远只有一个编号。
            id: evidenceDeadlineFailureId(end.id),
            missionId: detail.mission.id,
            trigger: evidenceDeadlineMissedTrigger,
            occurredAt: occurredAt.millisecondsSinceEpoch,
            createdAt: now.millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<EvidenceSubmissionResult> submitEvidence(
    EvidenceSubmission submission,
  ) async {
    if (submission.id.trim().isEmpty ||
        submission.missionId.trim().isEmpty ||
        submission.items.isEmpty) {
      throw ArgumentError('请至少添加一份有效材料');
    }
    final ids = <String>{};
    for (final item in submission.items) {
      validateEvidenceDraft(item, submission.missionId);
      if (item.supersedesEvidenceId != null) {
        throw ArgumentError('首次提交不能替代已有材料');
      }
      if (!ids.add(item.id)) throw ArgumentError('同批材料编号不能重复');
    }
    return database.transaction(() async {
      await _acquireWrite(submission.missionId);
      final rows = await (database.select(
        database.evidenceRecords,
      )..where((table) => table.submissionId.equals(submission.id))).get();
      // 先认出已经成功的原批次，之后才检查 CLOSED/截止；成功重试不得被新状态误拒绝。
      if (rows.isNotEmpty) {
        final saved = rows.map(evidenceFromRow).toList();
        final byId = {for (final item in saved) item.id: item};
        if (saved.length != submission.items.length ||
            saved.any((item) => item.missionId != submission.missionId) ||
            submission.items.any(
              (item) =>
                  byId[item.id] == null ||
                  !sameEvidenceInput(byId[item.id]!, item),
            )) {
          throw const EvidenceConflict('同一提交编号的材料内容不同，请重新读取记录');
        }
        // 也核对原批次关联事实，损坏历史不能被重试伪装为正常成功。
        await findDetail(submission.missionId);
        return EvidenceSubmissionResult.submitted;
      }
      final detail = await findDetail(submission.missionId);
      if (detail == null) throw const EvidenceConflict('任务不存在，请刷新');
      if (detail.failures.any(
        (item) => item.trigger == evidenceDeadlineMissedTrigger,
      )) {
        return EvidenceSubmissionResult.deadlineMissed;
      }
      if (detail.phase != MissionPhase.evidencePending) {
        throw const EvidenceConflict('任务已不再待补材料，请重新读取记录');
      }
      final now = _now();
      final end = detail.events.last;
      if (now.isBefore(end.occurredAt)) {
        throw const EvidenceConflict('系统时间早于结束记录，请校正后重试');
      }
      if (detail.mission.verificationPolicy ==
              VerificationPolicy.requiredEvidence &&
          !now.isBefore(detail.schedule.evidenceDeadlineAt!)) {
        await _insertEvidenceDeadline(detail, end, now);
        // 正常返回让 transaction 提交超时事实，不把它与拒绝提交一起回滚。
        return EvidenceSubmissionResult.deadlineMissed;
      }
      for (final draft in submission.items) {
        final item = Evidence(
          id: draft.id,
          missionId: submission.missionId,
          submissionId: submission.id,
          submittedAt: now,
          type: draft.type,
          source: draft.source,
          content: draft.content,
          attachmentStorageKey: draft.attachmentStorageKey,
          attachmentFileName: draft.attachmentFileName,
          attachmentMimeType: draft.attachmentMimeType,
          capturedAt: draft.capturedAt,
          supersedesEvidenceId: null,
        );
        await database
            .into(database.evidenceRecords)
            .insert(evidenceToCompanion(item));
      }
      return EvidenceSubmissionResult.submitted;
    });
  }

  @override
  Future<Evidence> correctEvidence(EvidenceCorrection correction) async {
    final draft = correction.item;
    if (correction.missionId.trim().isEmpty ||
        draft.supersedesEvidenceId == null ||
        draft.supersedesEvidenceId!.trim().isEmpty) {
      throw ArgumentError('请选择一份当前有效的正式材料');
    }
    validateEvidenceDraft(draft, correction.missionId);
    return database.transaction(() async {
      await _acquireWrite(correction.missionId);
      final existing = await (database.select(
        database.evidenceRecords,
      )..where((table) => table.id.equals(draft.id))).getSingleOrNull();
      if (existing != null) {
        final saved = evidenceFromRow(existing);
        if (saved.missionId != correction.missionId ||
            saved.submissionId != draft.id ||
            !sameEvidenceInput(saved, draft)) {
          throw const EvidenceConflict('修正编号已用于不同内容，请重新读取记录');
        }
        await findDetail(correction.missionId);
        return saved;
      }
      final detail = await findDetail(correction.missionId);
      if (detail == null || detail.phase != MissionPhase.closed) {
        throw const EvidenceConflict('任务没有可修正的正式材料，请刷新');
      }
      final original = detail.effectiveEvidence.where(
        (item) => item.id == draft.supersedesEvidenceId,
      );
      if (original.length != 1 || original.single.type != draft.type) {
        throw const EvidenceConflict('原材料已被修正或类型不同，请读取最新记录');
      }
      final now = _now();
      if (now.isBefore(original.single.submittedAt)) {
        throw const EvidenceConflict('系统时间早于原材料，请校正后重试');
      }
      final saved = Evidence(
        id: draft.id,
        missionId: correction.missionId,
        submissionId: draft.id,
        submittedAt: now,
        type: draft.type,
        source: draft.source,
        content: draft.content,
        attachmentStorageKey: draft.attachmentStorageKey,
        attachmentFileName: draft.attachmentFileName,
        attachmentMimeType: draft.attachmentMimeType,
        capturedAt: draft.capturedAt,
        supersedesEvidenceId: draft.supersedesEvidenceId,
      );
      await database
          .into(database.evidenceRecords)
          .insert(evidenceToCompanion(saved));
      return saved;
    });
  }

  @override
  Future<void> skipOptionalEvidence(String missionId) => database.transaction(
    () async {
      await _acquireWrite(missionId);
      final detail = await findDetail(missionId);
      if (detail == null) throw const EvidenceConflict('任务不存在，请刷新');
      if (detail.mission.evidenceWaivedAt != null) return; // 成功后响应丢失，保留第一次放弃时刻。
      if (detail.mission.verificationPolicy !=
              VerificationPolicy.optionalEvidence ||
          detail.phase != MissionPhase.evidencePending) {
        throw const EvidenceConflict('只有待补的可选材料可以放弃提交');
      }
      final now = _now();
      if (now.isBefore(detail.events.last.occurredAt)) {
        throw const EvidenceConflict('系统时间早于结束记录，请校正后重试');
      }
      await (database.update(
        database.missions,
      )..where((table) => table.id.equals(missionId))).write(
        MissionsCompanion(
          evidenceWaivedAt: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ),
      );
    },
  );

  @override
  Future<int> reconcileEvidenceDeadlines() => database.transaction(() async {
    // 整次补算先取得全局写权限，提交材料和超时不会同时依据旧快照成功。
    await _acquireGlobalWrite();
    final now = _now();
    // 先筛已报告完成、未提交/关闭且绑定排期已到期的强制材料任务，
    // 排除历史终态与旧排期，避免每次查询都逐一重建已关闭任务的详情。
    final candidates = await _findDeadlineCandidateIds(now);
    var count = 0;
    for (final id in candidates) {
      final detail = (await findDetail(id))!;
      // 真实阶段仍由唯一推演核心判定：只有“待补材料且已过截止”才写超时事实。
      if (detail.phase == MissionPhase.evidencePending &&
          !now.isBefore(detail.schedule.evidenceDeadlineAt!)) {
        await _insertEvidenceDeadline(detail, detail.events.last, now);
        count++;
      }
    }
    return count;
  });

  /// 只筛可能需要补算的事实组合，最终阶段和写入仍在原事务内按领域规则复查。
  Future<List<String>> _findDeadlineCandidateIds(DateTime now) async {
    final rows = await database
        .customSelect(
          'SELECT m.id AS mission_id FROM execution_events e '
          'JOIN missions m ON m.id = e.mission_id '
          "JOIN execution_events s ON s.mission_id = m.id AND s.type = 'START' "
          'JOIN mission_schedule_revisions r ON r.id = s.schedule_revision_id '
          'WHERE m.verification_policy = ? '
          'AND m.cancelled_at IS NULL '
          'AND m.evidence_waived_at IS NULL '
          "AND e.type = 'END' AND e.user_reported_result = 'COMPLETED' "
          'AND r.evidence_deadline_at IS NOT NULL '
          'AND r.evidence_deadline_at <= ? '
          'AND NOT EXISTS (SELECT 1 FROM evidence_records v WHERE v.mission_id = m.id) '
          'AND NOT EXISTS (SELECT 1 FROM failure_records f WHERE f.mission_id = m.id)',
          variables: [
            // 筛选条件与任务表保存的策略文本一致（见 missionToCompanion）。
            Variable.withString('REQUIRED_EVIDENCE'),
            Variable.withInt(now.millisecondsSinceEpoch),
          ],
          readsFrom: {
            database.missions,
            database.missionScheduleRevisions,
            database.executionEvents,
            database.evidenceRecords,
            database.failureRecords,
          },
        )
        .get();
    return [for (final row in rows) row.read<String>('mission_id')];
  }

  @override
  Future<List<MissionDetail>> findPendingEvidence() async =>
      (await findFinished())
          .where((detail) => detail.phase == MissionPhase.evidencePending)
          .toList();

  @override
  Future<Set<String>> referencedAttachmentKeys() async {
    final rows = await (database.select(
      database.evidenceRecords,
    )..where((table) => table.attachmentStorageKey.isNotNull())).get();
    return {for (final row in rows) row.attachmentStorageKey!};
  }

  @override
  Future<List<String>> startDueScheduledMissions() => database.transaction(
    () async {
      // 与手动执行、改期和取消共用全局 SQLite 写锁；不能先读后抢锁。
      await _acquireGlobalWrite();
      final now = _now();
      final details = await findAllDetails();
      final due = details.where((detail) {
        final start = detail.schedule.fixedStartAt;
        return detail.phase == MissionPhase.notStarted &&
            start != null &&
            !start.isAfter(now) &&
            start
                .add(Duration(minutes: detail.schedule.plannedDurationMinutes))
                .isAfter(now);
      }).toList();
      due.sort((a, b) {
        final order = a.schedule.fixedStartAt!.compareTo(
          b.schedule.fixedStartAt!,
        );
        return order == 0 ? a.mission.id.compareTo(b.mission.id) : order;
      });
      if (due.isEmpty) return <String>[];
      // 多项同时到点时稳定选择第一项；已有 RUNNING 则保留当前任务。
      final changed = <String>[];
      for (final detail in due) {
        final running = (await findActive()).where(
          (item) => item.phase == MissionPhase.running,
        );
        if (running.isNotEmpty) break;
        // 查询耗时可能跨过结束边界；同一次写事务内捕获时刻并用于后续 START，
        // 避免用过期筛选结果开始任务，或在校验后换用另一个发生时刻。
        final startedAt = _now();
        final end = detail.schedule.fixedStartAt!.add(
          Duration(minutes: detail.schedule.plannedDurationMinutes),
        );
        if (startedAt.isBefore(detail.schedule.fixedStartAt!) ||
            !startedAt.isBefore(end)) {
          continue;
        }
        await _execute(
          ExecutionCommand(
            id: 'scheduled-start-${detail.schedule.id}',
            missionId: detail.mission.id,
            expectedSequence: 0,
            type: ExecutionEventType.start,
            scheduleRevisionId: detail.schedule.id,
          ),
          occurredAt: startedAt,
        );
        changed.add(detail.mission.id);
      }
      return changed;
    },
  );

  @override
  Future<ExecutionEvent> execute(ExecutionCommand command) => _execute(command);

  // 自动开始已持有外层事务写锁，可复用其边界校验时刻；普通操作仍在下方捕获。
  Future<ExecutionEvent> _execute(
    ExecutionCommand command, {
    DateTime? occurredAt,
  }) async {
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
                      table.trigger.equals(userMarkedNotCompletedTrigger),
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
            event.submitOptionalEvidence != command.submitOptionalEvidence ||
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
      final now = occurredAt ?? _now();
      if (command.type == ExecutionEventType.start &&
          detail.schedule.fixedStartAt != null &&
          now.isBefore(detail.schedule.fixedStartAt!)) {
        throw const ExecutionConflict('计划任务尚未到开始时间，可以先修改排期');
      }
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
        submitOptionalEvidence: command.submitOptionalEvidence,
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
                id: userMarkedFailureId(event.id),
                missionId: event.missionId,
                trigger: userMarkedNotCompletedTrigger,
                occurredAt: now.millisecondsSinceEpoch,
                createdAt: now.millisecondsSinceEpoch,
                userReasonCategory: Value(category),
                userReasonText: Value(reasonText),
              ),
            );
      }
      // 晚于截止才报告完成：END 和超时一起提交，保留用户的完成报告。
      if (event.type == ExecutionEventType.end &&
          event.userReportedResult == UserReportedResult.completed &&
          detail.mission.verificationPolicy ==
              VerificationPolicy.requiredEvidence &&
          !now.isBefore(detail.schedule.evidenceDeadlineAt!)) {
        await _insertEvidenceDeadline(detail, event, now);
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

  @override
  Future<List<MissionDetail>> findAllDetails() =>
      database.transaction(() async {
        final rows =
            await (database.select(database.missions)..orderBy([
                  (row) => OrderingTerm.desc(row.createdAt),
                  (row) => OrderingTerm.asc(row.id),
                ]))
                .get();
        final result = <MissionDetail>[];
        for (final row in rows) {
          final detail = await findDetail(row.id); // 每项仍经唯一事实组合与阶段校验。
          if (detail == null) throw const FormatException('任务列表中存在无法读取的任务');
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
    VerificationPolicy? verificationPolicy,
    String? verificationCriteria,
    MissionOwnership? ownership,
    String? description,
    String? why,
    bool updateContext = false,
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
      if (current.events.isNotEmpty) {
        throw const MissionEditConflict('任务已经开始，不能再修改任务与排期');
      }
      final scheduleChanged = !_sameSchedule(current.schedule, schedule);
      final titleChanged = current.mission.title != title;
      final objectiveChanged = current.executionPlan.objective != objective;
      final newPolicy =
          verificationPolicy ?? original.mission.verificationPolicy;
      final newCriteria = verificationPolicy == null
          ? original.executionPlan.verificationCriteria
          : verificationCriteria;
      // 材料配置规则只有一份（domain/rules/evidence_rules.dart），事务内复查同一口径。
      validateEvidenceRequirement(
        policy: newPolicy,
        criteria: newCriteria,
        schedule: schedule,
      );
      final policyChanged = newPolicy != current.mission.verificationPolicy;
      final criteriaChanged =
          newCriteria != current.executionPlan.verificationCriteria;
      final newOwnership = ownership ?? original.mission.ownership;
      newOwnership.validate();
      final ownershipChanged = newOwnership != current.mission.ownership;
      final newDescription = updateContext
          ? description
          : original.mission.description;
      final newWhy = updateContext ? why : original.mission.why;
      final contextChanged =
          newDescription != current.mission.description ||
          newWhy != current.mission.why;
      // 无改动、双击或重试同一份已成功的内容都不制造新版本或修改时间。
      if (!scheduleChanged &&
          !titleChanged &&
          !objectiveChanged &&
          !policyChanged &&
          !criteriaChanged &&
          !ownershipChanged &&
          !contextChanged) {
        return;
      }

      final oldMission = original.mission;
      final oldPlan = original.executionPlan;
      if (current.schedule.id != original.schedule.id ||
          current.mission.updatedAt != oldMission.updatedAt ||
          current.mission.title != oldMission.title ||
          current.executionPlan.id != oldPlan.id ||
          current.executionPlan.updatedAt != oldPlan.updatedAt ||
          current.executionPlan.objective != oldPlan.objective ||
          current.mission.verificationPolicy != oldMission.verificationPolicy ||
          current.mission.ownership != oldMission.ownership ||
          current.mission.description != oldMission.description ||
          current.mission.why != oldMission.why ||
          current.executionPlan.verificationCriteria !=
              oldPlan.verificationCriteria) {
        throw const MissionEditConflict('任务已被修改，输入已保留；请返回详情刷新后重新编辑');
      }
      if (scheduleChanged &&
          (schedule.revisionNumber != current.schedule.revisionNumber + 1 ||
              schedule.timeZone != current.schedule.timeZone ||
              schedule.plannedDurationMinutes <= 0 ||
              (schedule.timePolicy == TimePolicy.fixed) !=
                  (schedule.fixedStartAt != null))) {
        throw ArgumentError('排期提案与当前任务不一致');
      }
      final now = schedule.changedAt.millisecondsSinceEpoch;
      // 只在改归属时要求新目标/节点有效；原节点归档后仍允许保留原归属编辑标题。
      if (ownershipChanged) await _validateNewOwnership(newOwnership);
      if (scheduleChanged &&
          newPolicy == VerificationPolicy.requiredEvidence &&
          !schedule.evidenceDeadlineAt!.isAfter(_now())) {
        throw ArgumentError('新的材料截止时间必须晚于当前时刻');
      }
      // 只写本次开放的名称与材料策略；说明、Why 和身份不被表单旧值覆盖。
      final missionUpdate = database.update(database.missions);
      missionUpdate.where((table) => table.id.equals(missionId));
      await missionUpdate.write(
        MissionsCompanion(
          title: Value(title),
          goalId: Value(newOwnership.goalId),
          goalNodeId: Value(newOwnership.goalNodeId),
          description: Value(newDescription),
          why: Value(newWhy),
          updatedAt: Value(now),
          verificationPolicy: Value(switch (newPolicy) {
            VerificationPolicy.selfReport => 'SELF_REPORT',
            VerificationPolicy.optionalEvidence => 'OPTIONAL_EVIDENCE',
            VerificationPolicy.requiredEvidence => 'REQUIRED_EVIDENCE',
          }),
        ),
      );
      if (objectiveChanged || criteriaChanged) {
        final planUpdate = database.update(database.executionPlans);
        planUpdate.where((table) => table.id.equals(current.executionPlan.id));
        await planUpdate.write(
          ExecutionPlansCompanion(
            objective: Value(objective),
            verificationCriteria: Value(newCriteria),
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
      final now = _now().millisecondsSinceEpoch;
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
      final evidenceRows =
          await (database.select(database.evidenceRecords)
                ..where((table) => table.missionId.equals(missionId))
                ..orderBy([
                  (table) => OrderingTerm.asc(table.submittedAt),
                  (table) => OrderingTerm.asc(table.id),
                ]))
              .get();
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
      final evidence = List<Evidence>.unmodifiable(
        evidenceRows.map(evidenceFromRow),
      );
      // 读取时同步复查材料配置口径；数据被外部损坏时明确报错，不默默显示。
      validateEvidenceRequirement(
        policy: mission.verificationPolicy,
        criteria: executionPlan.verificationCriteria,
        schedule: schedule,
      );
      deriveMissionPhase(mission, events, failures, evidence, schedule);
      // ⑤ 打包成一次查询结果，不新增一张详情表，也不向数据库写入阶段。
      return MissionDetail(
        mission: mission,
        schedule: schedule,
        executionPlan: executionPlan,
        events: events,
        failures: failures,
        evidence: evidence,
        ownershipInfo: await findOwnershipInfo(mission.ownership),
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
    if (mission.cancelledAt != null || mission.evidenceWaivedAt != null) {
      throw ArgumentError('新任务不能已经取消');
    }
    // 材料配置（含截止下限）在保存前按 domain 规则校验一次。
    validateEvidenceRequirement(
      policy: mission.verificationPolicy,
      criteria: executionPlan.verificationCriteria,
      schedule: initialSchedule,
    );
    if ((mission.sourceMissionId == null) != (mission.relationType == null) ||
        mission.sourceMissionId == mission.id) {
      throw ArgumentError('再次尝试必须关联另一个来源任务');
    }

    // 把下面的函数交给 Drift，由它在事务中执行。
    // 外层 await 等待整个事务完成。
    // 三次写入全部成功才提交，任意一次失败就一起回滚。
    await database.transaction(() async {
      await _acquireWrite(mission.id); // 先取得写锁，再核对归属和任务身份，防止与归档并发穿透。
      final existing = await (database.select(
        database.missions,
      )..where((table) => table.id.equals(mission.id))).getSingleOrNull();
      if (existing != null) {
        final saved = (await findDetail(mission.id))!;
        // 先识别原请求是否已提交，之后才判断目标归档和截止变化；成功重试不再创建。
        if (!_sameCreation(saved, mission, initialSchedule, executionPlan)) {
          throw StateError('这个创建请求已保存为其他内容，请先检查任务记录');
        }
        return;
      }
      await _validateNewOwnership(mission.ownership);
      // 创建强制任务也在事务中重查实际时刻，避免编辑期间截止已经过去。
      if (mission.verificationPolicy == VerificationPolicy.requiredEvidence &&
          !initialSchedule.evidenceDeadlineAt!.isAfter(_now())) {
        throw ArgumentError('材料截止时间必须晚于当前时刻');
      }
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

  bool _sameCreation(
    MissionDetail saved,
    Mission mission,
    MissionScheduleRevision schedule,
    ExecutionPlan plan,
  ) {
    bool sameTime(DateTime a, DateTime b) =>
        a.millisecondsSinceEpoch == b.millisecondsSinceEpoch;
    final old = saved.mission;
    final oldPlan = saved.executionPlan;
    return old.title == mission.title &&
        old.description == mission.description &&
        old.why == mission.why &&
        old.ownership == mission.ownership &&
        old.sourceMissionId == mission.sourceMissionId &&
        old.relationType == mission.relationType &&
        old.verificationPolicy == mission.verificationPolicy &&
        sameTime(old.createdAt, mission.createdAt) &&
        sameTime(old.updatedAt, mission.updatedAt) &&
        old.cancelledAt == mission.cancelledAt &&
        old.evidenceWaivedAt == mission.evidenceWaivedAt &&
        saved.schedule.id == schedule.id &&
        saved.schedule.revisionNumber == schedule.revisionNumber &&
        _sameSchedule(saved.schedule, schedule) &&
        sameTime(saved.schedule.changedAt, schedule.changedAt) &&
        saved.schedule.changeReason == schedule.changeReason &&
        oldPlan.id == plan.id &&
        oldPlan.objective == plan.objective &&
        jsonEncode(oldPlan.steps) == jsonEncode(plan.steps) &&
        oldPlan.verificationCriteria == plan.verificationCriteria &&
        oldPlan.notes == plan.notes &&
        sameTime(oldPlan.createdAt, plan.createdAt) &&
        sameTime(oldPlan.updatedAt, plan.updatedAt);
  }
}
