import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_outline_parser.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';

const valid = '''{
  "schema":"mission-book.goal-outline","version":1,
  "goal":{"title":" 学 Flutter ","why":"自己完成项目"},
  "nodes":[{"key":"ui","title":"界面","children":[
    {"key":"routes","title":"导航","description":"理解路由"}
  ]},{"key":"data","title":"数据"}]
}''';

void main() {
  test('严格解析、路径错误与大小/层数/数量边界', () {
    final parsed = GoalOutlineParser.parseText(valid);
    expect(parsed.title, '学 Flutter');
    expect(parsed.nodeCount, 3);
    expect(parsed.nodes.first.children.single.title, '导航');
    expect(parsed.nodes.last.key, 'data');
    expect(
      () => GoalOutlineParser.parseText(
        valid.replaceFirst('"version":1', '"version":"1"'),
      ),
      throwsFormatException,
    );
    expect(
      () => GoalOutlineParser.parseText(
        valid.replaceFirst('"key":"data"', '"key":"ui"'),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'path',
          contains('nodes[1].key'),
        ),
      ),
    );
    expect(
      () => GoalOutlineParser.parseText(
        valid.replaceFirst('"title":"数据"', '"status":"ACTIVE","title":"数据"'),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'path',
          contains('nodes[1].status'),
        ),
      ),
    );
    expect(
      () => GoalOutlineParser.parseText(
        valid.replaceFirst('"why":"自己完成项目"', '"why":null'),
      ),
      throwsFormatException,
    );
    expect(
      () => GoalOutlineParser.parseText(
        valid.replaceFirst('"title":"数据"', '"title":3'),
      ),
      throwsFormatException,
    );
    expect(
      () => GoalOutlineParser.parseText(' ' * (GoalOutlineParser.maxBytes + 1)),
      throwsFormatException,
    );
    Object deep(int depth) => depth == 0
        ? {'key': 'leaf', 'title': '末级'}
        : {
            'key': '$depth',
            'title': '层级',
            'children': [deep(depth - 1)],
          };
    expect(
      () => GoalOutlineParser.parseText(
        jsonEncode({
          'schema': 'mission-book.goal-outline',
          'version': 1,
          'goal': {'title': '目标'},
          'nodes': [deep(12)],
        }),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'path',
          contains('children[0]'),
        ),
      ),
    );
    expect(
      () => GoalOutlineParser.parseText(
        jsonEncode({
          'schema': 'mission-book.goal-outline',
          'version': 1,
          'goal': {'title': '目标'},
          'nodes': [
            for (var i = 0; i < 501; i++) {'key': '$i', 'title': '节点'},
          ],
        }),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'path',
          contains('nodes[500]'),
        ),
      ),
    );
  });

  test('导入一次提交全部目标节点，写中失败回滚，同一请求可安全重试', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final service = GoalService(DriftGoalRepository(db));
    addTearDown(() async {
      await service.dispose();
      await db.close();
    });
    final outline = GoalOutlineParser.parseText(valid);
    final request = service.prepareOutlineImport(outline);
    expect(await service.findAll(), isEmpty);
    expect(request.nodes.map((n) => n.id).toSet(), hasLength(3));
    expect(request.nodes.map((n) => n.orderIndex), [0, 0, 1]);
    await db.customStatement(
      "CREATE TRIGGER fail_import BEFORE INSERT ON goal_nodes WHEN NEW.title = '导航' BEGIN SELECT RAISE(ABORT, '模拟导入中断'); END",
    );
    await expectLater(service.importOutline(request), throwsException);
    expect(await service.findAll(), isEmpty);
    expect(await db.select(db.goalNodes).get(), isEmpty);
    await db.customStatement('DROP TRIGGER fail_import');
    await service.importOutline(request);
    await service.importOutline(request);
    final saved = (await service.findAll()).single;
    final nodes = await service.findNodes(saved.id);
    expect(saved.id, request.goal.id);
    expect(nodes, hasLength(3));
    final byId = {for (final node in nodes) node.id: node};
    expect(byId[request.nodes[1].id]!.parentNodeId, request.nodes.first.id);
    expect((await db.customSelect('PRAGMA foreign_key_check').get()), isEmpty);
  });
}
