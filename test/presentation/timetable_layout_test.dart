import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:mission_book/domain/entities/execution_event.dart';
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

/// 自选任务：没有固定开始时刻，执行区间从事实（START/END）读取。
/// startAt 为空表示还没开始（无执行记录）；已取消任务按领域规则也不能有事件。
MissionDetail flexible(
  String id,
  DateTime? startAt,
  DateTime? endAt, {
  bool cancelled = false,
}) {
  final anchor = startAt ?? DateTime.utc(2026, 10, 25, 8);
  final events = <ExecutionEvent>[
    if (startAt != null && !cancelled)
      ExecutionEvent(
        id: 'start-$id',
        missionId: id,
        sequence: 1,
        type: ExecutionEventType.start,
        occurredAt: startAt,
        scheduleRevisionId: 'schedule-$id',
      ),
    if (startAt != null && endAt != null && !cancelled)
      ExecutionEvent(
        id: 'end-$id',
        missionId: id,
        sequence: 2,
        type: ExecutionEventType.end,
        occurredAt: endAt,
        userReportedResult: UserReportedResult.completed,
      ),
  ];
  return MissionDetail(
    mission: Mission(
      id: id,
      title: id,
      createdAt: anchor,
      updatedAt: anchor,
      cancelledAt: cancelled ? anchor : null,
    ),
    schedule: MissionScheduleRevision(
      id: 'schedule-$id',
      missionId: id,
      revisionNumber: 1,
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      timePolicy: TimePolicy.flexible,
      plannedDurationMinutes: 30,
      changedAt: anchor,
    ),
    executionPlan: ExecutionPlan(
      id: 'plan-$id',
      missionId: id,
      objective: id,
      createdAt: anchor,
      updatedAt: anchor,
    ),
    events: events,
  );
}

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

  test('自选任务按执行记录上图，未开始与已取消不上图', () {
    final result = TimetableDay.build([
      flexible('已完成', at(20), at(21, 11)),
      flexible('未开始', null, null),
      flexible('已取消', at(9), null, cancelled: true),
    ], day);
    final slot = result.slots.single;
    expect(slot.id, '已完成');
    expect(slot.actual, isTrue);
    expect(slot.start, 20 * 60.0);
    expect(slot.end - slot.start, 71);
    expect(slot.timeLabel, startsWith('实际 '));
    // 实际区间只参与显示排布，不制造“计划时间冲突”，也不进计划全集。
    expect(result.conflicts, isEmpty);
    expect(result.allSlots, isEmpty);
  });

  test('未结束自选任务的实际区间截到 now，与计划任务并排不遮挡', () {
    final result = TimetableDay.build(
      [flexible('进行中', at(20), null), planned('固定', at(20, 15), 60)],
      day,
      now: at(20, 30),
    );
    final running = result.slots.firstWhere((slot) => slot.id == '进行中');
    expect(running.actual, isTrue);
    expect([running.start, running.end], [20 * 60.0, 20 * 60.0 + 30]);
    // 计划冲突只统计计划时段，不因实际区间而报冲突；
    // 两者时间重叠时各占一列显示，互不遮挡。
    expect(result.conflicts, isEmpty);
    expect(result.slots.every((slot) => slot.columns == 2), isTrue);
  });

  test('时间窗口覆盖内容与现在，半点对齐并保底 2 小时，减少首尾空白', () {
    final result = TimetableDay.build([planned('英语', at(21), 11)], day);
    // 首尾只补阅读上下文，时段之间的分钟比例保持不变。
    final window = timetableWindow(result.slots, nowMinute: 20 * 60 + 6);
    expect([window.start, window.end], [19 * 60.0 + 30, 21 * 60.0 + 30]);
    // 只有上午一小段：窗口向外补齐到 2 小时。
    final morning = TimetableDay.build([planned('晨读', at(9), 30)], day);
    final morningWindow = timetableWindow(morning.slots);
    expect(morningWindow.end - morningWindow.start, 120);
    expect(morningWindow.start % 30, 0);
    // 贴近一天两端时只向另一侧扩，不出界。
    final late = TimetableDay.build([planned('夜读', at(23, 50), 10)], day);
    final lateWindow = timetableWindow(late.slots);
    expect(lateWindow.end, 1440);
    expect(lateWindow.start, 22 * 60.0);
    // 没有任何占位时回退默认窗口。
    expect(timetableWindow(const []), (start: 8 * 60.0, end: 18 * 60.0));
  });

  test('实际区间覆盖的日期参与分组，午夜结束不多占一天', () {
    final detail = flexible('跨日', at(23, 50), at(24, 10));
    expect(timetableDateKeys(detail, at(25)).toSet(), {
      '2026-10-25',
      '2026-10-26',
    });
    final midnight = flexible('午夜结束', at(23, 50), at(24));
    expect(timetableDateKeys(midnight, at(25)).toSet(), {'2026-10-25'});
    final late = flexible('隔日才执行', at(25), at(26));
    expect(timetableDateKeys(late, at(27)).toSet(), {
      '2026-10-25',
      '2026-10-26',
    });
  });

  test('系统回拨时实际区间至少保留到最后一条事实，午夜刚开始也显示', () {
    final running = flexible('运行中', at(20), null);
    final paused = MissionDetail(
      mission: running.mission,
      schedule: running.schedule,
      executionPlan: running.executionPlan,
      events: [
        ...running.events,
        ExecutionEvent(
          id: 'pause',
          missionId: running.mission.id,
          sequence: 2,
          type: ExecutionEventType.pause,
          occurredAt: at(21),
        ),
      ],
    );
    expect(
      TimetableDay.build([paused], day, now: at(20, 30)).slots.single.end,
      1260,
    );
    final midnight = flexible('刚开始', at(0), null);
    expect(
      TimetableDay.build([midnight], day, now: at(0)).slots.single.start,
      0,
    );
  });
}
