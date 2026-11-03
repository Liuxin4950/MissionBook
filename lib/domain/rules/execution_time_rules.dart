import '../entities/execution_event.dart';
import '../entities/mission_schedule_revision.dart';
import 'scheduled_execution_rules.dart';

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

/// 固定任务从计划起点累计，并在计划终点（含 EXTEND）封顶。
/// 旧版本迟到的 START 不改变计时锚点；未开始和纯历史补报不产生计时。
/// PAUSE 区间仍从专注中扣除，主动 END/STOP 冻结，其他任务沿用 START 时刻。
ExecutionTimes calculateExecutionTimes(
  List<ExecutionEvent> events,
  DateTime now, {
  MissionScheduleRevision? schedule,
}) {
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
  var bound = ended
      ? (stopped ?? events.last).occurredAt
      : (behind ? events.last.occurredAt : now);
  final fixed =
      schedule?.timePolicy == TimePolicy.fixed &&
      events.first.type == ExecutionEventType.start;
  final start = fixed ? schedule!.fixedStartAt! : events.first.occurredAt;
  if (fixed) {
    final end = fixedTimeSlotEnd(
      start,
      schedule!.plannedDurationMinutes,
      events,
    );
    if (bound.isAfter(end)) bound = end;
    if (bound.isBefore(start)) bound = start;
  }
  var paused = Duration.zero;
  DateTime? pauseAt;
  final extension = events
      .where((event) => event.type == ExecutionEventType.extend)
      .fold<int>(0, (sum, event) => sum + event.grantedDurationMinutes!);
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
    }
  }
  if (pauseAt != null) paused += bound.difference(pauseAt);
  final elapsed = bound.difference(start);
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
