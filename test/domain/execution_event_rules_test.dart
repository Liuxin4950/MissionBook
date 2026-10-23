import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/rules/execution_event_rules.dart';

// 每次构造独立的事件；测试只替换当前关注的输入。
ExecutionEvent event({
  String id = 'event-1',
  String missionId = 'mission-1',
  int sequence = 1,
  DateTime? occurredAt,
  ExecutionEventType type = ExecutionEventType.resume,
  String? scheduleRevisionId,
  int? grantedDurationMinutes,
  String? reason,
  UserReportedResult? result,
  bool? evidenceChoice,
}) {
  return ExecutionEvent(
    id: id,
    missionId: missionId,
    sequence: sequence,
    occurredAt: occurredAt ?? DateTime.utc(2026, 10, 23, 8),
    type: type,
    scheduleRevisionId: scheduleRevisionId,
    grantedDurationMinutes: grantedDurationMinutes,
    reason: reason,
    userReportedResult: result,
    submitOptionalEvidence: evidenceChoice,
  );
}

void main() {
  test('五种事件的合法字段组合通过，校验不改变输入', () {
    final events = [
      event(type: ExecutionEventType.start, scheduleRevisionId: 'revision-1'),
      event(type: ExecutionEventType.pause),
      event(type: ExecutionEventType.pause, reason: '接电话'),
      event(type: ExecutionEventType.resume),
      event(type: ExecutionEventType.extend, grantedDurationMinutes: 10),
      event(type: ExecutionEventType.end, result: UserReportedResult.completed),
    ];
    for (final value in events) {
      expect(
        () => validateExecutionEvent(value, VerificationPolicy.selfReport),
        returnsNormally,
      );
      expect(value.id, 'event-1');
      expect(value.sequence, 1);
    }
  });

  test('空身份、非正序号和非 UTC 时刻被拒绝', () {
    final invalidEvents = [
      event(id: '  '),
      event(missionId: ''),
      event(sequence: 0),
      event(sequence: -1),
      event(occurredAt: DateTime(2026, 10, 23, 8)),
    ];
    for (final value in invalidEvents) {
      expect(
        () => validateExecutionEvent(value, VerificationPolicy.selfReport),
        throwsArgumentError,
      );
    }
  });

  test('START 必须提供非空排期编号', () {
    for (final revisionId in [null, '', '  ']) {
      expect(
        () => validateExecutionEvent(
          event(type: ExecutionEventType.start, scheduleRevisionId: revisionId),
          VerificationPolicy.selfReport,
        ),
        throwsArgumentError,
      );
    }
  });

  test('EXTEND 必须提供正整数分钟', () {
    for (final minutes in [null, 0, -10]) {
      expect(
        () => validateExecutionEvent(
          event(
            type: ExecutionEventType.extend,
            grantedDurationMinutes: minutes,
          ),
          VerificationPolicy.selfReport,
        ),
        throwsArgumentError,
      );
    }
  });

  test('每种动作均拒绝不属于自己的专属字段', () {
    for (final type in ExecutionEventType.values) {
      // 先补齐当前动作的必填字段，避免其他错误掩盖本次检查。
      final revision = type == ExecutionEventType.start ? 'revision-1' : null;
      final minutes = type == ExecutionEventType.extend ? 10 : null;
      final result = type == ExecutionEventType.end
          ? UserReportedResult.completed
          : null;
      final invalidEvents = [
        if (type != ExecutionEventType.start)
          event(
            type: type,
            scheduleRevisionId: 'wrong',
            grantedDurationMinutes: minutes,
            result: result,
          ),
        if (type != ExecutionEventType.extend)
          event(
            type: type,
            scheduleRevisionId: revision,
            grantedDurationMinutes: 10,
            result: result,
          ),
        if (type != ExecutionEventType.pause)
          event(
            type: type,
            scheduleRevisionId: revision,
            grantedDurationMinutes: minutes,
            reason: 'wrong',
            result: result,
          ),
        if (type != ExecutionEventType.end)
          event(
            type: type,
            scheduleRevisionId: revision,
            grantedDurationMinutes: minutes,
            result: UserReportedResult.completed,
          ),
      ];
      for (final value in invalidEvents) {
        expect(
          () => validateExecutionEvent(value, VerificationPolicy.selfReport),
          throwsArgumentError,
          reason: '动作 $type 不能携带其他动作的专属字段',
        );
      }
    }
  });

  test('所有策略的 END 都必须提供报告结果', () {
    for (final policy in VerificationPolicy.values) {
      expect(
        () =>
            validateExecutionEvent(event(type: ExecutionEventType.end), policy),
        throwsArgumentError,
      );
    }
  });

  test('END 材料选择覆盖所有策略、报告结果和三种空值组合', () {
    for (final policy in VerificationPolicy.values) {
      for (final result in UserReportedResult.values) {
        for (final choice in [null, false, true]) {
          final needsChoice =
              policy == VerificationPolicy.optionalEvidence &&
              result == UserReportedResult.completed;
          final valid = needsChoice ? choice != null : choice == null;
          expect(
            () => validateExecutionEvent(
              event(
                type: ExecutionEventType.end,
                result: result,
                evidenceChoice: choice,
              ),
              policy,
            ),
            valid ? returnsNormally : throwsArgumentError,
            reason: '$policy / $result / $choice',
          );
        }
      }
    }
  });

  test('非 END 不能携带材料选择，包括 false', () {
    for (final type in ExecutionEventType.values) {
      if (type == ExecutionEventType.end) continue;
      for (final choice in [false, true]) {
        expect(
          () => validateExecutionEvent(
            event(
              type: type,
              scheduleRevisionId: type == ExecutionEventType.start
                  ? 'revision-1'
                  : null,
              grantedDurationMinutes: type == ExecutionEventType.extend
                  ? 10
                  : null,
              evidenceChoice: choice,
            ),
            VerificationPolicy.optionalEvidence,
          ),
          throwsArgumentError,
        );
      }
    }
  });
}
