import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/rules/execution_event_rules.dart';

Mission task({DateTime? cancelledAt}) => Mission(
  id: 'mission-1',
  title: '阅读',
  createdAt: DateTime.utc(2026, 10, 23),
  updatedAt: DateTime.utc(2026, 10, 23),
  cancelledAt: cancelledAt,
);

// 根据动作产生字段合法的测试事件，便于专门检查前后关系。
ExecutionEvent action(
  ExecutionEventType type,
  int sequence, {
  String? id,
  String missionId = 'mission-1',
  DateTime? time,
}) => ExecutionEvent(
  id: id ?? 'event-$sequence',
  missionId: missionId,
  sequence: sequence,
  type: type,
  occurredAt: time ?? DateTime.utc(2026, 10, 23, 8, sequence),
  scheduleRevisionId: type == ExecutionEventType.start ? 'revision-1' : null,
  grantedDurationMinutes: type == ExecutionEventType.extend ? 10 : null,
  userReportedResult: type == ExecutionEventType.end
      ? UserReportedResult.completed
      : null,
);

List<ExecutionEvent> history(List<ExecutionEventType> types) {
  final events = <ExecutionEvent>[];
  for (var index = 0; index < types.length; index += 1) {
    events.add(action(types[index], index + 1));
  }
  return events;
}

void main() {
  const start = ExecutionEventType.start;
  const pause = ExecutionEventType.pause;
  const resume = ExecutionEventType.resume;
  const extend = ExecutionEventType.extend;
  const end = ExecutionEventType.end;

  test('未开始和已取消任务允许空时间线，已取消任务拒绝任何执行事件', () {
    expect(() => validateExecutionHistory(task(), []), returnsNormally);
    final cancelled = task(cancelledAt: DateTime.utc(2026, 10, 23, 7));
    expect(() => validateExecutionHistory(cancelled, []), returnsNormally);
    expect(
      () => validateExecutionHistory(cancelled, history([start])),
      throwsArgumentError,
    );
  });

  // 用四种已知前置历史，检查所有五种下一动作，而非只验证一条成功路径。
  final prefixes = <String, List<ExecutionEventType>>{
    '未开始': [],
    '执行中': [start],
    '暂停': [start, pause],
    '结束': [start, end],
  };
  final allowed = <String, Set<ExecutionEventType>>{
    '未开始': {start},
    '执行中': {pause, extend, end},
    '暂停': {resume, extend, end},
    '结束': {},
  };
  for (final entry in prefixes.entries) {
    for (final next in ExecutionEventType.values) {
      test('${entry.key}后追加 $next 按规则接受或拒绝', () {
        final events = history([...entry.value, next]);
        expect(
          () => validateExecutionHistory(task(), events),
          allowed[entry.key]!.contains(next)
              ? returnsNormally
              : throwsArgumentError,
        );
      });
    }
  }

  test('延长不改变执行或暂停状态，允许多轮暂停和继续', () {
    for (final types in [
      [start, extend, pause, extend, resume, pause, resume, end],
      [start, pause, extend, end],
    ]) {
      expect(
        () => validateExecutionHistory(task(), history(types)),
        returnsNormally,
      );
    }
    expect(
      () => validateExecutionHistory(
        task(),
        history([start, pause, extend, pause]),
      ),
      throwsArgumentError,
    );
    expect(
      () => validateExecutionHistory(task(), history([start, extend, resume])),
      throwsArgumentError,
    );
  });

  test('首条序号非1、跳号、重复序号和乱序列表均被拒绝', () {
    for (final events in [
      [action(start, 2)],
      [action(start, 1), action(pause, 3)],
      [action(start, 1), action(pause, 1, id: 'other')],
      [action(pause, 2), action(start, 1)],
    ]) {
      expect(
        () => validateExecutionHistory(task(), events),
        throwsArgumentError,
      );
    }
  });

  test('不同序号也不能重复使用事件编号，不能混入其他任务', () {
    for (final events in [
      [action(start, 1), action(pause, 2, id: 'event-1')],
      [action(start, 1), action(pause, 2, missionId: 'mission-2')],
    ]) {
      expect(
        () => validateExecutionHistory(task(), events),
        throwsArgumentError,
      );
    }
  });

  test('相同时间戳允许，时间倒退拒绝，不修改调用方列表', () {
    final instant = DateTime.utc(2026, 10, 23, 8);
    final events = List<ExecutionEvent>.unmodifiable([
      action(start, 1, time: instant),
      action(pause, 2, time: instant),
    ]);
    expect(() => validateExecutionHistory(task(), events), returnsNormally);
    expect(events.map((event) => event.sequence), [1, 2]);
    expect(
      () => validateExecutionHistory(task(), [
        events.first,
        action(
          pause,
          2,
          time: instant.subtract(const Duration(milliseconds: 1)),
        ),
      ]),
      throwsArgumentError,
    );
  });

  test('时间线复用单条规则，不放过字段非法的事件', () {
    final invalid = ExecutionEvent(
      id: 'event-2',
      missionId: 'mission-1',
      sequence: 2,
      type: extend,
      occurredAt: DateTime.utc(2026, 10, 23, 8, 2),
      grantedDurationMinutes: -10,
    );
    expect(
      () => validateExecutionHistory(task(), [action(start, 1), invalid]),
      throwsArgumentError,
    );
  });
}
