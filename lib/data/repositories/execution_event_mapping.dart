import 'package:drift/drift.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/failure_record.dart';
import '../local/app_database.dart';

String executionTypeText(ExecutionEventType type) => switch (type) {
  ExecutionEventType.start => 'START',
  ExecutionEventType.pause => 'PAUSE',
  ExecutionEventType.resume => 'RESUME',
  ExecutionEventType.extend => 'EXTEND',
  ExecutionEventType.stop => 'STOP',
  ExecutionEventType.end => 'END',
};

ExecutionEventsCompanion eventToCompanion(ExecutionEvent event) =>
    ExecutionEventsCompanion.insert(
      id: event.id,
      missionId: event.missionId,
      sequence: event.sequence,
      type: executionTypeText(event.type),
      occurredAt: event.occurredAt.millisecondsSinceEpoch,
      scheduleRevisionId: Value(event.scheduleRevisionId),
      grantedDurationMinutes: Value(event.grantedDurationMinutes),
      reason: Value(event.reason),
      userReportedResult: Value(switch (event.userReportedResult) {
        UserReportedResult.completed => 'COMPLETED',
        UserReportedResult.notCompleted => 'NOT_COMPLETED',
        null => null,
      }),
      submitOptionalEvidence: Value(event.submitOptionalEvidence),
      isRetrospective: Value(event.isRetrospective),
    );

ExecutionEvent eventFromRow(ExecutionEventRow row) => ExecutionEvent(
  id: row.id,
  missionId: row.missionId,
  sequence: row.sequence,
  type: switch (row.type) {
    'START' => ExecutionEventType.start,
    'PAUSE' => ExecutionEventType.pause,
    'RESUME' => ExecutionEventType.resume,
    'EXTEND' => ExecutionEventType.extend,
    'STOP' => ExecutionEventType.stop,
    'END' => ExecutionEventType.end,
    _ => throw FormatException('未知执行动作：${row.type}'),
  },
  occurredAt: DateTime.fromMillisecondsSinceEpoch(row.occurredAt, isUtc: true),
  scheduleRevisionId: row.scheduleRevisionId,
  grantedDurationMinutes: row.grantedDurationMinutes,
  reason: row.reason,
  userReportedResult: switch (row.userReportedResult) {
    'COMPLETED' => UserReportedResult.completed,
    'NOT_COMPLETED' => UserReportedResult.notCompleted,
    null => null,
    _ => throw FormatException('未知报告结果：${row.userReportedResult}'),
  },
  submitOptionalEvidence: row.submitOptionalEvidence,
  isRetrospective: row.isRetrospective,
);

FailureRecord failureFromRow(FailureRecordRow row) => FailureRecord(
  id: row.id,
  missionId: row.missionId,
  trigger: row.trigger,
  occurredAt: DateTime.fromMillisecondsSinceEpoch(row.occurredAt, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
  userReasonCategory: row.userReasonCategory,
  userReasonText: row.userReasonText,
);
