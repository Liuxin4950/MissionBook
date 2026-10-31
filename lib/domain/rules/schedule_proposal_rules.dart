import '../entities/schedule_proposal.dart';
import '../entities/mission_schedule_revision.dart';

/// 仓储读取的占用时段；只是事实输入，不包含数据库或 UI 行为。
class ExistingScheduleSlot {
  const ExistingScheduleSlot({
    required this.missionId,
    required this.title,
    required this.start,
    required this.minutes,
  });
  final String missionId;
  final String title;
  final DateTime start;
  final int minutes;
}

/// 半开时段 [start, end)：首尾相接可安排，交叉或包含才算重叠。
bool scheduleWindowsOverlap(
  DateTime start,
  int minutes,
  DateTime otherStart,
  int otherMinutes,
) =>
    start.isBefore(otherStart.add(Duration(minutes: otherMinutes))) &&
    otherStart.isBefore(start.add(Duration(minutes: minutes)));

/// 预览和事务重读共用的冲突规则；仓储的 SQL 只负责筛选候选。
List<ScheduleConflict> scheduleProposalConflicts(
  ScheduleProposal plan,
  Iterable<ExistingScheduleSlot> occupied,
) {
  final conflicts = <ScheduleConflict>[];
  final replaced = plan.items.map((item) => item.missionId).toSet();
  final unique = {for (final slot in occupied) slot.missionId: slot};
  for (var index = 0; index < plan.items.length; index++) {
    final item = plan.items[index];
    final schedule = item.schedule;
    final start = schedule.fixedStartAt;
    if (schedule.timePolicy != TimePolicy.fixed || start == null) continue;
    for (final other in unique.values) {
      if (replaced.contains(other.missionId)) continue;
      if (scheduleWindowsOverlap(
        start,
        schedule.plannedDurationMinutes,
        other.start,
        other.minutes,
      )) {
        conflicts.add(
          ScheduleConflict(
            itemId: item.id,
            otherMissionId: other.missionId,
            message: '与已有安排“${other.title}”时间重叠，请调整',
          ),
        );
      }
    }
    for (final other in plan.items.take(index)) {
      final otherStart = other.schedule.fixedStartAt;
      if (otherStart == null ||
          !scheduleWindowsOverlap(
            start,
            schedule.plannedDurationMinutes,
            otherStart,
            other.schedule.plannedDurationMinutes,
          )) {
        continue;
      }
      conflicts.add(
        ScheduleConflict(
          itemId: item.id,
          otherMissionId: other.missionId,
          message: '与计划内“${other.title}”时间重叠，请调整',
        ),
      );
      conflicts.add(
        ScheduleConflict(
          itemId: other.id,
          otherMissionId: item.missionId,
          message: '与计划内“${item.title}”时间重叠，请调整',
        ),
      );
    }
  }
  return List.unmodifiable(conflicts);
}
