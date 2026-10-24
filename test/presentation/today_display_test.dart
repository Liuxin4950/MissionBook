import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:mission_book/presentation/today/today_display.dart';
import 'package:timezone/data/latest.dart' as tzdata;

ScheduledMission mission(
  String id, {
  DateTime? start,
  String timeZone = 'Asia/Shanghai',
  String date = '2026-10-21',
  bool cancelled = false,
  int plannedDurationMinutes = 25,
  MissionPhase phase = MissionPhase.notStarted,
}) {
  final now = DateTime.utc(2026, 10, 21);
  return ScheduledMission(
    phase: phase,
    mission: Mission(
      id: id,
      title: '任务 $id',
      createdAt: now,
      updatedAt: now,
      cancelledAt: cancelled ? now : null,
    ),
    schedule: MissionScheduleRevision(
      id: '$id-schedule',
      missionId: id,
      revisionNumber: 1,
      scheduledDate: date,
      timeZone: timeZone,
      timePolicy: start == null ? TimePolicy.flexible : TimePolicy.fixed,
      fixedStartAt: start,
      plannedDurationMinutes: plannedDurationMinutes,
      changedAt: now,
    ),
  );
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('自选未开始优先，执行中和待补随后，已结束靠后且同阶段稳定', () {
    final source = [
      mission('closed', phase: MissionPhase.closed),
      mission('pending', phase: MissionPhase.evidencePending),
      mission('paused', phase: MissionPhase.paused),
      mission('todo-a'),
      mission('running', phase: MissionPhase.running),
      mission('todo-b'),
    ];
    expect(groupMissionsForDisplay(source).flexible.map((item) => item.id), [
      'todo-a',
      'todo-b',
      'paused',
      'running',
      'pending',
      'closed',
    ]);
    expect(source.first.mission.id, 'closed');
  });

  test('取消优先于固定/自选分区，保留查询顺序且不更改原始结果', () {
    final source = [
      mission('fixed-b', start: DateTime.utc(2026, 10, 21, 1)),
      mission(
        'cancelled-fixed',
        start: DateTime.utc(2026, 10, 21, 2),
        cancelled: true,
      ),
      mission('fixed-a', start: DateTime.utc(2026, 10, 21, 1)),
      mission('flex-b'),
      mission('cancelled-flex', cancelled: true),
      mission('flex-a'),
    ];
    final result = groupMissionsForDisplay(source);
    expect(result.fixed.map((item) => item.id), ['fixed-b', 'fixed-a']);
    expect(result.flexible.map((item) => item.id), ['flex-b', 'flex-a']);
    expect(result.cancelled.map((item) => item.id), [
      'cancelled-fixed',
      'cancelled-flex',
    ]);
    expect(result.cancelled.first.startTime, '10:00');
    expect(result.cancelled.first.durationLabel, '已取消 · 计划 25 分钟');
    expect(result.cancelled.last.startTime, '');
    expect(result.flexible.first.durationLabel, '计划 25 分钟');
    expect(source, hasLength(6));
    expect(source[1].mission.title, '任务 cancelled-fixed');
    expect(() => result.fixed.clear(), throwsUnsupportedError);
  });

  test('固定时间使用排期时区并处理跨日和夏令时；自选不产生固定时刻', () {
    final result = groupMissionsForDisplay([
      mission('shanghai', start: DateTime.utc(2026, 10, 20, 17, 5)),
      mission(
        'new-york-summer',
        start: DateTime.utc(2026, 7, 1, 13, 5),
        timeZone: 'America/New_York',
        date: '2026-07-01',
      ),
      mission(
        'new-york-winter',
        start: DateTime.utc(2026, 12, 1, 14, 5),
        timeZone: 'America/New_York',
        date: '2026-12-01',
      ),
      mission('flexible'),
    ]);
    expect(result.fixed.map((item) => item.startTime), [
      '01:05',
      '09:05',
      '09:05',
    ]);
    expect(result.fixed.first.timeZoneLabel, isNull);
    expect(result.fixed[1].timeZoneLabel, 'America/New_York');
    expect(result.flexible.single.startTime, '');
    expect(result.flexible.single.isFixed, isFalse);
  });

  test('同一天的查询键与页头文字共用日历日期，空结果三个分区均为空', () {
    final selected = DateTime(2026, 1, 4, 23, 59);
    expect(scheduleDateKey(selected), '2026-01-04');
    expect(scheduleDateLabel(selected), '1月4日 · 周日');
    expect(scheduleDateKey(DateTime(1, 1, 2)), '0001-01-02');
    expect(groupMissionsForDisplay([]).isEmpty, isTrue);
  });

  test('计划高亮包含开始、不包含结束；空档、自选和取消不高亮', () {
    final start = DateTime.parse('2026-10-22T09:00:00+08:00');
    final groups = groupMissionsForDisplay([
      mission('fixed', start: start, plannedDurationMinutes: 30),
      mission('flexible'),
      mission('cancelled', start: start, cancelled: true),
    ]);
    final item = groups.fixed.single;
    expect(
      isInPlannedTimeSlot(
        item,
        start.subtract(const Duration(microseconds: 1)),
      ),
      isFalse,
    );
    expect(isInPlannedTimeSlot(item, start), isTrue);
    expect(
      isInPlannedTimeSlot(
        item,
        start.add(const Duration(minutes: 29, seconds: 59)),
      ),
      isTrue,
    );
    expect(
      isInPlannedTimeSlot(item, start.add(const Duration(minutes: 30))),
      isFalse,
    );
    expect(
      isInPlannedTimeSlot(item, start.add(const Duration(hours: 2))),
      isFalse,
    );
    expect(isInPlannedTimeSlot(groups.flexible.single, start), isFalse);
    expect(isInPlannedTimeSlot(groups.cancelled.single, start), isFalse);
  });

  test('重叠时段分别高亮，跨午夜按绝对时刻计算，不受显示时区影响', () {
    final start = DateTime.parse('2026-10-22T23:50:00+08:00');
    final items = groupMissionsForDisplay([
      mission('short', start: start, plannedDurationMinutes: 10),
      mission('long', start: start, plannedDurationMinutes: 30),
    ]).fixed;
    expect(
      items.where(
        (item) =>
            isInPlannedTimeSlot(item, start.add(const Duration(minutes: 5))),
      ),
      hasLength(2),
    );
    final afterMidnight = DateTime.parse('2026-10-23T00:05:00+08:00');
    expect(isInPlannedTimeSlot(items.first, afterMidnight), isFalse);
    expect(isInPlannedTimeSlot(items.last, afterMidnight), isTrue);
    expect(isInPlannedTimeSlot(items.last, afterMidnight.toUtc()), isTrue);
  });

  test('每项轨道的经过比例取自身计划时长，与卡片激活边界一致', () {
    final start = DateTime.utc(2026, 10, 22, 1);
    final items = groupMissionsForDisplay([
      mission('short', start: start, plannedDurationMinutes: 30),
      mission('long', start: start, plannedDurationMinutes: 60),
    ]).fixed;
    expect(
      plannedTimeSlotProgress(
        items.first,
        start.subtract(const Duration(seconds: 1)),
      ),
      0,
    );
    expect(plannedTimeSlotProgress(items.first, start), 0);
    expect(
      plannedTimeSlotProgress(
        items.first,
        start.add(const Duration(minutes: 15)),
      ),
      0.5,
    );
    expect(
      plannedTimeSlotProgress(
        items.last,
        start.add(const Duration(minutes: 15)),
      ),
      0.25,
    );
    final end = start.add(const Duration(minutes: 30));
    expect(plannedTimeSlotProgress(items.first, end), 1);
    expect(isInPlannedTimeSlot(items.first, end), isFalse);
    expect(plannedTimeSlotProgress(items.last, end), 0.5);
    expect(isInPlannedTimeSlot(items.last, end), isTrue);
    expect(
      plannedTimeSlotProgress(items.last, start.add(const Duration(hours: 2))),
      1,
    );
    final flexible = groupMissionsForDisplay([
      mission('flexible'),
    ]).flexible.single;
    expect(plannedTimeSlotProgress(flexible, start), 0);
  });

  test('绿线按节点间真实时间插值，支持相同开始时间、单节点与时钟回拨', () {
    final start = DateTime.utc(2026, 10, 22, 1);
    final end = start.add(const Duration(hours: 5));
    expect(
      timelineSegmentProgress(
        start,
        end,
        start.subtract(const Duration(seconds: 1)),
      ),
      0,
    );
    expect(timelineSegmentProgress(start, end, start), 0);
    expect(
      timelineSegmentProgress(
        start,
        end,
        start.add(const Duration(minutes: 150)),
      ),
      0.5,
    );
    expect(timelineSegmentProgress(start, end, end), 1);
    expect(
      timelineSegmentProgress(start, end, end.add(const Duration(days: 1))),
      1,
    );
    expect(
      timelineSegmentProgress(
        start,
        start,
        start.subtract(const Duration(seconds: 1)),
      ),
      0,
    );
    expect(timelineSegmentProgress(start, start, start), 1);
    expect(
      timelineSegmentProgress(
        start,
        end,
        start.subtract(const Duration(hours: 1)),
      ),
      0,
    );
    expect(
      groupMissionsForDisplay([mission('single', start: start)]).fixed,
      hasLength(1),
    );
  });
}
