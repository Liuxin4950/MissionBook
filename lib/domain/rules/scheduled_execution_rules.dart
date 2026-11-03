import '../entities/execution_event.dart';
import '../entities/mission_schedule_revision.dart';

/// 固定日程按墙上时钟结束；暂停不顺延，已保存的加时才顺延。
DateTime fixedTimeSlotEnd(
  DateTime fixedStartAt,
  int plannedDurationMinutes,
  List<ExecutionEvent> events,
) {
  final extra = events
      .where((event) => event.type == ExecutionEventType.extend)
      .fold<int>(0, (sum, event) => sum + event.grantedDurationMinutes!);
  return fixedStartAt.add(Duration(minutes: plannedDurationMinutes + extra));
}

/// 正在执行的固定任务应停止的时刻；调度延迟和暂停不改变该边界。
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
  return fixedTimeSlotEnd(
    schedule.fixedStartAt!,
    schedule.plannedDurationMinutes,
    events,
  );
}
