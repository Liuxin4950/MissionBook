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
  final stopped = events
      .where((event) => event.type == ExecutionEventType.stop)
      .firstOrNull;
  final ended = stopped != null || events.last.type == ExecutionEventType.end;
  final behind = !ended && now.isBefore(events.last.occurredAt);
  final bound = ended
      ? (stopped ?? events.last).occurredAt
      : (behind ? events.last.occurredAt : now);
  var paused = Duration.zero;
  DateTime? pauseAt;
  var extension = 0;
  var pauseCount = 0;
  for (final event in events) {
    if (event.occurredAt.isAfter(bound)) break;
    // 这里汇总暂停区间和额度，不重新决定动作是否合法或另建状态机。
    if (event.type == ExecutionEventType.pause) {
      pauseAt = event.occurredAt;
      pauseCount++;
    } else if ((event.type == ExecutionEventType.resume ||
            event.type == ExecutionEventType.end ||
            event.type == ExecutionEventType.stop) &&
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

/// Current Budget（当前预算）= 原计划时长 + 已增加额度。
///
/// plannedDurationMinutes 是 START 所绑定排期的原计划分钟数；
/// times.extensionMinutes 是全部 EXTEND 事件累计的增加分钟数。
/// 执行页的额度提示、进度环分母和记录页的预算展示都用这里的结果，
/// 不在页面里各自手写“原计划 + 额度”的加法。
Duration currentBudget(ExecutionTimes times, int plannedDurationMinutes) =>
    Duration(minutes: plannedDurationMinutes + times.extensionMinutes);

/// Actual Overtime（实际超时）= max(Focus − 原计划时长, 0)。
///
/// 按领域口径超时不为负：没超时就是 Duration.zero，调用方按“大于零才显示”处理。
Duration actualOvertime(ExecutionTimes times, int plannedDurationMinutes) {
  final overtime = times.focus - Duration(minutes: plannedDurationMinutes);
  return overtime.isNegative ? Duration.zero : overtime;
}
