import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/goal.dart';
import 'package:mission_book/domain/entities/goal_node.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/presentation/goals/list/goals_page.dart';
import 'package:mission_book/presentation/missions/form/mission_form_page.dart';
import 'package:mission_book/presentation/missions/form/mission_ownership_field.dart';

class _UncertainMissionRepository extends DriftMissionRepository {
  _UncertainMissionRepository(super.database);
  bool loseReply = false;
  bool failBefore = false;
  @override
  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  }) async {
    if (failBefore) throw StateError('测试写入前失败');
    await super.create(
      mission: mission,
      initialSchedule: initialSchedule,
      executionPlan: executionPlan,
    );
    if (loseReply) {
      loseReply = false;
      throw StateError('测试提交后丢失响应');
    }
  }
}

void main() {
  late AppDatabase db;
  late GoalService goals;
  late MissionService missions;
  late _UncertainMissionRepository repository;
  late Goal goal;
  late GoalNode parent, node;
  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    goals = GoalService(DriftGoalRepository(db));
    repository = _UncertainMissionRepository(db);
    missions = MissionService(repository);
    goal = goals.prepareCreation(title: '学习 Flutter', why: '独立完成项目');
    await goals.create(goal);
    final root = goals.prepareNodeCreation(goalId: goal.id, title: '界面');
    await goals.createNode(root);
    parent = (await goals.findNodeById(root.id))!;
    final child = goals.prepareNodeCreation(
      goalId: goal.id,
      parentNodeId: root.id,
      title: '布局',
      description: '理解约束',
    );
    await goals.createNode(child);
    node = (await goals.findNodeById(child.id))!;
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<void> open(
    WidgetTester tester, {
    Widget? home,
    double width = 390,
    double scale = 1,
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
        home: home ?? GoalsPage(service: goals, missionService: missions),
      ),
    );
    await tester.pumpAndSettle();
    if (home == null) await tap(tester, 'goal-outline-toggle-${goal.id}');
  }

  Widget routeTo(Widget child) => Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => child)),
        child: const Text('打开表单'),
      ),
    ),
  );
  Future<MissionDetail> create({required String title, String? nodeId}) async {
    final request = missions.prepareCreation(
      title: title,
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
      ownership: MissionOwnership(goalId: goal.id, goalNodeId: nodeId),
      verificationPolicy: VerificationPolicy.optionalEvidence,
    );
    await missions.createPrepared(request);
    return (await missions.findDetail(missionId: request.mission.id))!;
  }

  testWidgets('归属搜索匹配目标和父路径，同名与归档节点不会误选，取消保留原值', (tester) async {
    final other = goals.prepareCreation(title: '阅读计划');
    await goals.create(other);
    final duplicate = goals.prepareNodeCreation(goalId: other.id, title: '布局');
    await goals.createNode(duplicate);
    final archived = goals.prepareNodeCreation(goalId: goal.id, title: '旧布局');
    await goals.createNode(archived);
    await goals.archiveNode(archived.id);
    var selected = const MissionOwnership();
    await open(
      tester,
      width: 320,
      scale: 1.5,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => MissionOwnershipField(
            service: missions,
            value: selected,
            enabled: true,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );
    await tap(tester, 'mission-ownership');
    await tester.enterText(
      find.byKey(const Key('ownership-search')),
      'flutter 布局',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byKey(Key('ownership-node-${node.id}')), findsOneWidget);
    expect(find.byKey(Key('ownership-node-${duplicate.id}')), findsNothing);
    expect(find.byKey(Key('ownership-node-${archived.id}')), findsNothing);
    expect(find.text('学习 Flutter / 界面 / 布局'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byKey(const Key('ownership-search')), '无匹配内容');
    await tester.pumpAndSettle();
    expect(find.textContaining('没有匹配的目标或节点'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭归属选择'));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(selected, const MissionOwnership());
    await tap(tester, 'mission-ownership');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ownership-search')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(find.byKey(const Key('ownership-search')), '独立');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ownership-independent')), findsOneWidget);
    expect(find.textContaining('没有匹配的目标或节点'), findsNothing);
    await tester.enterText(find.byKey(const Key('ownership-search')), '界面 布局');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('ownership-node-${node.id}')));
    await tester.pumpAndSettle();
    expect(selected, MissionOwnership(goalId: goal.id, goalNodeId: node.id));
    expect(tester.takeException(), isNull);
  });

  testWidgets('树线在圆圈中心接入，宽屏、窄屏大字号与任务展开均保持对齐', (tester) async {
    final long = goals.prepareNodeCreation(
      goalId: goal.id,
      parentNodeId: parent.id,
      title: '需要换行显示的子节点名称',
    );
    await goals.createNode(long);
    await create(title: '节点关联任务', nodeId: long.id);
    const captureKey = Key('outline-alignment-capture');

    Future<void> expectConnected() async {
      final marker = find.byKey(Key('node-marker-${long.id}'));
      await tester.ensureVisible(marker);
      await tester.pumpAndSettle();
      final circle = tester.getCenter(marker);
      final trunk = tester.getCenter(
        find.byKey(Key('node-marker-${parent.id}')),
      );
      final origin = tester.getTopLeft(find.byKey(captureKey));
      // 直接取渲染像素：横线应经过圆圈中心高度，向下三像素则回到卡片底色。
      // 这样能检出整行按文字居中、树线却使用另一套高度的回归。
      final x = ((trunk.dx + circle.dx - 10) / 2 - origin.dx).floor();
      final y = (circle.dy - origin.dy).floor();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      final pixels = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final result = (width: image.width, data: data!.buffer.asUint8List());
        image.dispose();
        return result;
      });
      final onLine = (y * pixels!.width + x) * 4;
      final below = ((y + 3) * pixels.width + x) * 4;
      var contrast = 0;
      for (var channel = 0; channel < 3; channel++) {
        contrast +=
            (pixels.data[onLine + channel] - pixels.data[below + channel])
                .abs();
      }
      expect(contrast, greaterThan(12), reason: '树线应落在圆圈的实际中心高度');
    }

    void expectActionsCentered() {
      for (final id in [parent.id, long.id]) {
        final createButton = find.byKey(Key('node-create-mission-$id'));
        final label = find.descendant(
          of: createButton,
          matching: find.text('建任务'),
        );
        final menu = find.descendant(
          of: find.byKey(Key('node-menu-$id')),
          matching: find.byIcon(Icons.more_horiz),
        );
        final header = find.byKey(Key('node-header-$id'));
        final actions = find.byKey(Key('node-actions-$id'));
        expect(
          tester.getCenter(label).dy,
          closeTo(tester.getCenter(menu).dy, .01),
        );
        expect(
          tester.getCenter(actions).dy,
          closeTo(tester.getCenter(header).dy, .01),
        );
      }
    }

    for (final size in [
      (width: 1000.0, scale: 1.0),
      (width: 320.0, scale: 2.0),
    ]) {
      await open(
        tester,
        width: size.width,
        scale: size.scale,
        home: RepaintBoundary(
          key: captureKey,
          child: Scaffold(
            body: GoalsPage(service: goals, missionService: missions),
          ),
        ),
      );
      await tap(tester, 'goal-outline-toggle-${goal.id}');
      await expectConnected();
      if (size.width >= 1000) expectActionsCentered();
      await tap(tester, 'node-tasks-${long.id}');
      await expectConnected();
      if (size.width >= 1000) expectActionsCentered();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('点击节点主体展开子项，任务记录和菜单保持独立', (tester) async {
    await create(title: '父节点任务', nodeId: parent.id);
    await open(tester);
    expect(find.byKey(Key('node-row-${node.id}')), findsOneWidget);
    await tester.tap(find.text('界面'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('node-row-${node.id}')), findsNothing);
    await tester.tap(find.text('界面'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('node-row-${node.id}')), findsOneWidget);
    await tap(tester, 'node-tasks-${parent.id}');
    expect(find.text('父节点任务'), findsOneWidget);
    expect(find.byKey(Key('node-row-${node.id}')), findsOneWidget);
    await tap(tester, 'node-menu-${parent.id}');
    expect(find.text('添加子节点'), findsOneWidget);
    expect(find.byKey(Key('node-row-${node.id}')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.longPress(find.text('界面'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('node-title-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('从节点直接建任务，预填名称说明原因，可以改成独立任务', (tester) async {
    await open(tester);
    await tap(tester, 'node-menu-${node.id}');
    await tap(tester, 'node-create-mission-menu-${node.id}');
    await tap(tester, 'mission-plan-toggle');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mission-title')))
          .controller!
          .text,
      '布局',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mission-objective')))
          .controller!
          .text,
      '布局',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mission-description')))
          .controller!
          .text,
      '理解约束',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mission-why')))
          .controller!
          .text,
      '独立完成项目',
    );
    await tap(tester, 'mission-ownership');
    await tap(tester, 'ownership-independent');
    expect(find.textContaining('原归属目前不可用于新任务'), findsNothing);
    await enter(tester, 'mission-title', '练习布局');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mission-objective')))
          .controller!
          .text,
      '练习布局',
    );
    await enter(tester, 'mission-objective', '只做约束实验');
    await enter(tester, 'mission-title', '调整练习名称');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mission-objective')))
          .controller!
          .text,
      '只做约束实验',
    );
    await enter(tester, 'mission-duration', '20');
    await save(tester);
    expect(find.byType(MissionFormPage), findsNothing);
    final saved = (await db.select(db.missions).get()).single;
    expect(saved.goalId, isNull);
    expect(saved.goalNodeId, isNull);
    expect(saved.description, '理解约束');
    expect(await missions.findForGoal(goal.id), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('普通创建默认独立，开始前可改为仅目标再改为节点', (tester) async {
    await open(
      tester,
      home: routeTo(MissionFormPage(missionService: missions)),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    expect(find.text('独立任务'), findsOneWidget);
    await enter(tester, 'mission-title', '直接创建');
    await enter(tester, 'mission-duration', '15');
    await save(tester);
    var saved = (await db.select(db.missions).get()).single;
    expect(saved.goalId, isNull);
    expect(saved.goalNodeId, isNull);
    await tester.pumpWidget(const SizedBox());
    var detail = (await missions.findDetail(missionId: saved.id))!;
    await open(
      tester,
      home: routeTo(
        MissionFormPage.edit(missionService: missions, detail: detail),
      ),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await tap(tester, 'mission-ownership');
    await tap(tester, 'ownership-goal-${goal.id}');
    await save(tester, label: '保存修改');
    detail = (await missions.findDetail(missionId: saved.id))!;
    expect(detail.mission.goalId, goal.id);
    expect(detail.mission.goalNodeId, isNull);
    await tester.pumpWidget(const SizedBox());
    await open(
      tester,
      home: routeTo(
        MissionFormPage.edit(missionService: missions, detail: detail),
      ),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await tap(tester, 'mission-ownership');
    await tap(tester, 'ownership-node-${node.id}');
    await save(tester, label: '保存修改');
    detail = (await missions.findDetail(missionId: saved.id))!;
    expect(detail.mission.goalNodeId, node.id);
    expect(await db.select(db.missionScheduleRevisions).get(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('节点直接记录标签不继承子节点，完成后新任务不抹掉完成标记', (tester) async {
    var completed = await create(title: '已经报告完成', nodeId: node.id);
    await missions.execute(
      missions.prepareExecution(
        detail: completed,
        type: ExecutionEventType.start,
      ),
    );
    completed = (await missions.findDetail(missionId: completed.mission.id))!;
    await missions.execute(
      missions.prepareExecution(
        detail: completed,
        type: ExecutionEventType.end,
        report: UserReportedResult.completed,
        submitOptionalEvidence: true,
      ),
    );
    final pending = await create(title: '下一次练习', nodeId: node.id);
    await create(title: '目标层任务');
    await open(tester);
    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester
            .getSemantics(find.byKey(Key('goal-record-summary-${goal.id}')))
            .label,
        '有效节点2项，其中1项有直接完成记录，不表示掌握程度',
      );
    } finally {
      semantics.dispose();
    }
    expect(
      find.descendant(
        of: find.byKey(Key('node-row-${parent.id}')),
        matching: find.text('暂无完成记录'),
      ),
      findsOneWidget,
    );
    expect(find.text('有完成记录 · 2'), findsOneWidget);
    expect(find.text('待补材料'), findsOneWidget);
    await tap(tester, 'node-tasks-${node.id}');
    expect(find.text('下一次练习'), findsOneWidget);
    final startEntry = find.descendant(
      of: find.byKey(Key('goal-task-${pending.mission.id}')),
      matching: find.byTooltip('任务详情'),
    );
    await tester.tap(startEntry);
    await tester.pumpAndSettle();
    await tap(tester, 'execution-start');
    expect(find.byKey(const Key('mission-execution-page')), findsOneWidget);
    expect(
      (await missions.findDetail(missionId: pending.mission.id))!.events,
      hasLength(1),
    );
    // 从别处归档不会结束独立执行页，也不会写入暂停事实。
    await goals.archiveNode(parent.id);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-execution-page')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('暂无节点'), findsOneWidget);
    expect(find.byKey(Key('node-create-mission-${node.id}')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('节点任务进入独立执行页，报告返回保护草稿且不保存 END', (tester) async {
    final detail = await create(title: '保护报告', nodeId: node.id);
    await missions.execute(
      missions.prepareExecution(detail: detail, type: ExecutionEventType.start),
    );
    await open(tester);
    await tap(tester, 'node-tasks-${node.id}');
    final entry = find.descendant(
      of: find.byKey(Key('goal-task-${detail.mission.id}')),
      matching: find.byTooltip('返回执行'),
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-execution-page')), findsOneWidget);
    await tap(tester, 'execution-end');
    await tap(tester, 'report-not-completed');
    await enter(tester, 'report-reason', '保留我的原因');
    await goals.archiveNode(parent.id);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('report-reason')))
          .controller!
          .text,
      '保留我的原因',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃本次报告？'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-execution-page')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('report-reason')))
          .controller!
          .text,
      '保留我的原因',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃报告'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-execution-page')), findsOneWidget);
    expect(
      (await missions.findDetail(
        missionId: detail.mission.id,
      ))!.events.where((event) => event.type == ExecutionEventType.end),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('重试原归属已归档时明确提示，选择独立后保存新任务和来源关系', (tester) async {
    final source = await create(title: '旧任务', nodeId: node.id);
    await missions.cancel(missionId: source.mission.id);
    final cancelled = (await missions.findDetail(
      missionId: source.mission.id,
    ))!;
    await goals.archiveNode(parent.id);
    await open(
      tester,
      home: routeTo(
        MissionFormPage.retry(missionService: missions, source: cancelled),
      ),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(find.textContaining('请重新选择有效归属'), findsOneWidget);
    expect(await db.select(db.missions).get(), hasLength(1));
    await tap(tester, 'mission-ownership');
    await tap(tester, 'ownership-independent');
    expect(find.textContaining('原归属目前不可用于新任务'), findsNothing);
    await save(tester);
    final rows = await db.select(db.missions).get();
    expect(rows, hasLength(2));
    final retry = rows.singleWhere((row) => row.id != source.mission.id);
    expect(retry.goalId, isNull);
    expect(retry.sourceMissionId, source.mission.id);
  });

  testWidgets('创建丢失响应后原请求重试不重复，写前失败检查后可继续编辑', (tester) async {
    repository.loseReply = true;
    await open(
      tester,
      home: routeTo(MissionFormPage(missionService: missions)),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await enter(tester, 'mission-title', '不重复');
    await enter(tester, 'mission-duration', '10');
    await save(tester);
    expect(find.text('检查保存结果'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('mission-title'))).enabled,
      isFalse,
    );
    await save(tester);
    expect(await db.select(db.missions).get(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    repository.failBefore = true;
    await open(
      tester,
      home: routeTo(MissionFormPage(missionService: missions)),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await enter(tester, 'mission-title', '失败保留');
    await enter(tester, 'mission-duration', '10');
    await save(tester);
    await tester.tap(find.text('检查保存结果'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('mission-title'))).enabled,
      isTrue,
    );
    await enter(tester, 'mission-title', '修改后保存');
    repository.failBefore = false;
    await save(tester);
    expect(await db.select(db.missions).get(), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('320宽双倍字体下任务归属、选择器与节点建任务没有溢出', (tester) async {
    await open(tester, width: 320, scale: 2);
    await tap(tester, 'node-create-mission-${node.id}');
    await tap(tester, 'mission-ownership');
    await tap(tester, 'ownership-node-${node.id}');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await enter(tester, 'mission-duration', '20');
    expect(tester.takeException(), isNull);
  });
}

Future<void> tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.enterText(target, value);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester, {String label = '创建任务'}) async {
  final target = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  if (find.text('返回原页面').evaluate().isNotEmpty) {
    await tester.tap(find.text('返回原页面'));
    await tester.pumpAndSettle();
  }
}
