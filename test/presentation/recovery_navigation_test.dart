import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_maintenance.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/presentation/goals/outline/goal_outline_section.dart';
import 'package:mission_book/presentation/missions/all/all_missions_page.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_page.dart';
import 'package:mission_book/presentation/missions/execution/mission_execution_page.dart';
import 'package:mission_book/presentation/widgets/detail_pane.dart';

void main() {
  final now = DateTime.utc(2026, 11, 11, 2);
  DateTime clock() => now;
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(db, clock: clock),
      clock: clock,
    );
    goals = GoalService(DriftGoalRepository(db));
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });
  Future<String> create(String title, {bool fixed = false}) async {
    final request = missions.prepareCreation(
      title: title,
      scheduledDate: '2026-11-11',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      timePolicy: fixed ? TimePolicy.fixed : TimePolicy.flexible,
      fixedStartAt: fixed ? now.add(const Duration(hours: 2)) : null,
    );
    await missions.createPrepared(request);
    return request.mission.id;
  }

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: child,
  );
  Future<void> open(WidgetTester tester, DetailPaneController pane) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        DetailPaneScope(
          controller: pane,
          child: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: AllMissionsPage(
                    missions: missions,
                    goals: goals,
                    clock: clock,
                  ),
                ),
                Expanded(child: DetailPaneHost(controller: pane)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('首次 inactive 目录和 inactive 时替换依赖均可构建，激活后正常读取', (tester) async {
    final goal = goals.prepareCreation(title: '目录边界');
    await goals.create(goal);
    for (final withService in [false, true]) {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: GoalOutlineSection(
                service: goals,
                goalId: goal.id,
                goalTitle: goal.title,
                goal: goal,
                missionService: withService ? missions : null,
                active: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: GoalOutlineSection(
              service: goals,
              goalId: goal.id,
              goalTitle: goal.title,
              goal: goal,
              missionService: missions,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('全部任务宽屏可连续选择，执行页沿用注入时钟', (tester) async {
    final first = await create('执行中的第一项');
    final second = await create('可继续选择的第二项');
    await missions.execute(
      missions.prepareExecution(
        detail: (await missions.findDetail(missionId: first))!,
        type: ExecutionEventType.start,
      ),
    );
    final pane = DetailPaneController();
    await open(tester, pane);
    await tester.ensureVisible(find.byKey(Key('all-mission-$first')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('all-mission-$first')));
    await tester.pumpAndSettle();
    expect(find.byType(MissionExecutionPage), findsOneWidget);
    expect(
      tester
          .widget<MissionExecutionPage>(find.byType(MissionExecutionPage))
          .clock,
      same(clock),
    );
    await tester.ensureVisible(find.byKey(Key('all-mission-$second')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('all-mission-$second')));
    await tester.pumpAndSettle();
    expect(pane.entries, hasLength(1));
    expect(
      tester
          .widget<MissionDetailPage>(find.byType(MissionDetailPage))
          .missionId,
      second,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    pane.dispose();
  });
  testWidgets('周表弹层打开后任务被删除，再点击旧条目时提示刷新', (tester) async {
    final id = await create('弹层中的待删除任务', fixed: true);
    final pane = DetailPaneController();
    await open(tester, pane);
    await tester.tap(find.byKey(const Key('week-day-2026-11-11')));
    await tester.pumpAndSettle();
    final proposal = await missions.prepareMaintenance(
      action: MissionMaintenanceAction.delete,
      ids: [id],
    );
    await missions.applyMaintenance(proposal);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '弹层中的待删除任务'));
    await tester.pumpAndSettle();
    expect(find.text('任务已变化，请从最新列表重新选择'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    pane.dispose();
  });
}
