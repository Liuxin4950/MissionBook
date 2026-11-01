import 'dart:async';
import 'dart:typed_data';
import '../attachments/attachment_coordinator.dart';
import '../../domain/entities/saved_record.dart';
import '../../domain/entities/record_draft.dart';
import '../../domain/entities/analysis_scope.dart';
import '../../domain/entities/evidence.dart';
import '../../domain/repositories/record_repository.dart';
import '../../domain/rules/content_rules.dart';
import '../missions/mission_service.dart';

/// 页面和助手共用的记录内容与归属入口；执行报告直接进入任务服务。
class RecordService {
  RecordService(this._repository, this._missions, this._attachments) {
    if (!identical(_missions.attachments, _attachments)) {
      throw ArgumentError('记录和任务必须共用同一个附件协调器');
    }
  }
  final RecordRepository _repository;
  final MissionService _missions;
  final AttachmentCoordinator _attachments;
  Stream<void> get changes => _missions.changes;
  Future<void> delete(String id) async {
    await _repository.deleteRecord(id);
    _missions.refreshAfterExternalCommit();
  }

  Future<void> save(
    RecordDraft draft, {
    String? goalId,
    String? nodeId,
    String? missionId,
  }) async {
    validateContentDraft(draft);
    await _attachments.synchronized(() async {
      final key = draft.attachmentStorageKey;
      if (key != null) await _attachments.read(key);
      await _repository.saveRecord(
        draft,
        goalId: goalId,
        nodeId: nodeId,
        missionId: missionId,
      );
      _attachments.markCommitted([draft]);
    });
    _missions.refreshAfterExternalCommit();
  }

  Future<void> initializeAttachments() => _attachments.initialize();
  Future<RecordDraft?> pickImage(String id) async {
    final content = await _attachments.pickImage(id);
    return content == null ? null : RecordDraft.fromContent(content);
  }

  Future<RecordDraft?> pickFile(String id) async {
    final content = await _attachments.pickFile(id);
    return content == null ? null : RecordDraft.fromContent(content);
  }

  Future<RecordDraft> captureImage(
    String id,
    Uint8List bytes, {
    required DateTime capturedAt,
  }) async => RecordDraft.fromContent(
    await _attachments.captureImage(id, bytes, capturedAt: capturedAt),
  );
  Future<Uint8List> readAttachment(String key) => _attachments.read(key);
  Future<void> discardDrafts(List<RecordDraft> drafts) =>
      _attachments.discard(drafts);

  Future<void> updateContent(
    String id,
    String? original,
    String? content,
  ) async {
    await _repository.updateRecordContent(id, original, content?.trim());
    _missions.refreshAfterExternalCommit();
  }

  Future<RecordDraft> readDraft(String id) => _repository.readDraft(id);

  Future<RecordPage> readRecords({
    String? id,
    String? goalId,
    String? nodeId,
    String? missionId,
    String? date,
    int offset = 0,
    bool content = false,
    int contentOffset = 0,
  }) => _repository.readRecords(
    id: id,
    goalId: goalId,
    nodeId: nodeId,
    missionId: missionId,
    date: date,
    offset: offset,
    content: content,
    contentOffset: contentOffset,
  );

  /// 设置记录自己的归属，清空两个参数表示恢复独立记录。
  Future<void> setOwnership(
    String id, {
    String? goalId,
    String? nodeId,
    String? operationId,
  }) async {
    await _repository.updateOwnership(
      id,
      goalId: goalId,
      nodeId: nodeId,
      operationId: operationId,
    );
    _missions.refreshAfterExternalCommit();
  }

  /// 为任务提交当前内容快照，不改变来源记录的归属。
  Future<void> useAsMaterial(
    String id,
    String missionId, {
    RecordDraft? expected,
    String? operationId,
  }) async {
    await _missions.useRecordAsMaterial(
      id,
      missionId,
      expected: expected == null ? null : EvidenceDraft.fromContent(expected),
      operationId: operationId,
    );
  }

  Future<Map<String, Object?>> analysis(AnalysisScope scope, String id) =>
      _repository.analysis(scope, id);

  Future<Map<String, Object?>> associationChoices(
    String kind, {
    String search = '',
    int offset = 0,
  }) => _repository.associationChoices(kind, search: search, offset: offset);
}
