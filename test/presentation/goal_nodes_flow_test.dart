import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/domain/entities/goal.dart';
import 'package:mission_book/domain/entities/goal_node.dart';
import 'package:mission_book/presentation/goals/list/goals_page.dart';

// 在真实仓储周围模拟网络式响应不确定和慢保存，验证页面不会重复创建。
class _UncertainNodes extends DriftGoalRepository {
  _UncertainNodes(super.database);
  bool failBefore = false;
  bool loseReply = false;
  int writes = 0;
  Completer<void>? gate;

  @override
  Future<void> createNode(GoalNodeCreation request) async {
    writes++;
    if (gate != null) await gate!.future;
    if (failBefore) throw StateError('测试写入前失败');
    await super.createNode(request);
    if (loseReply) {
      loseReply = false;
      throw StateError('测试已提交但响应丢失');
    }
  }
}

void main() {
  late AppDatabase db;
  late _UncertainNodes repository;
  late GoalService service;
  late Goal goal;
  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = _UncertainNodes(db);
    service = GoalService(repository);
    goal = service.prepareCreation(title: '独立开发 Flutter 应用');
    await service.create(goal);
  });
  tearDown(() async {
    await service.dispose();
    await db.close();
  });

  Future<GoalNode> seed(String title, {String? parent}) async {
    final request = service.prepareNodeCreation(
      goalId: goal.id,
      title: title,
      parentNodeId: parent,
    );
    await service.createNode(request);
    return (await service.findNodeById(request.id))!;
  }

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: GoalsPage(service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'goal-outline-toggle-${goal.id}');
  }

  Future<void> addFromSheet(WidgetTester tester, String title) async {
    await tester.enterText(find.byKey(const Key('node-title-input')), title);
    await tapKey(tester, 'node-save');
  }

  testWidgets('目标卡原位新增父子节点，刷新保留展开，编辑与同级移动可保存', (tester) async {
    await open(tester);
    await tapKey(tester, 'node-add-root-${goal.id}');
    await tapKey(tester, 'node-save');
    expect(find.text('请填写节点名称'), findsOneWidget);
    await addFromSheet(tester, '状态管理');
    final parent = (await service.findNodes(goal.id)).single;
    expect(find.byKey(Key('node-row-${parent.id}')), findsOneWidget);
    await nodeAction(tester, parent.id, '添加子节点');
    expect(find.text('添加到 · 状态管理'), findsOneWidget);
    await addFromSheet(tester, 'Stream');
    final child = (await service.findNodes(
      goal.id,
    )).singleWhere((node) => node.parentNodeId == parent.id);
    expect(find.byKey(Key('node-row-${child.id}')), findsOneWidget);
    await tapKey(tester, 'node-expand-${parent.id}');
    expect(find.byKey(Key('node-row-${child.id}')), findsNothing);
    await tapKey(tester, 'node-expand-${parent.id}');
    await nodeAction(tester, child.id, '编辑名称与说明');
    await tester.enterText(
      find.byKey(const Key('node-title-input')),
      'Stream 事件流',
    );
    await tester.enterText(
      find.byKey(const Key('node-description-input')),
      '通过控制器向页面发送事件',
    );
    await tapKey(tester, 'node-save');
    expect((await service.findNodeById(child.id))!.description, '通过控制器向页面发送事件');
    await tapKey(tester, 'node-add-root-${goal.id}');
    await addFromSheet(tester, '数据存储');
    final sibling = (await service.findNodes(
      goal.id,
    )).singleWhere((node) => node.title == '数据存储');
    await nodeAction(tester, sibling.id, '上移');
    expect(
      (await service.findNodes(
        goal.id,
      )).where((node) => node.parentNodeId == null).map((node) => node.id),
      [sibling.id, parent.id],
    );
    expect(find.text('目标详情'), findsNothing); // 正常维护无需先打开详情页。
    expect(tester.takeException(), isNull);
  });

  testWidgets('归档确认包含子树，默认隐藏；恢复父节点后整树出现，重新进入仍可读', (tester) async {
    final parent = await seed('父节点');
    final child = await seed('子节点', parent: parent.id);
    await open(tester);
    await nodeAction(tester, parent.id, '归档节点及子节点');
    expect(find.textContaining('已有任务和执行历史会保留'), findsOneWidget);
    await tester.tap(find.text('保留节点'));
    await tester.pumpAndSettle();
    expect((await service.findNodeById(parent.id))!.archivedAt, isNull);
    await nodeAction(tester, parent.id, '归档节点及子节点');
    await tester.tap(find.text('归档').last);
    await tester.pumpAndSettle();
    expect(find.byKey(Key('node-row-${parent.id}')), findsNothing);
    expect((await service.findNodeById(child.id))!.archivedAt, isNotNull);
    await tapKey(tester, 'node-show-archived-${goal.id}');
    expect(find.byKey(Key('node-row-${child.id}')), findsOneWidget);
    await tapKey(tester, 'node-menu-${child.id}');
    expect(find.text('请先恢复父节点'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await nodeAction(tester, parent.id, '恢复节点及子节点');
    expect(find.byKey(Key('node-row-${parent.id}')), findsOneWidget);
    expect(find.byKey(Key('node-row-${child.id}')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(find.byKey(Key('node-row-${child.id}')), findsOneWidget);
  });

  testWidgets('目录按树序展示，长按编辑及左滑归档保留确认', (tester) async {
    final parent = await seed('父节点');
    final child = await seed('子节点', parent: parent.id);
    final sibling = await seed('另一个根节点');
    await open(tester, width: 1000);
    expect(find.textContaining('层级'), findsNothing);
    expect(
      tester.getTopLeft(find.text('子节点')).dx,
      greaterThan(tester.getTopLeft(find.text('父节点')).dx),
    );
    expect(
      tester.getTopLeft(find.text('另一个根节点')).dx,
      tester.getTopLeft(find.text('父节点')).dx,
    );
    expect(
      tester.getTopLeft(find.byKey(Key('node-row-${child.id}'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(Key('node-row-${parent.id}'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(Key('node-row-${sibling.id}'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(Key('node-row-${child.id}'))).dy,
      ),
    );
    await tester.longPress(find.text('子节点'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('node-title-input')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(Key('node-row-${child.id}')),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('node-swipe-archive-${child.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已有任务和执行历史会保留'), findsOneWidget);
    await tester.tap(find.text('保留节点'));
    await tester.pumpAndSettle();
    expect((await service.findNodeById(child.id))!.archivedAt, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无任务服务时点击节点标题展开和收起子项', (tester) async {
    final parent = await seed('父节点');
    final child = await seed('子节点', parent: parent.id);
    await open(tester);
    await tester.tap(find.text('父节点'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('node-row-${child.id}')), findsNothing);
    await tester.tap(find.text('父节点'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('node-row-${child.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏左滑后仍可打开归档确认', (tester) async {
    final node = await seed('移动端节点');
    await open(tester, width: 320, scale: 1.2);
    await tester.drag(
      find.byKey(Key('node-row-${node.id}')),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('node-swipe-archive-${node.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已有任务和执行历史会保留'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统返回保护草稿；关闭不保存，保存期间阻止重复点击及离开', (tester) async {
    await open(tester);
    await tapKey(tester, 'node-add-root-${goal.id}');
    await tester.enterText(find.byKey(const Key('node-title-input')), '草稿');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('离开节点编辑？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('草稿'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭节点编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('离开'));
    await tester.pumpAndSettle();
    expect(await service.findNodes(goal.id), isEmpty);
    await tapKey(tester, 'node-add-root-${goal.id}');
    await tester.enterText(find.byKey(const Key('node-title-input')), '慢保存');
    repository.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('node-save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('node-save')));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(repository.writes, 1);
    expect(find.byKey(const Key('node-title-input')), findsOneWidget);
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(await service.findNodes(goal.id), hasLength(1));
    expect(find.byKey(const Key('node-title-input')), findsNothing);
  });

  testWidgets('提交失败保留输入，确认未写入后可编辑；已提交响应丢失重试不重复', (tester) async {
    await open(tester);
    await tapKey(tester, 'node-add-root-${goal.id}');
    repository.failBefore = true;
    await addFromSheet(tester, '未保存');
    expect(find.text('重试保存'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('node-title-input')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isTrue,
    );
    await tester.tap(find.text('确认结果并继续编辑'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('node-title-input')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isFalse,
    );
    repository.failBefore = false;
    repository.loseReply = true;
    await addFromSheet(tester, '原请求');
    expect(await service.findNodes(goal.id), hasLength(1));
    await tapKey(tester, 'node-save');
    expect(await service.findNodes(goal.id), hasLength(1));
    expect(find.byKey(const Key('node-title-input')), findsNothing);
    expect(find.text('原请求'), findsOneWidget);
  });

  testWidgets('详情与卡片共用节点：外部保存后刷新，返回仍保留卡片路径', (tester) async {
    final node = await seed('状态管理');
    await open(tester);
    await tapKey(tester, 'goal-${goal.id}');
    expect(find.text('目标详情'), findsOneWidget);
    await service.updateNode(node, title: '状态管理与事件流');
    await tester.pumpAndSettle();
    expect(find.text('状态管理与事件流').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('node-row-${node.id}')), findsOneWidget);
    expect(find.text('状态管理与事件流'), findsOneWidget);
  });

  testWidgets('详情创建响应丢失，查询确认成功后返回，卡片仍重新读到新节点', (tester) async {
    await open(tester);
    await tapKey(tester, 'goal-${goal.id}');
    await tapKey(tester, 'node-add-root-${goal.id}');
    repository.loseReply = true;
    await addFromSheet(tester, '确认后可见');
    await tester.tap(find.text('确认结果并继续编辑'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('node-title-input')), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('确认后可见'), findsOneWidget);
    expect(await service.findNodes(goal.id), hasLength(1));
  });

  testWidgets('在已归档区添加顶层节点，保存后切回当前路径展示新节点', (tester) async {
    final archived = await seed('旧节点');
    await service.archiveNode(archived.id);
    await open(tester);
    await tapKey(tester, 'node-show-archived-${goal.id}');
    await tapKey(tester, 'node-add-root-${goal.id}');
    await addFromSheet(tester, '新的学习内容');
    expect(find.text('新的学习内容'), findsOneWidget);
    expect(find.byKey(Key('node-row-${archived.id}')), findsNothing);
  });

  testWidgets('编辑期间其他入口改名，保存拒绝覆盖，确认最新记录后才允许继续编辑', (tester) async {
    final node = await seed('原名字');
    await open(tester);
    await nodeAction(tester, node.id, '编辑名称与说明');
    await tester.enterText(find.byKey(const Key('node-title-input')), '我的修改');
    await service.updateNode(node, title: '另一个入口的修改');
    await tester.pumpAndSettle();
    await tapKey(tester, 'node-save');
    expect((await service.findNodeById(node.id))!.title, '另一个入口的修改');
    expect(find.textContaining('节点已在其他入口修改'), findsOneWidget);
    await tester.tap(find.text('确认结果并继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('已读取最新节点，当前输入仍保留，请核对后再保存。'), findsOneWidget);
    await tapKey(tester, 'node-save');
    expect((await service.findNodeById(node.id))!.title, '我的修改');
  });

  testWidgets('320窄屏双倍字体：深层节点及带键盘编辑框可滚动，菜单不溢出', (tester) async {
    String? parent;
    late GoalNode deepest;
    for (var depth = 0; depth < 12; depth++) {
      deepest = await seed('第 $depth 层：较长的学习节点名称与范围说明', parent: parent);
      parent = deepest.id;
    }
    await open(tester, width: 320, scale: 2);
    await tapKey(tester, 'node-menu-${deepest.id}');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('编辑名称与说明'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('node-title-input')), '深层新名称');
    await tapKey(tester, 'node-save');
    expect((await service.findNodeById(deepest.id))!.title, '深层新名称');
    expect(tester.takeException(), isNull);
  });
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle(); // 等滚动后的布局完成，再用新的屏幕坐标点击。
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> nodeAction(WidgetTester tester, String id, String label) async {
  await tapKey(tester, 'node-menu-$id');
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}
