import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/rules/execution_time_rules.dart';

void main() {
  final start = DateTime.utc(2026, 11, 11, 2);
  final schedule = MissionScheduleRevision(
    id: 'schedule',
    missionId: 'mission',
    revisionNumber: 1,
    scheduledDate: '2026-11-11',
    timeZone: 'Asia/Shanghai',
    plannedDurationMinutes: 30,
    timePolicy: TimePolicy.fixed,
    fixedStartAt: start,
    changedAt: start,
  );
  ExecutionEvent event(int sequence, ExecutionEventType type, int minute) =>
      ExecutionEvent(
        id: 'e$sequence',
        missionId: 'mission',
        sequence: sequence,
        type: type,
        occurredAt: start.add(Duration(minutes: minute)),
        scheduleRevisionId: sequence == 1 ? 'schedule' : null,
        grantedDurationMinutes: type == ExecutionEventType.extend ? 5 : null,
        userReportedResult: type == ExecutionEventType.end
            ? UserReportedResult.completed
            : null,
      );
  test('未开始与纯历史 END 不产生应用计时', () {
    expect(calculateExecutionTimes([], start).elapsed, Duration.zero);
    expect(
      calculateExecutionTimes([
        event(1, ExecutionEventType.end, 90),
      ], start).focus,
      Duration.zero,
    );
  });
  test('迟到 START 仍固定计划起点，暂停扣除，EXTEND 封顶，STOP 后 END 不增加计时', () {
    final events = [
      event(1, ExecutionEventType.start, 7),
      event(2, ExecutionEventType.pause, 10),
      event(3, ExecutionEventType.extend, 20),
      event(4, ExecutionEventType.resume, 25),
      event(5, ExecutionEventType.stop, 35),
      event(6, ExecutionEventType.end, 90),
    ];
    final result = calculateExecutionTimes(
      events,
      start.add(const Duration(hours: 3)),
      schedule: schedule,
    );
    expect(result.elapsed, const Duration(minutes: 35));
    expect(result.paused, const Duration(minutes: 15));
    expect(result.focus, const Duration(minutes: 20));
    expect(result.pauseCount, 1);
    expect(result.extensionMinutes, 5);
    expect(currentBudget(result, 30), const Duration(minutes: 35));
    expect(actualOvertime(result, 30), Duration.zero);
  });
  test('暂停中加时不恢复专注，固定结束后等待不延长预算', () {
    final result = calculateExecutionTimes(
      [
        event(1, ExecutionEventType.start, 0),
        event(2, ExecutionEventType.pause, 10),
        event(3, ExecutionEventType.extend, 15),
      ],
      start.add(const Duration(hours: 1)),
      schedule: schedule,
    );
    expect(result.elapsed, const Duration(minutes: 35));
    expect(result.focus, const Duration(minutes: 10));
    expect(result.paused, const Duration(minutes: 25));
  });
  test('时钟回拨提示 clockBehind，专注与暂停均不产生负数', () {
    final result = calculateExecutionTimes(
      [
        event(1, ExecutionEventType.start, 0),
        event(2, ExecutionEventType.pause, 10),
      ],
      start.add(const Duration(minutes: 4)),
      schedule: schedule,
    );
    expect(result.clockBehind, isTrue);
    expect(result.focus, const Duration(minutes: 10));
    expect(result.paused, Duration.zero);
  });
}
