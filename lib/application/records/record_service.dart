import '../../domain/entities/analysis_scope.dart';
import '../../domain/entities/evidence.dart';
import '../../domain/entities/user_execution_report.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/repositories/record_repository.dart';
import '../../domain/rules/evidence_rules.dart';
import '../missions/mission_service.dart';

/// 页面和 AI 共用记录、关联、补记和记忆的业务入口。
class RecordService {
  RecordService(this.repository, this.missions);
  final RecordRepository repository;
  final MissionService missions;
  Future<void> delete(String id) async {
    await repository.deleteRecord(id);
    missions.refreshAfterExternalCommit();
  }

  Future<void> save(
    EvidenceDraft draft, {
    String? goalId,
    String? nodeId,
    String? missionId,
  }) async {
    validateEvidenceDraft(draft, missionId ?? draft.id);
    await missions.commitRecordAttachment(
      draft,
      () => repository.saveRecord(
        draft,
        goalId: goalId,
        nodeId: nodeId,
        missionId: missionId,
      ),
    );
  }

  Future<void> link(
    String id, {
    String? goalId,
    String? nodeId,
    String? missionId,
    String? operationId,
  }) async {
    await repository.linkRecord(
      id,
      goalId: goalId,
      nodeId: nodeId,
      missionId: missionId,
      operationId: operationId,
    );
    missions.refreshAfterExternalCommit();
  }

  Future<void> updateContent(
    String id,
    String? original,
    String? content,
  ) async {
    await repository.updateRecordContent(id, original, content?.trim());
    missions.refreshAfterExternalCommit();
  }

  Future<void> report(
    UserExecutionReport report,
    MissionDetail detail, {
    UserReportedResult? result,
    bool? submitOptionalEvidence,
  }) async {
    await missions.reportExecution(
      report,
      expectedSequence: detail.lastSequence,
      scheduleId: detail.schedule.id,
      result: result,
      submitOptionalEvidence: submitOptionalEvidence,
    );
  }

  Future<Map<String, Object?>> queryRecords({
    String? id,
    String? goalId,
    String? nodeId,
    String? missionId,
    String? date,
    int offset = 0,
    bool content = false,
    int contentOffset = 0,
  }) => repository.queryRecords(
    id: id,
    goalId: goalId,
    nodeId: nodeId,
    missionId: missionId,
    date: date,
    offset: offset,
    content: content,
    contentOffset: contentOffset,
  );

  Future<Map<String, Object?>> analysis(AnalysisScope scope, String id) =>
      repository.analysis(scope, id);

  Future<Map<String, Object?>> associationChoices(
    String kind, {
    String search = '',
    int offset = 0,
  }) => repository.associationChoices(kind, search: search, offset: offset);
}
