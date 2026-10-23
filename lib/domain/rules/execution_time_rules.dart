import '../entities/execution_event.dart';

/// 由已校验的完整时间线计算毫秒统计；不存储，不使用 Timer 累加。
class ExecutionTimes {
  const ExecutionTimes({
    required this.focus,
    required this.paused,
    required this.elapsed,
    required this.extensionMinutes,
    required this.pauseCount,
    required this.clockBehind,
  });
  final Duration focus;
  final Duration paused;
  final Duration elapsed;
  final int extensionMinutes;
  final int pauseCount;
  final bool clockBehind;
}

ExecutionTimes calculateExecutionTimes(
  List<ExecutionEvent> events,
  DateTime now,
) {
  if (events.isEmpty) {
    return const ExecutionTimes(
      focus: Duration.zero,
      paused: Duration.zero,
      elapsed: Duration.zero,
      extensionMinutes: 0,
      pauseCount: 0,
      clockBehind: false,
    );
  }
  final ended = events.last.type == ExecutionEventType.end;
  final behind = !ended && now.isBefore(events.last.occurredAt);
  final bound = ended
      ? events.last.occurredAt
      : (behind ? events.last.occurredAt : now);
  var paused = Duration.zero;
  DateTime? pauseAt;
  var extension = 0;
  var pauseCount = 0;
  for (final event in events) {
    // 这里汇总暂停区间和额度，不重新决定动作是否合法或另建状态机。
    if (event.type == ExecutionEventType.pause) {
      pauseAt = event.occurredAt;
      pauseCount++;
    } else if ((event.type == ExecutionEventType.resume ||
            event.type == ExecutionEventType.end) &&
        pauseAt != null) {
      paused += event.occurredAt.difference(pauseAt);
      pauseAt = null;
    } else if (event.type == ExecutionEventType.extend) {
      extension += event.grantedDurationMinutes!;
    }
  }
  if (pauseAt != null) paused += bound.difference(pauseAt);
  final elapsed = bound.difference(events.first.occurredAt);
  return ExecutionTimes(
    focus: elapsed - paused,
    paused: paused,
    elapsed: elapsed,
    extensionMinutes: extension,
    pauseCount: pauseCount,
    clockBehind: behind,
  );
}
