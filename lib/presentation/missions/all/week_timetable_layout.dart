import 'dart:math' as math;

import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';
import 'timetable_layout.dart';

/// 只取日历字段，使用 UTC 做日历加减，避免设备时区和夏令时改变周界。
DateTime timetableWeekStart(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day - day.weekday + 1);

const timetableWeekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class WeekTimetableDay {
  const WeekTimetableDay(this.date, this.layout, this.other);
  final DateTime date;
  final TimetableDay layout;
  final List<MissionDetail> other;
  bool get supported => date.year >= 1 && date.year <= 9999;
}

/// 七天使用同一个任务快照；先收窄区间，再逐日裁切，隐藏任务仍参与冲突检测。
class TimetableWeek {
  TimetableWeek.build(
    List<MissionDetail> records,
    DateTime anchor, {
    required DateTime now,
    required bool Function(MissionDetail) visible,
  }) : start = timetableWeekStart(anchor) {
    final until = DateTime.utc(start.year, start.month, start.day + 7);
    final source = records
        .where((detail) => timetableOverlapsRange(detail, start, until, now))
        .toList();
    days = [
      for (var offset = 0; offset < 7; offset++)
        for (final date in [
          DateTime.utc(start.year, start.month, start.day + offset),
        ])
          WeekTimetableDay(
            date,
            TimetableDay.build(source, date, now: now, visible: visible),
            source
                .where(
                  (detail) =>
                      visible(detail) &&
                      detail.schedule.scheduledDate == timetableDateKey(date) &&
                      (detail.schedule.fixedStartAt == null ||
                          detail.phase == MissionPhase.cancelled),
                )
                .toList(),
          ),
    ];
  }

  final DateTime start;
  late final List<WeekTimetableDay> days;
}

/// 同一天的重叠安排合并成可展开入口；不把窄列再拆成无法阅读的子列。
/// 分组只影响呈现，真实冲突仍由 TimetableDay 判断，实际执行不冒充计划冲突。
class WeekTimetableBlock {
  WeekTimetableBlock(this.slots);
  final List<TimetableSlot> slots;
  double get start => slots.first.start;
  double get end => slots.fold(start, (end, slot) => math.max(end, slot.end));
  bool get hasConflict => slots.any((slot) => slot.conflicts.isNotEmpty);
}

List<WeekTimetableBlock> weekTimetableBlocks(List<TimetableSlot> slots) {
  final sorted = [...slots]..sort((a, b) => a.start.compareTo(b.start));
  final blocks = <WeekTimetableBlock>[];
  for (final slot in sorted) {
    if (blocks.isEmpty || slot.start >= blocks.last.end) {
      blocks.add(WeekTimetableBlock([slot]));
    } else {
      blocks.last.slots.add(slot);
    }
  }
  return blocks;
}
