import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/goal.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';

void main() {
  late AppDatabase db;
  late DriftGoalRepository repository;
  late GoalService service;
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftGoalRepository(db);
    service = GoalService(repository);
  });
  tearDown(() async {
    await service.dispose();
    await db.close();
  });

  test('整理输入、默认推进；准备对象不写库，提交成功才通知重读', () async {
    var notifications = 0;
    final subscription = service.changes.listen((_) => notifications++);
    addTearDown(subscription.cancel);
    final goal = service.prepareCreation(
      title: '  学 Flutter  ',
      description: '  ',
      why: '  自己写应用  ',
    );
    expect(await repository.findAll(), isEmpty);
    expect(notifications, 0);
    expect(goal.description, isNull);
    await service.create(goal);
    await Future<void>.delayed(Duration.zero);
    final saved = (await repository.findAll()).single;
    expect(saved.id, goal.id);
    expect(saved.title, '学 Flutter');
    expect(saved.why, '自己写应用');
    expect(saved.status, GoalStatus.active);
    expect(saved.createdAt, goal.createdAt);
    expect(saved.createdAt.isUtc, isTrue);
    expect(notifications, 1);
  });

  test('失败和重复请求不增加目标，同编号不同内容不能覆盖', () async {
    expect(() => service.prepareCreation(title: '  '), throwsArgumentError);
    expect(await repository.findAll(), isEmpty);
    final goal = service.prepareCreation(title: '独立开发应用');
    await Future.wait([service.create(goal), service.create(goal)]);
    expect(await repository.findAll(), hasLength(1));
    final conflicting = Goal(
      id: goal.id,
      title: '另一件事',
      status: GoalStatus.active,
      createdAt: goal.createdAt,
      updatedAt: goal.updatedAt,
    );
    await expectLater(service.create(conflicting), throwsStateError);
    expect((await repository.findAll()).single.title, '独立开发应用');
    expect(await repository.findById('不存在'), isNull);
  });

  test('按创建时间稳定排序，默认列表排除放弃但按编号仍可查询', () async {
    for (final id in ['a', 'b', 'c']) {
      final time = DateTime.utc(2026, 10, id == 'a' ? 23 : 24);
      await repository.create(
        Goal(
          id: id,
          title: id,
          status: GoalStatus.active,
          createdAt: time,
          updatedAt: time,
        ),
      );
    }
    expect((await repository.findAll()).map((g) => g.id), ['b', 'c', 'a']);
    await db.customStatement(
      "UPDATE goals SET status = 'DROPPED' WHERE id = 'b'",
    );
    expect((await repository.findAll()).map((g) => g.id), ['c', 'a']);
    expect((await repository.findById('b'))!.status, GoalStatus.dropped);
    await expectLater(
      db.customStatement("UPDATE goals SET status = 'UNKNOWN'"),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement("UPDATE goals SET title = '   '"),
      throwsA(isA<SqliteException>()),
    );
  });

  test('目标文字和四状态由用户保存；放弃隐藏但可找回，节点与既有任务不改写', () async {
    final goal = service.prepareCreation(title: '手动目标', description: '原说明');
    await service.create(goal);
    final missions = MissionService(DriftMissionRepository(db));
    addTearDown(missions.dispose);
    await missions.create(
      title: '既有任务',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 25,
      ownership: MissionOwnership(goalId: goal.id),
    );
    final existingMission = (await missions.findForGoal(goal.id)).single;
    final node = service.prepareNodeCreation(goalId: goal.id, title: '原节点');
    await service.createNode(node);
    await service.updateGoal(
      goal,
      title: '更新后的目标',
      description: '新说明',
      why: '保留原因',
    );
    final edited = (await service.findById(goal.id))!;
    expect(edited.title, '更新后的目标');
    expect(edited.updatedAt.isAfter(goal.updatedAt), isTrue);
    await service.updateGoal(
      goal,
      title: '更新后的目标',
      description: '新说明',
      why: '保留原因',
    );
    expect((await service.findById(goal.id))!.updatedAt, edited.updatedAt);
    await expectLater(
      service.updateGoal(goal, title: '错误覆盖'),
      throwsStateError,
    );

    await service.setGoalStatus(edited, GoalStatus.paused);
    final paused = (await service.findById(goal.id))!;
    expect(paused.status, GoalStatus.paused);
    await expectLater(
      missions.create(
        title: '暂停后新任务',
        scheduledDate: '2026-10-25',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 25,
        ownership: MissionOwnership(goalId: goal.id),
      ),
      throwsArgumentError,
    );
    await service.setGoalStatus(paused, GoalStatus.achieved);
    final achieved = (await service.findById(goal.id))!;
    expect(achieved.status, GoalStatus.achieved);
    await service.setGoalStatus(achieved, GoalStatus.dropped);
    final dropped = (await service.findById(goal.id))!;
    expect(await service.findAll(), isEmpty);
    expect((await service.findDropped()).single.id, goal.id);
    await service.setGoalStatus(achieved, GoalStatus.dropped); // 同一命令重试。
    expect((await service.findById(goal.id))!.updatedAt, dropped.updatedAt);
    await expectLater(
      service.setGoalStatus(paused, GoalStatus.active),
      throwsStateError,
    );
    expect((await service.findNodes(goal.id)).single.id, node.id);
    expect(
      (await missions.findForGoal(goal.id)).single.mission.id,
      existingMission.mission.id,
    );
    await service.setGoalStatus(dropped, GoalStatus.active);
    expect((await service.findAll()).single.status, GoalStatus.active);
    expect(await service.findDropped(), isEmpty);
  });

  test('独立文件关闭重开后目标仍可完整读取', () async {
    await db.close(); // 这个测试改用磁盘连接，先关闭 setUp 准备的内存连接。
    final directory = await Directory.systemTemp.createTemp(
      'missionbook-goals-',
    );
    try {
      final file = File('${directory.path}/goals.sqlite');
      final first = AppDatabase(executor: NativeDatabase(file));
      final firstService = GoalService(DriftGoalRepository(first));
      final goal = firstService.prepareCreation(
        title: '做自己的应用',
        description: '支持离线\n保留记录',
        why: '边做边学',
      );
      try {
        await firstService.create(goal);
      } finally {
        await firstService.dispose();
        await first.close();
      }
      final reopened = AppDatabase(executor: NativeDatabase(file));
      try {
        final saved = await DriftGoalRepository(reopened).findById(goal.id);
        expect(saved!.title, goal.title);
        expect(saved.description, goal.description);
        expect(saved.why, goal.why);
        expect(saved.createdAt, goal.createdAt);
        expect(saved.updatedAt, goal.updatedAt);
      } finally {
        await reopened.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
