part of 'drift_mission_repository.dart';

/// 同一连接与事务中的任务持久化职责。
class _MissionCommands {
  _MissionCommands(this._repository);
  final DriftMissionRepository _repository;
  Future<void> _validateNewOwnership(MissionOwnership ownership) async {
    final info = await _repository.findOwnershipInfo(ownership);
    if (info != null && !info.available) {
      throw ArgumentError('目标暂未推进或节点已归档，请重新选择有效归属，或改为独立任务');
    }
  }

  Future<void> edit({
    required MissionDetail original,
    required String title,
    required String objective,
    required MissionScheduleRevision schedule,
    ExecutionPlanContent? content,
    VerificationPolicy? verificationPolicy,
    String? verificationCriteria,
    MissionOwnership? ownership,
    String? description,
    String? why,
    bool updateContext = false,
    String? operationId,
  }) async {
    final missionId = original.mission.id;
    validateMissionSchedule(schedule);
    if (missionId.trim().isEmpty ||
        title.trim().isEmpty ||
        objective.trim().isEmpty ||
        schedule.missionId != missionId) {
      throw ArgumentError('任务编号、名称、具体目标或排期关联无效');
    }
    final fingerprint = operationId == null
        ? null
        : _editFingerprint(
            original: original,
            title: title,
            objective: objective,
            schedule: schedule,
            content: content,
            verificationPolicy: verificationPolicy,
            verificationCriteria: verificationCriteria,
            ownership: ownership,
            description: description,
            why: why,
            updateContext: updateContext,
          );
    await _repository.database.transaction(() async {
      await _repository._acquireWrite(missionId);
      if (operationId != null) {
        final receipt = await _repository.findOperationReceipt(operationId);
        if (receipt != null) {
          if (receipt.kind != 'mission_edit' ||
              receipt.entityId != missionId ||
              receipt.fingerprint != fingerprint) {
            throw StateError('同一编辑身份已用于其他内容，请重新核对任务');
          }
          return;
        }
      }
      // 重读的是事务内最新快照，不能依靠编辑页打开时的状态放行。
      final current = await _repository.findDetail(missionId);
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
      final newSteps = content?.steps ?? original.executionPlan.steps;
      final newNotes = content == null
          ? original.executionPlan.notes
          : content.notes;
      validateExecutionPlanContent(newSteps, newNotes);
      final contentChanged =
          jsonEncode(newSteps) != jsonEncode(current.executionPlan.steps) ||
          newNotes != current.executionPlan.notes;
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
          !contentChanged &&
          !policyChanged &&
          !criteriaChanged &&
          !ownershipChanged &&
          !contextChanged) {
        await _repository._writeOperationReceipt(
          operationId: operationId,
          missionId: missionId,
          fingerprint: fingerprint,
        );
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
          jsonEncode(current.executionPlan.steps) !=
              jsonEncode(oldPlan.steps) ||
          current.executionPlan.notes != oldPlan.notes ||
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
          !schedule.evidenceDeadlineAt!.isAfter(_repository._now())) {
        throw ArgumentError('新的材料截止时间必须晚于当前时刻');
      }
      // 只写本次开放的名称与材料策略；说明、Why 和身份不被表单旧值覆盖。
      final missionUpdate = _repository.database.update(
        _repository.database.missions,
      );
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
      if (objectiveChanged || criteriaChanged || contentChanged) {
        final planUpdate = _repository.database.update(
          _repository.database.executionPlans,
        );
        planUpdate.where((table) => table.id.equals(current.executionPlan.id));
        await planUpdate.write(
          ExecutionPlansCompanion(
            objective: Value(objective),
            steps: Value(jsonEncode(newSteps)),
            notes: Value(newNotes),
            verificationCriteria: Value(newCriteria),
            updatedAt: Value(now),
          ),
        );
      }
      if (scheduleChanged) {
        // insert 追加完整快照，绝不 update 旧排期；任一步失败会回滚上面的修改。
        await _repository.database
            .into(_repository.database.missionScheduleRevisions)
            .insert(scheduleToCompanion(schedule));
      }
      await _repository._writeOperationReceipt(
        operationId: operationId,
        missionId: missionId,
        fingerprint: fingerprint,
      );
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
  Future<void> cancel(String missionId, {String? operationId}) async {
    if (missionId.trim().isEmpty) {
      throw ArgumentError('任务编号不能为空');
    }
    // 页面展示的是旧快照；在同一写事务内重读，再决定是否修改。
    await _repository.database.transaction(() async {
      await _repository._acquireWrite(missionId);
      final fingerprint = sha256
          .convert(utf8.encode('mission_cancel:$missionId'))
          .toString();
      if (operationId != null) {
        final receipt = await _repository.findOperationReceipt(operationId);
        if (receipt != null) {
          if (receipt.kind != 'mission_cancel' ||
              receipt.entityId != missionId ||
              receipt.fingerprint != fingerprint) {
            throw StateError('操作编号已用于其他请求');
          }
          return;
        }
      }
      Future<void> recordReceipt() => _repository._writeOperationReceipt(
        operationId: operationId,
        missionId: missionId,
        fingerprint: fingerprint,
        kind: 'mission_cancel',
      );
      final missions = _repository.database.missions;
      final query = _repository.database.select(missions);
      query.where((table) => table.id.equals(missionId));
      final row = await query.getSingleOrNull();
      if (row == null) {
        throw StateError('任务不存在，无法取消');
      }
      // 重复请求不覆盖第一次取消的时间，也不更新 updatedAt。
      if (row.cancelledAt != null) {
        await recordReceipt();
        return;
      }
      final events =
          await (_repository.database.select(
                  _repository.database.executionEvents,
                )
                ..where((table) => table.missionId.equals(missionId))
                ..limit(1))
              .get();
      if (events.isNotEmpty) {
        throw const ExecutionConflict('任务已经开始，请通过结束报告选择未完成');
      }
      final now = _repository._now().millisecondsSinceEpoch;
      final update = _repository.database.update(missions);
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
      await recordReceipt();
    });
  }

  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  }) async {
    validateMissionCreation(
      MissionCreation(
        mission: mission,
        schedule: initialSchedule,
        plan: executionPlan,
      ),
    );
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
    await _repository.database.transaction(() async {
      await _repository._acquireWrite(
        mission.id,
      ); // 先取得写锁，再核对归属和任务身份，防止与归档并发穿透。
      final existing = await (_repository.database.select(
        _repository.database.missions,
      )..where((table) => table.id.equals(mission.id))).getSingleOrNull();
      if (existing != null) {
        final saved = (await _repository.findDetail(mission.id))!;
        // 先识别原请求是否已提交，之后才判断目标归档和截止变化；成功重试不再创建。
        if (!_sameCreation(saved, mission, initialSchedule, executionPlan)) {
          throw StateError('这个创建请求已保存为其他内容，请先检查任务记录');
        }
        return;
      }
      await _validateNewOwnership(mission.ownership);
      // 创建强制任务也在事务中重查实际时刻，避免编辑期间截止已经过去。
      if (mission.verificationPolicy == VerificationPolicy.requiredEvidence &&
          !initialSchedule.evidenceDeadlineAt!.isAfter(_repository._now())) {
        throw ArgumentError('材料截止时间必须晚于当前时刻');
      }
      if (mission.sourceMissionId != null) {
        final source = await _repository.findDetail(mission.sourceMissionId!);
        if (source == null ||
            (source.phase != MissionPhase.closed &&
                source.phase != MissionPhase.cancelled)) {
          throw ArgumentError('只能从已结束或已取消任务创建再次尝试');
        }
      }
      // into 指定写入任务表。
      // 转换函数返回 Companion 对象，insert 接收它并执行写入。
      // await 等待任务保存完成，再继续保存引用它的排期。
      await _repository.database
          .into(_repository.database.missions)
          .insert(missionToCompanion(mission));
      // 保存同一任务的第一条排期。
      await _repository.database
          .into(_repository.database.missionScheduleRevisions)
          .insert(scheduleToCompanion(initialSchedule));
      // 保存同一任务的执行方案。
      await _repository.database
          .into(_repository.database.executionPlans)
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
