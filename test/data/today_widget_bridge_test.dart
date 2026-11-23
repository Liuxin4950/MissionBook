import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/notifications/today_widget_bridge.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:timezone/data/latest.dart' as tzdata;

ScheduledMission widgetMission(
  String id, {
  MissionPhase phase = MissionPhase.notStarted,
  DateTime? start,
}) {
  final now = DateTime.utc(2026, 11, 22);
  return ScheduledMission(
    phase: phase,
    mission: Mission(id: id, title: '任务 $id', createdAt: now, updatedAt: now),
    schedule: MissionScheduleRevision(
      id: '$id-schedule',
      missionId: id,
      revisionNumber: 1,
      scheduledDate: '2026-11-23',
      timeZone: 'Asia/Shanghai',
      timePolicy: start == null ? TimePolicy.flexible : TimePolicy.fixed,
      fixedStartAt: start,
      plannedDurationMinutes: 40,
      changedAt: now,
    ),
  );
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('快照按上海日界读取今天和明天，并排除取消任务', () async {
    final calls = <String>[];
    final json = await buildTodayWidgetSnapshot(
      now: DateTime.utc(2026, 11, 22, 16), // Shanghai 2026-11-23 00:00
      query: (date) async {
        calls.add(date);
        return date == '2026-11-23'
            ? [
                widgetMission('a', start: DateTime.utc(2026, 11, 23, 1)),
                widgetMission('b', phase: MissionPhase.cancelled),
              ]
            : [widgetMission('tomorrow')];
      },
    );
    final data = jsonDecode(json) as Map<String, dynamic>;
    expect(calls, ['2026-11-23', '2026-11-24']);
    expect((data['days'] as List).length, 2);
    expect((data['days'][0]['total']), 1);
    expect(data['days'][0]['rows'][0]['start'], '09:00');
    expect(data['days'][1]['total'], 1);
  });

  test('自选任务不伪造固定时间，保留派生阶段文本', () async {
    final json = await buildTodayWidgetSnapshot(
      now: DateTime.utc(2026, 11, 22, 1),
      query: (_) async => [
        widgetMission('x', phase: MissionPhase.reportPending),
      ],
    );
    final row = (jsonDecode(json)['days'][0]['rows'] as List).single;
    expect(row['start'], isNull);
    expect(row['end'], isNull);
    expect(row['phase'], 'reportPending');
  });
}
