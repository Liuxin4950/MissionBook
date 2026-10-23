import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';

Future<void> seedMission(DriftMissionRepository repository, String id) {
  final now = DateTime.utc(2026, 10, 20);
  return repository.create(
    mission: Mission(
      id: id,
      title: '任务 $id',
      description: '保留原来的任务说明',
      why: '验证取消事实',
      createdAt: now,
      updatedAt: now,
    ),
    initialSchedule: MissionScheduleRevision(
      id: '$id-1',
      missionId: id,
      revisionNumber: 1,
      scheduledDate: '2026-10-23',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
      changedAt: now,
    ),
    executionPlan: ExecutionPlan(
      id: '$id-plan',
      missionId: id,
      objective: '原方案不会丢失',
      steps: const ['第一步', '第二步'],
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  group('取消任务真实仓储', () {
    late AppDatabase database;
    late DriftMissionRepository repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = DriftMissionRepository(database);
    });
    tearDown(() => database.close());

    Future<List<Map<String, Object?>>> rows(String table) async {
      final result = await database
          .customSelect('SELECT * FROM $table ORDER BY id')
          .get();
      return result.map((row) => row.data).toList();
    }

    test('业务入口取消后只修改两个时间字段，保留全部排期历史、方案和其他任务', () async {
      await seedMission(repository, 'a');
      await seedMission(repository, 'b');
      final changedAt = DateTime.utc(2026, 10, 21);
      await database
          .into(database.missionScheduleRevisions)
          .insert(
            scheduleToCompanion(
              MissionScheduleRevision(
                id: 'a-2',
                missionId: 'a',
                revisionNumber: 2,
                scheduledDate: '2026-10-24',
                timeZone: 'Asia/Shanghai',
                plannedDurationMinutes: 35,
                changeReason: '保留旧排期',
                changedAt: changedAt,
              ),
            ),
          );
      final beforeMissions = await rows('missions');
      final beforeSchedules = await rows('mission_schedule_revisions');
      final beforePlans = await rows('execution_plans');
      await MissionService(repository).cancel(missionId: 'a');
      final afterMissions = await rows('missions');
      final cancelled = afterMissions.singleWhere((row) => row['id'] == 'a');
      expect(cancelled['cancelled_at'], isNotNull);
      expect(cancelled['updated_at'], cancelled['cancelled_at']);
      final expected = beforeMissions
          .map((row) => Map<String, Object?>.of(row))
          .toList();
      expected.first['cancelled_at'] = cancelled['cancelled_at'];
      expected.first['updated_at'] = cancelled['updated_at'];
      expect(afterMissions, expected);
      expect(await rows('mission_schedule_revisions'), beforeSchedules);
      expect(await rows('execution_plans'), beforePlans);
      final detail = await repository.findDetail('a');
      expect(detail!.mission.cancelledAt!.isUtc, isTrue);
      expect(detail.schedule.revisionNumber, 2);
      final list = await repository.findScheduledOn('2026-10-24');
      expect(list.single.mission.cancelledAt, detail.mission.cancelledAt);
    });

    test('并发和后续重复请求保留第一次取消时间', () async {
      await seedMission(repository, 'a');
      await Future.wait([repository.cancel('a'), repository.cancel('a')]);
      final first = await rows('missions');
      await repository.cancel('a');
      expect(await rows('missions'), first);
    });

    test('空编号和不存在的任务明确报错，不修改已有任务', () async {
      await seedMission(repository, 'a');
      final before = await rows('missions');
      await expectLater(
        MissionService(repository).cancel(missionId: '  '),
        throwsArgumentError,
      );
      await expectLater(repository.cancel(''), throwsArgumentError);
      await expectLater(repository.cancel('missing'), throwsStateError);
      expect(await rows('missions'), before);
    });

    test('数据库写入失败回滚，解除失败条件后可重试', () async {
      await seedMission(repository, 'a');
      final before = await rows('missions');
      await database.customStatement('''
        CREATE TRIGGER reject_cancellation AFTER UPDATE OF cancelled_at ON missions
        BEGIN SELECT RAISE(ABORT, '模拟取消失败'); END
      ''');
      await expectLater(repository.cancel('a'), throwsA(isA<Exception>()));
      expect(await rows('missions'), before);
      await database.customStatement('DROP TRIGGER reject_cancellation');
      await repository.cancel('a');
      expect(
        (await repository.findDetail('a'))!.mission.cancelledAt,
        isNotNull,
      );
    });
  });

  test('文件数据库关闭重开后，取消时间与原任务关联仍可读回', () async {
    final directory = await Directory.systemTemp.createTemp('mission-cancel-');
    final file = File('${directory.path}/mission.sqlite');
    try {
      final first = AppDatabase(executor: NativeDatabase(file));
      DateTime? cancelledAt;
      try {
        final repository = DriftMissionRepository(first);
        await seedMission(repository, 'persistent');
        await repository.cancel('persistent');
        cancelledAt = (await repository.findDetail(
          'persistent',
        ))!.mission.cancelledAt;
      } finally {
        await first.close();
      }
      final second = AppDatabase(executor: NativeDatabase(file));
      try {
        final detail = await DriftMissionRepository(
          second,
        ).findDetail('persistent');
        expect(detail!.mission.cancelledAt, cancelledAt);
        expect(detail.schedule.id, 'persistent-1');
        expect(detail.executionPlan.steps, ['第一步', '第二步']);
      } finally {
        await second.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
