import 'package:timezone/timezone.dart' as tz;
import '../entities/mission_phase.dart';
import '../entities/mission_schedule_revision.dart';

enum MissionAttention { none, overdue, reportPending }

/// 需要处理是时刻相关的查询标记，不增加另一套可写阶段。
MissionAttention missionAttention(
  MissionPhase phase,
  MissionScheduleRevision schedule,
  DateTime now,
) {
  if (phase == MissionPhase.reportPending) {
    return MissionAttention.reportPending;
  }
  if (phase != MissionPhase.notStarted) return MissionAttention.none;
  if (schedule.fixedStartAt != null) {
    return !now.isBefore(
          schedule.fixedStartAt!.add(
            Duration(minutes: schedule.plannedDurationMinutes),
          ),
        )
        ? MissionAttention.overdue
        : MissionAttention.none;
  }
  final local = tz.TZDateTime.from(now, tz.getLocation(schedule.timeZone));
  final today =
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  return schedule.scheduledDate.compareTo(today) < 0
      ? MissionAttention.overdue
      : MissionAttention.none;
}
