import 'package:mission_book/domain/entities/evidence.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/user_execution_report.dart';

/// 仅用于创建/读取页面的替身；误调用真实写入口时明确失败。
mixin UnusedMissionWrites {
  Future<EvidenceSubmissionResult> attachRecordEvidence(
    String recordId,
    String missionId,
  ) => throw UnsupportedError('本替身不关联材料');

  Future<void> reportExecution(
    UserExecutionReport report, {
    required int expectedSequence,
    required String scheduleId,
    UserReportedResult? result,
    bool? submitOptionalEvidence,
  }) => throw UnsupportedError('本替身不保存执行报告');
}
