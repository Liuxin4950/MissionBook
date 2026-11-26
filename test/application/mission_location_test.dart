import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_assistant_reader.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/rules/mission_location_rules.dart';

void main() {
  late AppDatabase db;
  late MissionService service;
  final now = DateTime.utc(2026, 11, 26);
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    service = MissionService(DriftMissionRepository(db), clock: () => now);
  });
  tearDown(() async {
    await service.dispose();
    await db.close();
  });

  Future<MissionDetail> create({String? location, bool fixed = false}) async {
    final request = service.prepareCreation(
      title: '数据库原理',
      scheduledDate: '2026-11-27',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 90,
      location: location,
      timePolicy: fixed ? TimePolicy.fixed : TimePolicy.flexible,
      fixedStartAt: fixed ? DateTime.utc(2026, 11, 27, 0) : null,
    );
    await service.createPrepared(request);
    return (await service.findDetail(missionId: request.mission.id))!;
  }

  Future<void> edit(
    MissionDetail original, {
    String? location,
    bool updateLocation = false,
    String? date,
  }) => service.edit(
    original: original,
    title: original.mission.title,
    objective: original.executionPlan.objective,
    scheduledDate: date ?? original.schedule.scheduledDate,
    plannedDurationMinutes: original.schedule.plannedDurationMinutes,
    timePolicy: original.schedule.timePolicy,
    fixedStartAt: original.schedule.fixedStartAt,
    location: location,
    updateLocation: updateLocation,
  );

  test('地点独立于固定和自选排期，统一空白和长度约束', () async {
    for (final fixed in [false, true]) {
      final detail = await create(location: '  二教\n A203  ', fixed: fixed);
      expect(detail.mission.location, '二教 A203');
      expect(
        detail.schedule.timePolicy,
        fixed ? TimePolicy.fixed : TimePolicy.flexible,
      );
    }
    expect((await create(location: ' \n ')).mission.location, isNull);
    expect(
      normalizeMissionLocation(List.filled(200, '😀').join())!.runes.length,
      200,
    );
    expect(
      () => normalizeMissionLocation(List.filled(201, '中').join()),
      throwsArgumentError,
    );
  });

  test('替换和清空地点不生成排期版本，省略及单独改期保留地点', () async {
    var detail = await create(location: '二教 A203');
    final scheduleId = detail.schedule.id;
    await edit(detail, location: ' 图书馆 ', updateLocation: true);
    detail = (await service.findDetail(missionId: detail.mission.id))!;
    expect(detail.mission.location, '图书馆');
    expect(detail.schedule.id, scheduleId);
    await edit(detail, date: '2026-11-28');
    detail = (await service.findDetail(missionId: detail.mission.id))!;
    expect(detail.mission.location, '图书馆');
    expect(detail.schedule.revisionNumber, 2);
    await edit(detail, location: '  ', updateLocation: true);
    detail = (await service.findDetail(missionId: detail.mission.id))!;
    expect(detail.mission.location, isNull);
    expect(detail.schedule.revisionNumber, 2);
  });

  test('旧快照不能覆盖已修改地点，同一编辑身份重试幂等', () async {
    final original = await create(location: '二教 A203');
    Future<void> save() => service.edit(
      original: original,
      title: original.mission.title,
      objective: original.executionPlan.objective,
      scheduledDate: original.schedule.scheduledDate,
      plannedDurationMinutes: 90,
      timePolicy: TimePolicy.flexible,
      location: '图书馆',
      updateLocation: true,
      operationId: 'location-edit',
    );
    await save();
    await save();
    await expectLater(
      edit(original, location: '操场', updateLocation: true),
      throwsA(isA<MissionEditConflict>()),
    );
    expect(
      (await service.findDetail(
        missionId: original.mission.id,
      ))!.mission.location,
      '图书馆',
    );
  });

  test('再次尝试默认继承地点，明确空串可清空', () async {
    final original = await create(location: '二教 A203');
    await service.cancel(missionId: original.mission.id);
    final source = (await service.findDetail(missionId: original.mission.id))!;
    for (final location in <String?>[null, '', '图书馆']) {
      final retry = service.prepareCreation(
        title: '再次准备',
        scheduledDate: '2026-11-28',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 30,
        retrySource: source,
        location: location,
      );
      await service.createPrepared(retry);
      final saved = (await service.findDetail(missionId: retry.mission.id))!;
      expect(
        saved.mission.location,
        location == null
            ? '二教 A203'
            : location.isEmpty
            ? null
            : location,
      );
    }
  });

  test('任务详情、渐进读取和日程查询直接返回地点', () async {
    final detail = await create(location: '二教 A203');
    final reader = DriftUnifiedReader(db);
    final mission = await reader.getMission(mission: detail.mission.id);
    expect(mission['location'], '二教 A203');
    final schedule = await reader.getSchedule(
      date: detail.schedule.scheduledDate,
    );
    expect((schedule['items'] as List).single['location'], '二教 A203');
    final content = await DriftAssistantReader(
      db,
    ).content(detail.mission.id, 'location');
    expect(content['text'], '二教 A203');
    expect(
      (await service.findScheduledOn(
        scheduledDate: detail.schedule.scheduledDate,
      )).single.mission.location,
      '二教 A203',
    );
  });

  test('文件数据库关闭重开后保留地点', () async {
    final dir = await Directory.systemTemp.createTemp('mission-location-');
    final file = File('${dir.path}/db.sqlite');
    final disk = AppDatabase(executor: NativeDatabase(file));
    final missions = MissionService(DriftMissionRepository(disk));
    try {
      await missions.create(
        title: '线下活动',
        scheduledDate: '2026-11-27',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 30,
        location: '活动中心',
      );
    } finally {
      await missions.dispose();
      await disk.close();
    }
    final reopened = AppDatabase(executor: NativeDatabase(file));
    try {
      expect(
        (await DriftMissionRepository(
          reopened,
        ).findAllDetails()).single.mission.location,
        '活动中心',
      );
    } finally {
      await reopened.close();
      await dir.delete(recursive: true);
    }
  });
}
