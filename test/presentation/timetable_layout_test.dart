import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/presentation/missions/all/timetable_layout.dart';

MissionDetail planned(
  String id,
  DateTime start,
  int minutes, {
  bool cancelled = false,
}) => MissionDetail(
  mission: Mission(
    id: id,
    title: id,
    createdAt: start,
    updatedAt: start,
    cancelledAt: cancelled ? start : null,
  ),
  schedule: MissionScheduleRevision(
    id: 'schedule-$id',
    missionId: id,
    revisionNumber: 1,
    scheduledDate: '2026-10-25',
    timeZone: 'Asia/Shanghai',
    timePolicy: TimePolicy.fixed,
    fixedStartAt: start,
    plannedDurationMinutes: minutes,
    changedAt: start,
  ),
  executionPlan: ExecutionPlan(
    id: 'plan-$id',
    missionId: id,
    objective: id,
    createdAt: start,
    updatedAt: start,
  ),
);

void main() {
  setUpAll(tz.initializeTimeZones);
  final day = DateTime(2026, 10, 25);
  DateTime at(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 10, 25, hour - 8, minute);

  test('计划重叠按真实交集计算，并排不改变开始与时长', () {
    final result = TimetableDay.build([
      planned('英语', at(10, 30), 90),
      planned('讨论', at(11), 90),
    ], day);
    expect(result.conflicts.single.start, 660);
    expect(result.conflicts.single.end, 720);
    expect(result.slots.map((s) => s.conflictMinutes), [60, 60]);
    expect(result.slots.map((s) => s.column).toSet(), {0, 1});
    expect(result.slots.map((s) => s.columns), [2, 2]);
    expect(result.slots.first.start, 630);
    expect(result.slots.first.end - result.slots.first.start, 90);
  });
  test('相接任务不冲突，独立组恢复全宽', () {
    final result = TimetableDay.build([
      planned('a', at(9), 60),
      planned('b', at(10), 30),
      planned('c', at(13), 60),
    ], day);
    expect(result.conflicts, isEmpty);
    expect(result.slots.every((s) => s.columns == 1), isTrue);
  });
  test('三重与链式重叠取区间并集，已释放的列可以复用', () {
    final result = TimetableDay.build([
      planned('a', at(9), 180),
      planned('b', at(9, 30), 60),
      planned('c', at(10), 60),
      planned('d', at(11), 30),
    ], day);
    final a = result.slots.first;
    expect(a.conflictMinutes, 120); // 09:30–11:30，不重复计算三重交集。
    expect(a.columns, 3);
    for (final first in result.slots) {
      for (final second in result.slots) {
        if (first.id == second.id ||
            first.end <= second.start ||
            second.end <= first.start) {
          continue;
        }
        expect(first.column, isNot(second.column));
      }
    }
  });
  test('隐藏任务仍参与冲突检测，取消任务不占用时段', () {
    final result = TimetableDay.build(
      [
        planned('a', at(10), 60),
        planned('hidden', at(10, 30), 60),
        planned('cancelled', at(10), 60, cancelled: true),
      ],
      day,
      visible: (detail) => detail.mission.id == 'a',
    );
    expect(result.slots.single.columns, 1);
    expect(result.slots.single.conflictMinutes, 30);
    expect(result.conflicts.single.second.id, 'hidden');
  });
  test('跨午夜分到两天，边界00:00不多占一天', () {
    final records = [planned('night', at(23, 30), 120)];
    final first = TimetableDay.build(records, day).slots.single;
    final second = TimetableDay.build(
      records,
      DateTime(2026, 10, 26),
    ).slots.single;
    expect([first.start, first.end], [1410, 1440]);
    expect([second.start, second.end], [0, 90]);
    expect(
      TimetableDay.build([
        planned('end', at(23), 60),
      ], DateTime(2026, 10, 26)).slots,
      isEmpty,
    );
    expect(timetableClock(1440), '24:00');
  });
  test('不同来源时区在统一北京时间轴上按绝对时刻检测', () {
    expect(timetableNow(DateTime.utc(2026, 10, 24, 18)).day, 25);
    final result = TimetableDay.build([
      planned('utc', DateTime.utc(2026, 10, 25, 1), 60),
      planned('offset', DateTime.parse('2026-10-24T21:30:00-04:00'), 60),
    ], day);
    expect(result.slots.first.start, 540);
    expect(result.slots.first.conflictMinutes, 30);
  });
}
