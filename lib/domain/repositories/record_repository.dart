import '../entities/evidence.dart';
import '../entities/user_execution_report.dart';
import '../entities/execution_event.dart';

abstract interface class RecordRepository {
  Future<void> deleteRecord(String id);
  Future<void> saveRecord(
    EvidenceDraft draft, {
    String? goalId,
    String? nodeId,
    String? missionId,
  });
  Future<void> linkRecord(
    String id, {
    String? goalId,
    String? nodeId,
    String? missionId,
    String? operationId,
  });
  Future<Map<String, Object?>> queryRecords({
    String? id,
    String? goalId,
    String? nodeId,
    String? missionId,
    String? date,
    int offset = 0,
    bool content = false,
    int contentOffset = 0,
  });
  Future<void> updateRecordContent(
    String id,
    String? expectedContent,
    String? content,
  );
  Future<void> reportExecution(
    UserExecutionReport report, {
    required int expectedSequence,
    required String scheduleId,
    UserReportedResult? result,
    bool? submitOptionalEvidence,
  });
  Future<Map<String, Object?>> analysis(String scope, String id);
  Future<Map<String, Object?>> associationChoices(
    String kind, {
    String search = '',
    int offset = 0,
  });
}
