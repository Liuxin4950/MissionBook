import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/presentation/missions/all/timetable_layout.dart';
import 'package:mission_book/presentation/missions/all/week_timetable_layout.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'timetable_layout_test.dart' show planned, flexible;

void main() {
  setUpAll(tz.initializeTimeZones);

  test('周界按日历计算，周日仍属于本周，跨年保留完整七天', () {
    expect(
      timetableWeekStart(DateTime.utc(2026, 11, 15)),
      DateTime.utc(2026, 11, 9),
    );
    expect(
      timetableWeekStart(DateTime.utc(2027, 1, 1)),
      DateTime.utc(2026, 12, 28),
    );
    final week = TimetableWeek.build(
      [],
      DateTime.utc(2027, 1, 1),
      now: DateTime.utc(2027),
      visible: (_) => true,
    );
    expect(week.days.map((day) => timetableDateKey(day.date)), [
      '2026-12-28',
      '2026-12-29',
      '2026-12-30',
      '2026-12-31',
      '2027-01-01',
      '2027-01-02',
      '2027-01-03',
    ]);
  });

  test('周起点使用业务时区今天，UTC 周日的北京时间周一不能落入上周', () {
    final instant = DateTime.utc(2026, 11, 8, 17);
    expect(
      timetableWeekStart(timetableNow(instant)),
      DateTime.utc(2026, 11, 9),
    );
  });

  test('跨周区间按半开范围裁切，周一零点结束不多占下一周', () {
    final sunday = planned('周日夜间', DateTime.utc(2026, 11, 15, 15, 30), 120);
    final untilMidnight = planned('整点结束', DateTime.utc(2026, 11, 15, 15), 60);
    final monday = DateTime.utc(2026, 11, 16);
    final next = DateTime.utc(2026, 11, 23);
    final now = DateTime.utc(2026, 11, 16, 2);
    expect(timetableOverlapsRange(sunday, monday, next, now), isTrue);
    expect(timetableOverlapsRange(untilMidnight, monday, next, now), isFalse);
    final week = TimetableWeek.build(
      [sunday, untilMidnight],
      monday,
      now: now,
      visible: (_) => true,
    );
    final slot = week.days.first.layout.slots.single;
    expect(slot.id, '周日夜间');
    expect(slot.start, 0);
    expect(slot.end, 90);
    expect(slot.continuesBefore, isTrue);
    expect(week.days.skip(1).every((day) => day.layout.slots.isEmpty), isTrue);
  });

  test('筛选保留隐藏任务冲突，但不让整周以外的固定任务入图', () {
    final first = planned('可见', DateTime.utc(2026, 11, 9, 1), 90);
    final hidden = planned('隐藏', DateTime.utc(2026, 11, 9, 1, 30), 90);
    final outside = planned('下周', DateTime.utc(2026, 11, 16, 1), 90);
    final week = TimetableWeek.build(
      [first, hidden, outside],
      DateTime.utc(2026, 11, 9),
      now: DateTime.utc(2026, 11, 9),
      visible: (detail) => detail.mission.id != '隐藏',
    );
    expect(week.days.first.layout.slots.map((slot) => slot.id), ['可见']);
    expect(week.days.first.layout.conflicts, hasLength(1));
    expect(week.days.first.layout.slots.single.conflictMinutes, 60);
  });

  test('重叠链合并入口，相邻时段分开，实际与计划重叠不冒充冲突', () {
    final day = DateTime.utc(2026, 10, 25);
    final layout = TimetableDay.build([
      planned('一', DateTime.utc(2026, 10, 25, 1), 60),
      planned('二', DateTime.utc(2026, 10, 25, 1, 30), 60),
      planned('三', DateTime.utc(2026, 10, 25, 2, 20), 40),
      planned('四', DateTime.utc(2026, 10, 25, 3), 30),
    ], day);
    final blocks = weekTimetableBlocks(layout.slots);
    expect(blocks, hasLength(2));
    expect(blocks.first.slots.map((slot) => slot.id), ['一', '二', '三']);
    expect(blocks.first.start, 540);
    expect(blocks.first.end, 660);
    expect(blocks.first.hasConflict, isTrue);
    final actual = TimetableDay.build([
      planned('计划', DateTime.utc(2026, 10, 25, 1), 60),
      flexible(
        '实际',
        DateTime.utc(2026, 10, 25, 1, 30),
        DateTime.utc(2026, 10, 25, 2),
      ),
    ], day);
    expect(weekTimetableBlocks(actual.slots).single.hasConflict, isFalse);
  });

  test('日历上界保留七个槽位，超出支持年份的日期不可操作', () {
    final week = TimetableWeek.build(
      [],
      DateTime.utc(9999, 12, 31),
      now: DateTime.utc(9999, 12, 31),
      visible: (_) => true,
    );
    expect(week.days, hasLength(7));
    expect(
      week.days.where((day) => day.supported).last.date,
      DateTime.utc(9999, 12, 31),
    );
  });
}
