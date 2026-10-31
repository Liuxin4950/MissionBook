import '../entities/mission_detail.dart';
import '../entities/evidence.dart';

/// 任务仓储的材料命令与查询契约。
abstract interface class MissionEvidenceRepository {
  /// 稳定批次身份、事务重读、整批原子保存；已超时返回已提交的超时结果。
  Future<EvidenceSubmissionResult> submitEvidence(
    EvidenceSubmission submission,
  );

  Future<Evidence> correctEvidence(EvidenceCorrection correction);

  Future<void> skipOptionalEvidence(String missionId);

  Future<int> reconcileEvidenceDeadlines();

  Future<List<MissionDetail>> findPendingEvidence();

  Future<Set<String>> referencedAttachmentKeys();

  /// 关联既有记录也复用材料提交规则；任何阶段可保留材料，超时事实不被覆盖。
  Future<EvidenceSubmissionResult> attachRecordEvidence(
    String recordId,
    String missionId,
  );
}
