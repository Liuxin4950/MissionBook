import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/domain/entities/mission.dart';
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
}) {
  final now = DateTime.utc(2026, 10, 21);
  return ScheduledMission(
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
      plannedDurationMinutes: 25,
      changedAt: now,
    ),
  );
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

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
}
