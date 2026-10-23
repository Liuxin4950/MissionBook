import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';

import 'mission_cancellation_test.dart' show seedMission;

void main() {
  group('编辑与改期真实仓储', () {
    late AppDatabase database;
    late DriftMissionRepository repository;
    late MissionService service;
    late MissionDetail original;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = DriftMissionRepository(database);
      service = MissionService(repository);
      await seedMission(repository, 'a');
      await seedMission(repository, 'b');
      original = (await repository.findDetail('a'))!;
    });
    tearDown(() => database.close());

    Future<List<Map<String, Object?>>> rows(String table) async =>
        (await database.customSelect('SELECT * FROM $table ORDER BY id').get())
            .map((row) => row.data)
            .toList();

    Future<List<Object?>> snapshot() async => [
      await rows('missions'),
      await rows('execution_plans'),
      await rows('mission_schedule_revisions'),
    ];

    Future<void> edit({
      MissionDetail? baseline,
      String? title,
      String? objective,
      String date = '2026-10-23',
      int minutes = 20,
      TimePolicy policy = TimePolicy.flexible,
      DateTime? start,
    }) => service.edit(
      original: baseline ?? original,
      title: title ?? original.mission.title,
      objective: objective ?? original.executionPlan.objective,
      scheduledDate: date,
      plannedDurationMinutes: minutes,
      timePolicy: policy,
      fixedStartAt: start,
    );

    test('无改动不写入；纯元数据编辑保留排期、其他字段与其他任务', () async {
      final before = await snapshot();
      await edit();
      expect(await snapshot(), before);
      final oldSchedules = await rows('mission_schedule_revisions');
      final oldOther = await repository.findDetail('b');
      await edit(title: '  新名称  ', objective: '  新目标  ');
      final detail = (await repository.findDetail('a'))!;
      expect(detail.mission.title, '新名称');
      expect(detail.executionPlan.objective, '新目标');
      expect(detail.mission.description, original.mission.description);
      expect(detail.mission.why, original.mission.why);
      expect(detail.mission.createdAt, original.mission.createdAt);
      expect(detail.executionPlan.id, original.executionPlan.id);
      expect(detail.executionPlan.steps, original.executionPlan.steps);
      expect(detail.executionPlan.createdAt, original.executionPlan.createdAt);
      expect(await rows('mission_schedule_revisions'), oldSchedules);
      expect(
        (await repository.findDetail('b'))!.mission.updatedAt,
        oldOther!.mission.updatedAt,
      );
    });

    test('日期与策略改变追加完整版本，旧行原样保留且列表只用最新排期', () async {
      final oldRows = await rows('mission_schedule_revisions');
      final start = DateTime.utc(2026, 10, 24, 8, 30);
      await edit(
        title: '改到明天',
        objective: '新目标',
        date: '2026-10-24',
        minutes: 45,
        policy: TimePolicy.fixed,
        start: start,
      );
      final second = (await repository.findDetail('a'))!;
      expect(second.schedule.revisionNumber, 2);
      expect(second.schedule.fixedStartAt, start);
      expect(second.schedule.timeZone, 'Asia/Shanghai');
      expect(second.schedule.plannedDurationMinutes, 45);
      expect(second.schedule.changedAt, second.mission.updatedAt);
      final history = await rows('mission_schedule_revisions');
      for (final old in oldRows) {
        expect(history.singleWhere((row) => row['id'] == old['id']), old);
      }
      expect(
        (await repository.findScheduledOn(
          '2026-10-23',
        )).map((row) => row.mission.id),
        ['b'],
      );
      expect(
        (await repository.findScheduledOn('2026-10-24')).single.mission.id,
        'a',
      );
      await edit(
        baseline: second,
        title: second.mission.title,
        objective: second.executionPlan.objective,
        date: '2026-10-24',
        minutes: 45,
      );
      final third = (await repository.findDetail('a'))!.schedule;
      expect(third.revisionNumber, 3);
      expect(third.timePolicy, TimePolicy.flexible);
      expect(third.fixedStartAt, isNull);
    });

    test('并发与重复提交同一内容只追加一次，保留首次保存时间', () async {
      await Future.wait([
        edit(title: '同一修改', date: '2026-10-24'),
        edit(title: '同一修改', date: '2026-10-24'),
      ]);
      final after = await snapshot();
      await edit(title: '同一修改', date: '2026-10-24');
      expect(await snapshot(), after);
      expect((await repository.findDetail('a'))!.schedule.revisionNumber, 2);
    });

    test('旧表单不能覆盖新元数据或新排期，包括相同毫秒的修改', () async {
      await edit(title: '另一次修改');
      // 不只靠毫秒时间戳识别冲突，修改值本身也参与比较。
      await database.customStatement(
        'UPDATE missions SET updated_at = ? WHERE id = ?',
        [original.mission.updatedAt.millisecondsSinceEpoch, 'a'],
      );
      final after = await snapshot();
      await expectLater(
        edit(title: '旧表单覆盖'),
        throwsA(isA<MissionEditConflict>()),
      );
      expect(await snapshot(), after);
      final current = (await repository.findDetail('a'))!;
      await edit(baseline: current, date: '2026-10-24');
      final rescheduled = await snapshot();
      await expectLater(
        edit(baseline: current, date: '2026-10-25'),
        throwsA(isA<MissionEditConflict>()),
      );
      expect(await snapshot(), rescheduled);
    });

    test('已取消与任务缺失时拒绝旧表单保存，不产生新排期', () async {
      await repository.cancel('a');
      final cancelled = await snapshot();
      await expectLater(
        edit(title: '不应保存', date: '2026-10-24'),
        throwsA(isA<MissionEditConflict>()),
      );
      expect(await snapshot(), cancelled);
      await database.customStatement(
        'DELETE FROM execution_plans WHERE mission_id = ?',
        ['a'],
      );
      await database.customStatement(
        'DELETE FROM mission_schedule_revisions WHERE mission_id = ?',
        ['a'],
      );
      await database.customStatement('DELETE FROM missions WHERE id = ?', [
        'a',
      ]);
      await expectLater(edit(), throwsA(isA<MissionEditConflict>()));
    });

    test('排期插入失败时元数据和目标一起回滚，原草稿重试可成功', () async {
      final before = await snapshot();
      await database.customStatement('''
        CREATE TRIGGER reject_revision AFTER INSERT ON mission_schedule_revisions
        WHEN NEW.revision_number > 1
        BEGIN SELECT RAISE(ABORT, '模拟改期失败'); END
      ''');
      await expectLater(
        edit(title: '新名称', objective: '新目标', date: '2026-10-24'),
        throwsA(isA<Exception>()),
      );
      expect(await snapshot(), before);
      await database.customStatement('DROP TRIGGER reject_revision');
      await edit(title: '新名称', objective: '新目标', date: '2026-10-24');
      expect((await repository.findDetail('a'))!.schedule.revisionNumber, 2);
    });

    test('编辑沿用创建的日期、时长、固定时间与非空目标校验，错误不写库', () async {
      final before = await snapshot();
      final invalid = <Future<void> Function()>[
        () => edit(title: '  '),
        () => edit(objective: '  '),
        () => edit(minutes: 0),
        () => edit(date: '2026-02-30'),
        () => edit(policy: TimePolicy.fixed),
        () => edit(start: DateTime.utc(2026, 10, 23)),
        () => edit(policy: TimePolicy.fixed, start: DateTime.utc(2026, 10, 24)),
      ];
      for (final operation in invalid) {
        await expectLater(operation(), throwsArgumentError);
        expect(await snapshot(), before);
      }
    });
  });

  test('文件库关闭重开仍保留新内容及全部排期版本', () async {
    final directory = await Directory.systemTemp.createTemp('mission-edit-');
    final file = File('${directory.path}/mission.sqlite');
    try {
      final first = AppDatabase(executor: NativeDatabase(file));
      try {
        final repository = DriftMissionRepository(first);
        await seedMission(repository, 'persistent');
        final original = (await repository.findDetail('persistent'))!;
        await MissionService(repository).edit(
          original: original,
          title: '重开后的任务',
          objective: '重开后的目标',
          scheduledDate: '2026-10-24',
          plannedDurationMinutes: 35,
          timePolicy: TimePolicy.flexible,
        );
      } finally {
        await first.close();
      }
      final second = AppDatabase(executor: NativeDatabase(file));
      try {
        final detail = (await DriftMissionRepository(
          second,
        ).findDetail('persistent'))!;
        expect(detail.mission.title, '重开后的任务');
        expect(detail.executionPlan.objective, '重开后的目标');
        expect(detail.schedule.revisionNumber, 2);
        expect(
          await second.select(second.missionScheduleRevisions).get(),
          hasLength(2),
        );
      } finally {
        await second.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
