import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/rules/execution_event_rules.dart';

Mission task({DateTime? cancelledAt}) => Mission(
  id: 'mission-1',
  title: '阅读',
  createdAt: DateTime.utc(2026, 10, 23),
  updatedAt: DateTime.utc(2026, 10, 23),
  cancelledAt: cancelledAt,
);

// 根据动作列表生成字段合法、序号连续的事件，作为推导函数的输入。
List<ExecutionEvent> history(List<ExecutionEventType> types) {
  final events = <ExecutionEvent>[];
  for (var index = 0; index < types.length; index += 1) {
    final type = types[index];
    events.add(
      ExecutionEvent(
        id: 'event-$index',
        missionId: 'mission-1',
        sequence: index + 1,
        type: type,
        occurredAt: DateTime.utc(2026, 10, 23, 8, index),
        scheduleRevisionId: type == ExecutionEventType.start
            ? 'revision-1'
            : null,
        grantedDurationMinutes: type == ExecutionEventType.extend ? 10 : null,
        userReportedResult: type == ExecutionEventType.end
            ? UserReportedResult.completed
            : null,
      ),
    );
  }
  return events;
}

void main() {
  const start = ExecutionEventType.start;
  const pause = ExecutionEventType.pause;
  const resume = ExecutionEventType.resume;
  const extend = ExecutionEventType.extend;
  const end = ExecutionEventType.end;

  test('无事件且未取消时为待开始', () {
    expect(derivePreEndMissionPhase(task(), []), MissionPhase.notStarted);
  });

  test('无事件且记录取消时为已取消', () {
    final cancelled = task(cancelledAt: DateTime.utc(2026, 10, 23, 7));
    expect(derivePreEndMissionPhase(cancelled, []), MissionPhase.cancelled);
  });

  final cases = <String, List<ExecutionEventType>>{
    '开始后': [start],
    '暂停后': [start, pause],
    '继续后': [start, pause, resume],
    '执行中延长后': [start, extend, extend],
    '暂停中延长后': [start, pause, extend, extend],
    '继续并再次暂停后': [start, pause, resume, pause],
  };
  final expected = <String, MissionPhase>{
    '开始后': MissionPhase.running,
    '暂停后': MissionPhase.paused,
    '继续后': MissionPhase.running,
    '执行中延长后': MissionPhase.running,
    '暂停中延长后': MissionPhase.paused,
    '继续并再次暂停后': MissionPhase.paused,
  };
  for (final entry in cases.entries) {
    test('${entry.key}按事实返回阶段，重复计算结果一致', () {
      final events = List<ExecutionEvent>.unmodifiable(history(entry.value));
      expect(derivePreEndMissionPhase(task(), events), expected[entry.key]);
      expect(derivePreEndMissionPhase(task(), events), expected[entry.key]);
    });
  }

  test('先校验后推导，取消事实不能掩盖已有执行事件', () {
    final cancelled = task(cancelledAt: DateTime.utc(2026, 10, 23, 9));
    expect(
      () => derivePreEndMissionPhase(cancelled, history([start])),
      throwsArgumentError,
    );
  });

  test('非法时间线不能被推导成看似合理的阶段', () {
    expect(
      () => derivePreEndMissionPhase(task(), history([start, pause, pause])),
      throwsArgumentError,
    );
    expect(
      () => derivePreEndMissionPhase(task(), history([resume])),
      throwsArgumentError,
    );
  });

  test('合法END明确提示尚未支持，不能误判为执行中或已关闭', () {
    // END是合法的执行动作；只是不在“结束前阶段查询”的支持范围内。
    expect(
      () => validateExecutionHistory(task(), history([start, end])),
      returnsNormally,
    );
    expect(
      () => derivePreEndMissionPhase(task(), history([start, end])),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('END后还有非法动作时先报时间线错误，不能用尚未支持掩盖损坏事实', () {
    final events = history([start, end, resume]);
    expect(() => validateExecutionHistory(task(), events), throwsArgumentError);
    expect(() => derivePreEndMissionPhase(task(), events), throwsArgumentError);
  });

  test('阶段入口同样拒绝跳号和混入其他任务的事件', () {
    final first = history([start]).single;
    for (final next in [
      ExecutionEvent(
        id: 'event-next',
        missionId: 'mission-1',
        sequence: 3,
        type: pause,
        occurredAt: DateTime.utc(2026, 10, 23, 9),
      ),
      ExecutionEvent(
        id: 'event-next',
        missionId: 'mission-other',
        sequence: 2,
        type: pause,
        occurredAt: DateTime.utc(2026, 10, 23, 9),
      ),
    ]) {
      expect(
        () => derivePreEndMissionPhase(task(), [first, next]),
        throwsArgumentError,
      );
    }
  });
}
