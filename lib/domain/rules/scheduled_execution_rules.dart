import '../entities/execution_event.dart';
import '../entities/mission_schedule_revision.dart';

/// 固定日程按墙上时钟结束；暂停不顺延，已保存的加时才顺延。
/// 已错过整个时段后手动开始的任务，从实际开始时刻获得完整预算。
DateTime? scheduledExecutionEnd(
  MissionScheduleRevision schedule,
  List<ExecutionEvent> events,
) {
  if (schedule.timePolicy != TimePolicy.fixed ||
      events.isEmpty ||
      events.first.type != ExecutionEventType.start ||
      events.any(
        (event) =>
            event.type == ExecutionEventType.stop ||
            event.type == ExecutionEventType.end,
      )) {
    return null;
  }
  final plannedEnd = schedule.fixedStartAt!.add(
    Duration(minutes: schedule.plannedDurationMinutes),
  );
  final startedAt = events.first.occurredAt;
  final baseEnd = startedAt.isBefore(plannedEnd)
      ? plannedEnd
      : startedAt.add(Duration(minutes: schedule.plannedDurationMinutes));
  final extra = events
      .where((event) => event.type == ExecutionEventType.extend)
      .fold<int>(0, (sum, event) => sum + event.grantedDurationMinutes!);
  final end = baseEnd.add(Duration(minutes: extra));
  // 旧版本可能已在应结束时刻之后保存动作；保留原事实，不能倒序插入 STOP。
  return end.isBefore(events.last.occurredAt) ? events.last.occurredAt : end;
}
