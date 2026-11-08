import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/goal.dart';
import 'package:mission_book/domain/entities/goal_node.dart';
import 'package:mission_book/domain/entities/record_draft.dart';
import 'package:mission_book/domain/entities/saved_record.dart';
import 'package:mission_book/presentation/goals/detail/goal_detail_page.dart';
import 'package:mission_book/presentation/records/shared/record_scope.dart';
import 'package:mission_book/presentation/records/list/records_page.dart';

class _Records extends DriftRecordRepository {
  _Records(super.db);
  bool fail = false;

  @override
  Future<RecordPage> readRecords({
    String? id,
    String? goalId,
    String? nodeId,
    String? missionId,
    String? date,
    int offset = 0,
    bool content = false,
    int contentOffset = 0,
  }) {
    if (fail) return Future.error(StateError('测试读取失败'));
    return super.readRecords(
      id: id,
      goalId: goalId,
      nodeId: nodeId,
      missionId: missionId,
      date: date,
      offset: offset,
      content: content,
      contentOffset: contentOffset,
    );
  }
}

void main() {
  late AppDatabase db;
  late GoalService goals;
  late MissionService missions;
  late _Records repository;
  late RecordService records;
  late AnalysisService analysis;
  late Goal goal;
  late GoalNode first, second;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    goals = GoalService(DriftGoalRepository(db));
    missions = MissionService(DriftMissionRepository(db));
    repository = _Records(db);
    records = RecordService(repository, missions, missions.attachments);
    analysis = AnalysisService(
      store: DriftAnalysisStore(db),
      mainBusy: () => false,
      model: (p, {imageKey, mime, json = false}) async => '摘要',
    );
    goal = goals.prepareCreation(title: '2026 秋季学期课表');
    await goals.create(goal);
    final a = goals.prepareNodeCreation(goalId: goal.id, title: '安全教育（含入学教育）');
    final b = goals.prepareNodeCreation(goalId: goal.id, title: '马克思主义基本原理');
    await goals.createNode(a);
    await goals.createNode(b);
    first = (await goals.findNodeById(a.id))!;
    second = (await goals.findNodeById(b.id))!;
  });

  tearDown(() async {
    await analysis.dispose();
    await goals.dispose();
    await missions.dispose();
    await db.close();
  });

  Future<void> save(String id, {String? nodeId, String? goalId}) =>
      records.save(
        RecordDraft(
          id: id,
          type: ContentType.text,
          source: ContentSource.user,
          content: '笔记 $id',
        ),
        goalId: goalId,
        nodeId: nodeId,
      );

  Future<void> open(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    Widget? home,
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
        builder: (context, child) => RecordScope(
          service: records,
          analysis: analysis,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home:
            home ??
            GoalDetailPage(
              service: goals,
              missionService: missions,
              goalId: goal.id,
            ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('空目标无记录入口，节点摘要只从三点菜单打开', (tester) async {
    await open(tester);
    expect(find.textContaining('目标记录 ·'), findsNothing);
    expect(find.textContaining('节点记录 ·'), findsNothing);
    expect(find.text('节点摘要'), findsNothing);
    expect(find.text('生成总结'), findsNothing);
    await tap(tester, find.byKey(Key('node-menu-${first.id}')));
    await tap(tester, find.text('节点摘要'));
    expect(
      find.byKey(Key('generate-summary-node-${first.id}')),
      findsOneWidget,
    );
    expect(find.byKey(Key('generate-summary-node-${second.id}')), findsNothing);
    await tap(tester, find.byTooltip('关闭摘要'));
    expect(find.text('节点摘要'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('真实计数和导航同范围，归属变更与删除后入口随事实更新', (tester) async {
    await save('goal-note', goalId: goal.id);
    await save('first-note', nodeId: first.id);
    await save('unrelated');
    await open(tester);
    expect(find.text('目标记录 · 2'), findsOneWidget);
    // 节点记录入口属于节点展开内容；先展开当前节点，再验证入口范围。
    await tap(tester, find.byKey(Key('node-tasks-${first.id}')));
    expect(find.text('节点记录 · 1'), findsOneWidget);
    await tap(tester, find.text('节点记录 · 1'));
    final page = tester.widget<RecordsPage>(find.byType(RecordsPage));
    expect(page.nodeId, first.id);
    expect(page.goalId, goal.id);
    expect(find.text('笔记 first-note'), findsOneWidget);
    expect(find.text('笔记 goal-note'), findsNothing);
    expect(find.text('笔记 unrelated'), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await records.setOwnership('first-note', nodeId: second.id);
    await tester.pumpAndSettle();
    // 归属变化后，重新展开新的节点即可看到记录入口。
    await tap(tester, find.byKey(Key('node-tasks-${second.id}')));
    expect(find.text('节点记录 · 1'), findsOneWidget);
    await records.delete('first-note');
    await records.delete('goal-note');
    await tester.pumpAndSettle();
    expect(find.textContaining('节点记录 ·'), findsNothing);
    expect(find.textContaining('目标记录 ·'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('记录读取失败有明确重试，切换节点不会沿用上一个数量', (tester) async {
    await save('first-note', nodeId: first.id);
    repository.fail = true;
    await open(
      tester,
      home: Scaffold(
        body: RelatedRecordsEntry(goalId: goal.id, nodeId: first.id),
      ),
    );
    expect(find.text('记录读取失败，点击重试'), findsOneWidget);
    repository.fail = false;
    await tap(tester, find.text('记录读取失败，点击重试'));
    expect(find.text('节点记录 · 1'), findsOneWidget);
    await open(
      tester,
      home: Scaffold(
        body: RelatedRecordsEntry(goalId: goal.id, nodeId: second.id),
      ),
    );
    expect(find.textContaining('节点记录 ·'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('320窄屏双倍字体，节点展开和摘要动作无溢出', (tester) async {
    await save('first-note', nodeId: first.id);
    await open(tester, width: 320, scale: 2);
    await tap(tester, find.byKey(Key('node-tasks-${first.id}')));
    await tap(tester, find.byKey(Key('node-menu-${first.id}')));
    await tap(tester, find.text('节点摘要'));
    await tester.ensureVisible(
      find.byKey(Key('generate-summary-node-${first.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('节点记录 · 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('记录空态无分页，宽屏双列与窄屏大字单列使用同一内容', (tester) async {
    await open(tester, home: const RecordsPage());
    expect(find.text('还没有记录'), findsOneWidget);
    expect(find.text('上一页'), findsNothing);
    expect(find.text('下一页'), findsNothing);
    await save('one');
    await save('two');
    await save('three');
    await tester.pumpAndSettle();
    await open(tester, width: 1080, home: const RecordsPage());
    expect(
      tester.getTopLeft(find.text('笔记 three')).dx,
      isNot(tester.getTopLeft(find.text('笔记 two')).dx),
    );
    await open(tester, width: 320, scale: 2, home: const RecordsPage());
    expect(
      tester.getTopLeft(find.text('笔记 three')).dx,
      tester.getTopLeft(find.text('笔记 two')).dx,
    );
    expect(find.text('上一页'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
