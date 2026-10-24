import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/domain/entities/goal.dart';

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
