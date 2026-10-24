import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/domain/entities/goal_node.dart';

void main() {
  late AppDatabase db;
  late DriftGoalRepository repository;
  late GoalService service;
  late String goalId;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftGoalRepository(db);
    service = GoalService(repository);
    final goal = service.prepareCreation(title: '独立开发 Flutter 应用');
    await service.create(goal);
    goalId = goal.id;
  });
  tearDown(() async {
    await service.dispose();
    await db.close();
  });

  Future<GoalNode> add(String title, {String? parent, String? goal}) async {
    final request = service.prepareNodeCreation(
      goalId: goal ?? goalId,
      parentNodeId: parent,
      title: title,
    );
    await service.createNode(request);
    return (await service.findNodeById(request.id))!;
  }

  test('创建请求不写库；顶层与子节点分别排序，文字整理后保存，成功才通知', () async {
    var notifications = 0;
    final subscription = service.changes.listen((_) => notifications++);
    addTearDown(subscription.cancel);
    final request = service.prepareNodeCreation(
      goalId: goalId,
      title: '  状态管理  ',
      description: '  从事件到页面刷新  ',
    );
    expect(await service.findNodes(goalId), isEmpty);
    expect(notifications, 0);
    await service.createNode(request);
    final child = await add('Stream', parent: request.id);
    final sibling = await add('数据库');
    await Future<void>.delayed(Duration.zero);
    final parent = (await service.findNodeById(request.id))!;
    expect(parent.title, '状态管理');
    expect(parent.description, '从事件到页面刷新');
    expect(parent.createdAt, request.createdAt);
    expect(parent.updatedAt, request.createdAt);
    expect(parent.createdAt.isUtc, isTrue);
    expect(parent.orderIndex, 0);
    expect(child.parentNodeId, parent.id);
    expect(child.orderIndex, 0);
    expect(sibling.orderIndex, 1);
    expect(notifications, 3);
  });

  test('并发新增分配连续同级序号，同请求重试不重复，同编号冲突不覆盖', () async {
    final request = service.prepareNodeCreation(goalId: goalId, title: '同一节点');
    await Future.wait([
      service.createNode(request),
      service.createNode(request),
    ]);
    await Future.wait([for (var i = 0; i < 8; i++) add('节点 $i')]);
    final nodes = await service.findNodes(goalId);
    expect(nodes, hasLength(9));
    expect(nodes.map((node) => node.orderIndex), List.generate(9, (i) => i));
    await expectLater(
      service.createNode(
        GoalNodeCreation(
          id: request.id,
          goalId: goalId,
          title: '试图覆盖',
          createdAt: request.createdAt,
        ),
      ),
      throwsStateError,
    );
    await service.archiveNode(request.id);
    await service.createNode(request);
    expect((await service.findNodeById(request.id))!.archivedAt, isNotNull);
    expect(await service.findNodes(goalId), hasLength(9));
  });

  test('拒绝不存在、跨目标、归档父节点及自指；数据库组合外键也保护归属', () async {
    final parent = await add('父节点');
    final other = service.prepareCreation(title: '另一个目标');
    await service.create(other);
    for (final request in [
      service.prepareNodeCreation(goalId: '不存在', title: '非法'),
      service.prepareNodeCreation(
        goalId: goalId,
        parentNodeId: '不存在',
        title: '非法',
      ),
      service.prepareNodeCreation(
        goalId: other.id,
        parentNodeId: parent.id,
        title: '非法',
      ),
    ]) {
      await expectLater(service.createNode(request), throwsStateError);
    }
    final self = GoalNodeCreation(
      id: 'self',
      goalId: goalId,
      parentNodeId: 'self',
      title: '自己',
      createdAt: DateTime.utc(2026),
    );
    await expectLater(service.createNode(self), throwsArgumentError);
    await expectLater(
      db.customStatement(
        'INSERT INTO goal_nodes (id, goal_id, parent_node_id, title, order_index, created_at, updated_at) VALUES (?, ?, ?, ?, 0, 0, 0)',
        ['bad-cross-goal', other.id, parent.id, '不能跨目标'],
      ),
      throwsA(isA<SqliteException>()),
    );
    await service.archiveNode(parent.id);
    await expectLater(add('不能挂到归档父节点', parent: parent.id), throwsStateError);
    expect(await service.findNodes(goalId), hasLength(1));
    expect(await service.findNodes(other.id), isEmpty);
  });

  test('编辑保留排序，重复请求可确认成功；过期文字不能覆盖其他入口的新内容', () async {
    final first = await add('旧名字');
    final second = await add('第二个');
    await service.moveNode(
      second,
      siblings: await service.findNodes(goalId),
      upward: true,
    );
    await service.updateNode(first, title: '  新名字  ', description: '  内容  ');
    final edited = (await service.findNodeById(first.id))!;
    expect(edited.orderIndex, 1);
    expect(edited.description, '内容');
    await service.updateNode(first, title: '新名字', description: '内容');
    expect((await service.findNodeById(first.id))!.updatedAt, edited.updatedAt);
    await expectLater(
      service.updateNode(first, title: '旧页面想覆盖'),
      throwsStateError,
    );
    expect((await service.findNodeById(first.id))!.title, '新名字');
    await service.archiveNode(first.id);
    await expectLater(
      service.updateNode(edited, title: '归档后不能改'),
      throwsStateError,
    );
  });

  test('移动跳过归档项但保留它的存储位置，归档恢复不重新编号', () async {
    final a = await add('A');
    final hidden = await add('归档项');
    final b = await add('B');
    await service.archiveNode(hidden.id);
    final siblings = await service.findNodes(goalId);
    await service.moveNode(b, siblings: siblings, upward: true);
    final moved = await service.findNodes(goalId);
    expect(moved.map((node) => node.id), [b.id, hidden.id, a.id]);
    expect(moved.map((node) => node.orderIndex), [0, 1, 2]);
    await service.restoreNode(hidden.id);
    expect((await service.findNodes(goalId)).map((node) => node.id), [
      b.id,
      hidden.id,
      a.id,
    ]);
    final extra = await add('新增');
    expect(extra.orderIndex, 3);
  });

  test('调序检查完整旧顺序，响应丢失后重试不二次移动，新节点使旧顺序失效', () async {
    final a = await add('A');
    final b = await add('B');
    Future<void> move() => repository.reorderNodes(
      goalId: goalId,
      parentNodeId: null,
      expectedIds: [a.id, b.id],
      orderedIds: [b.id, a.id],
    );
    await move();
    await move();
    final c = await add('C');
    await expectLater(move(), throwsStateError);
    expect((await service.findNodes(goalId)).map((node) => node.id), [
      b.id,
      a.id,
      c.id,
    ]);
    await expectLater(
      repository.reorderNodes(
        goalId: goalId,
        parentNodeId: null,
        expectedIds: [b.id, a.id, c.id],
        orderedIds: [b.id, a.id, a.id],
      ),
      throwsArgumentError,
    );
  });

  test('调序中途写失败整组回滚，不发成功通知', () async {
    final a = await add('A');
    final b = await add('B');
    var notifications = 0;
    final subscription = service.changes.listen((_) => notifications++);
    addTearDown(subscription.cancel);
    await db.customStatement(
      "CREATE TRIGGER fail_reorder BEFORE UPDATE OF order_index ON goal_nodes WHEN OLD.id = '${a.id}' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      service.moveNode(
        b,
        siblings: await service.findNodes(goalId),
        upward: true,
      ),
      throwsA(isA<SqliteException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 0);
    final unchanged = await service.findNodes(goalId);
    expect(unchanged.map((node) => node.id), [a.id, b.id]);
    expect(unchanged.map((node) => node.orderIndex), [0, 1]);
  });

  test('整棵子树原子归档与恢复，父节点归档时不能单独恢复子节点', () async {
    final parent = await add('父节点');
    final child = await add('子节点', parent: parent.id);
    final grandchild = await add('孙节点', parent: child.id);
    final sibling = await add('另一个顶层');
    final before = await service.findNodes(goalId);
    await service.archiveNode(parent.id);
    final archived = await service.findNodes(goalId);
    final subtree = archived.where((node) => node.id != sibling.id).toList();
    expect(subtree.every((node) => node.archivedAt != null), isTrue);
    expect(subtree.map((node) => node.archivedAt).toSet(), hasLength(1));
    expect((await service.findNodeById(sibling.id))!.archivedAt, isNull);
    await expectLater(service.restoreNode(child.id), throwsStateError);
    await expectLater(service.restoreNode(grandchild.id), throwsStateError);
    await service.archiveNode(parent.id);
    expect(
      (await service.findNodeById(parent.id))!.archivedAt,
      subtree.first.archivedAt,
    );
    await service.restoreNode(parent.id);
    final restored = await service.findNodes(goalId);
    expect(restored.every((node) => node.archivedAt == null), isTrue);
    expect(
      restored.map((node) => '${node.id}:${node.orderIndex}'),
      before.map((node) => '${node.id}:${node.orderIndex}'),
    );
  });

  test('归档子树中途失败全部回滚，原节点仍可编辑和新增', () async {
    final parent = await add('父节点');
    final child = await add('子节点', parent: parent.id);
    await db.customStatement(
      "CREATE TRIGGER fail_archive BEFORE UPDATE OF archived_at ON goal_nodes WHEN OLD.id = '${child.id}' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      service.archiveNode(parent.id),
      throwsA(isA<SqliteException>()),
    );
    expect(
      (await service.findNodes(
        goalId,
      )).every((node) => node.archivedAt == null),
      isTrue,
    );
    await add('仍可新增', parent: parent.id);
    await service.updateNode(parent, title: '仍可编辑');
  });

  test('损坏的循环或不连续顺序明确失败，不把丢失的分支当作空路径', () async {
    final parent = await add('父节点');
    final child = await add('子节点', parent: parent.id);
    await db.customStatement(
      'UPDATE goal_nodes SET parent_node_id = ? WHERE id = ?',
      [child.id, parent.id],
    );
    await expectLater(service.findNodes(goalId), throwsStateError);
    await db.customStatement(
      'UPDATE goal_nodes SET parent_node_id = NULL, order_index = 3 WHERE id = ?',
      [parent.id],
    );
    await expectLater(service.findNodes(goalId), throwsStateError);
  });

  test('真实文件关闭重开，归属、文字、顺序与归档时刻逐字段保留', () async {
    await db.close(); // 本例改用独立磁盘连接，先关闭 setUp 的内存库。
    final directory = await Directory.systemTemp.createTemp(
      'missionbook-nodes-',
    );
    final file = File('${directory.path}/test.sqlite');
    final disk = AppDatabase(executor: NativeDatabase(file));
    final writer = GoalService(DriftGoalRepository(disk));
    late List<Map<String, Object?>> before;
    final goal = writer.prepareCreation(title: '磁盘目标');
    try {
      await writer.create(goal);
      final parent = writer.prepareNodeCreation(
        goalId: goal.id,
        title: '父节点',
        description: '保留说明\n及换行',
      );
      await writer.createNode(parent);
      final child = writer.prepareNodeCreation(
        goalId: goal.id,
        parentNodeId: parent.id,
        title: '子节点',
      );
      await writer.createNode(child);
      await writer.archiveNode(parent.id);
      before = [
        for (final row
            in await disk
                .customSelect('SELECT * FROM goal_nodes ORDER BY id')
                .get())
          row.data,
      ];
    } finally {
      await writer.dispose();
      await disk.close();
    }
    final reopened = AppDatabase(executor: NativeDatabase(file));
    try {
      final after = [
        for (final row
            in await reopened
                .customSelect('SELECT * FROM goal_nodes ORDER BY id')
                .get())
          row.data,
      ];
      expect(after, before);
      final saved = await DriftGoalRepository(reopened).findNodes(goal.id);
      expect(saved, hasLength(2));
      expect(saved.every((node) => node.archivedAt != null), isTrue);
      expect(
        await reopened.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      await reopened.close();
      await directory.delete(recursive: true);
    }
  });
}
