part of 'drift_mission_repository.dart';

/// 同一连接与事务中的任务持久化职责。
class _MissionEvidence {
  _MissionEvidence(this._repository);
  final DriftMissionRepository _repository;

  /// 已有记录和页面草稿共用提交、截止判定、身份校验及完整阶段复查。
  Future<EvidenceSubmissionResult> attachRecordEvidence(
    String recordId,
    String missionId,
  ) => _repository.database.transaction(() async {
    await _repository._acquireWrite(missionId);
    final row = await (_repository.database.select(
      _repository.database.records,
    )..where((table) => table.id.equals(recordId))).getSingleOrNull();
    if (row == null) throw const EvidenceConflict('记录不存在，请刷新');
    final id = 'record:$recordId';
    return _submitEvidence(
      EvidenceSubmission(
        id: id,
        missionId: missionId,
        items: [evidenceDraftFromRecord(row, id: id)],
      ),
      existingRecordId: recordId,
    );
  });

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
    await _repository.database
        .into(_repository.database.failureRecords)
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

  Future<EvidenceSubmissionResult> submitEvidence(
    EvidenceSubmission submission,
  ) => _submitEvidence(submission);

  Future<EvidenceSubmissionResult> _submitEvidence(
    EvidenceSubmission submission, {
    String? existingRecordId,
  }) async {
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
    return _repository.database.transaction(() async {
      await _repository._acquireWrite(submission.missionId);
      final rows = await (_repository.database.select(
        _repository.database.evidenceRecords,
      )..where((table) => table.submissionId.equals(submission.id))).get();
      // 先认出已经成功的原批次，之后才检查 CLOSED/截止；成功重试不得被新状态误拒绝。
      if (rows.isNotEmpty) {
        final saved = (await hydrateEvidenceRows(
          _repository.database,
          rows,
        )).map(evidenceFromRow).toList();
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
        final detail = await _repository.findDetail(submission.missionId);
        return _submissionResult(detail!);
      }
      final detail = await _repository.findDetail(submission.missionId);
      if (detail == null) throw const EvidenceConflict('任务不存在，请刷新');
      final now = _repository._now();
      // 超时仍保存补充材料，原失败事实保留；提交时刻不使用拍摄时刻。
      if (detail.phase == MissionPhase.evidencePending &&
          detail.mission.verificationPolicy ==
              VerificationPolicy.requiredEvidence &&
          !now.isBefore(detail.schedule.evidenceDeadlineAt!)) {
        await _insertEvidenceDeadline(detail, detail.events.last, now);
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
        await insertEvidence(
          _repository.database,
          item,
          existingRecordId: existingRecordId,
        );
      }
      final saved = (await _repository.findDetail(submission.missionId))!;
      return _submissionResult(saved);
    });
  }

  EvidenceSubmissionResult _submissionResult(MissionDetail detail) =>
      detail.failures.any(
        (failure) => failure.trigger == evidenceDeadlineMissedTrigger,
      )
      ? EvidenceSubmissionResult.deadlineMissed
      : EvidenceSubmissionResult.submitted;

  Future<Evidence> correctEvidence(EvidenceCorrection correction) async {
    final draft = correction.item;
    if (correction.missionId.trim().isEmpty ||
        draft.supersedesEvidenceId == null ||
        draft.supersedesEvidenceId!.trim().isEmpty) {
      throw ArgumentError('请选择一份当前有效的正式材料');
    }
    validateEvidenceDraft(draft, correction.missionId);
    return _repository.database.transaction(() async {
      await _repository._acquireWrite(correction.missionId);
      final existing = await (_repository.database.select(
        _repository.database.evidenceRecords,
      )..where((table) => table.id.equals(draft.id))).getSingleOrNull();
      if (existing != null) {
        final saved = evidenceFromRow(
          (await hydrateEvidenceRows(_repository.database, [existing])).single,
        );
        if (saved.missionId != correction.missionId ||
            saved.submissionId != draft.id ||
            !sameEvidenceInput(saved, draft)) {
          throw const EvidenceConflict('修正编号已用于不同内容，请重新读取记录');
        }
        await _repository.findDetail(correction.missionId);
        return saved;
      }
      final detail = await _repository.findDetail(correction.missionId);
      if (detail == null) {
        throw const EvidenceConflict('任务没有可修正的正式材料，请刷新');
      }
      final original = detail.effectiveEvidence.where(
        (item) => item.id == draft.supersedesEvidenceId,
      );
      if (original.length != 1 || original.single.type != draft.type) {
        throw const EvidenceConflict('原材料已被修正或类型不同，请读取最新记录');
      }
      final now = _repository._now();
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
      await insertEvidence(_repository.database, saved);
      return saved;
    });
  }

  Future<void> skipOptionalEvidence(String missionId) =>
      _repository.database.transaction(() async {
        await _repository._acquireWrite(missionId);
        final detail = await _repository.findDetail(missionId);
        if (detail == null) throw const EvidenceConflict('任务不存在，请刷新');
        if (detail.mission.evidenceWaivedAt != null) {
          return; // 成功后响应丢失，保留第一次放弃时刻。
        }
        if (detail.mission.verificationPolicy !=
                VerificationPolicy.optionalEvidence ||
            detail.phase != MissionPhase.evidencePending) {
          throw const EvidenceConflict('只有待补的可选材料可以放弃提交');
        }
        final now = _repository._now();
        if (now.isBefore(detail.events.last.occurredAt)) {
          throw const EvidenceConflict('系统时间早于结束记录，请校正后重试');
        }
        await (_repository.database.update(
          _repository.database.missions,
        )..where((table) => table.id.equals(missionId))).write(
          MissionsCompanion(
            evidenceWaivedAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
      });
  Future<int> reconcileEvidenceDeadlines() =>
      _repository.database.transaction(() async {
        // 整次补算先取得全局写权限，提交材料和超时不会同时依据旧快照成功。
        await _repository._acquireGlobalWrite();
        final now = _repository._now();
        // 先筛已报告完成、未提交/关闭且绑定排期已到期的强制材料任务，
        // 排除历史终态与旧排期，避免每次查询都逐一重建已关闭任务的详情。
        final candidates = await _findDeadlineCandidateIds(now);
        var count = 0;
        for (final id in candidates) {
          final detail = (await _repository.findDetail(id))!;
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
    final rows = await _repository.database
        .customSelect(
          'SELECT m.id AS mission_id FROM execution_events e '
          'JOIN missions m ON m.id = e.mission_id '
          "JOIN execution_events s ON s.mission_id = m.id AND (s.type = 'START' OR s.is_retrospective = 1) "
          'JOIN mission_schedule_revisions r ON r.id = s.schedule_revision_id '
          'WHERE m.verification_policy = ? '
          'AND m.cancelled_at IS NULL '
          'AND m.evidence_waived_at IS NULL '
          "AND e.type = 'END' AND e.user_reported_result = 'COMPLETED' "
          'AND r.evidence_deadline_at IS NOT NULL '
          'AND r.evidence_deadline_at <= ? '
          'AND NOT EXISTS (SELECT 1 FROM evidence_records v WHERE v.mission_id = m.id '
          'AND v.supersedes_evidence_id IS NULL AND v.submitted_at < r.evidence_deadline_at) '
          'AND NOT EXISTS (SELECT 1 FROM failure_records f WHERE f.mission_id = m.id)',
          variables: [
            // 筛选条件与任务表保存的策略文本一致（见 missionToCompanion）。
            Variable.withString('REQUIRED_EVIDENCE'),
            Variable.withInt(now.millisecondsSinceEpoch),
          ],
          readsFrom: {
            _repository.database.missions,
            _repository.database.missionScheduleRevisions,
            _repository.database.executionEvents,
            _repository.database.evidenceRecords,
            _repository.database.failureRecords,
          },
        )
        .get();
    return [for (final row in rows) row.read<String>('mission_id')];
  }

  Future<List<MissionDetail>> findPendingEvidence() async =>
      (await _repository.findFinished())
          .where((detail) => detail.phase == MissionPhase.evidencePending)
          .toList();
  Future<Set<String>> referencedAttachmentKeys() async {
    final rows = await _repository.database
        .customSelect(
          'SELECT attachment_storage_key AS k FROM records WHERE attachment_storage_key IS NOT NULL '
          'UNION SELECT attachment_storage_key FROM evidence_records WHERE attachment_storage_key IS NOT NULL',
        )
        .get();
    return {for (final row in rows) row.read<String>('k')};
  }
}
