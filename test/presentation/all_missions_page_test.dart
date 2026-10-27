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
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/presentation/missions/all/mission_timetable.dart';
import 'package:mission_book/presentation/missions/all/all_missions_page.dart';
import 'package:mission_book/presentation/today/today_page.dart';

void main() {
  late AppDatabase db;
  late GoalService goals;
  late MissionService missions;
  late DateTime now;
  late String goalId, doneId, oldId, cancelledId;
  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    goals = GoalService(DriftGoalRepository(db));
    now = DateTime.utc(2026, 10, 25, 10);
    missions = MissionService(DriftMissionRepository(db, clock: () => now));
    final goal = goals.prepareCreation(title: '学习目标');
    await goals.create(goal);
    goalId = goal.id;
    Future<String> create(
      String title,
      String day, {
      MissionOwnership ownership = const MissionOwnership(),
    }) async {
      await missions.create(
        title: title,
        scheduledDate: day,
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 20,
        ownership: ownership,
      );
      return (await missions.findScheduledOn(
        scheduledDate: day,
      )).last.mission.id;
    }

    oldId = await create('以前未开始', '2026-10-20');
    doneId = await create(
      '已完成目标任务',
      '2026-10-25',
      ownership: MissionOwnership(goalId: goalId),
    );
    cancelledId = await create('取消的任务', '2026-10-24');
    await missions.cancel(missionId: cancelledId);
    Future<void> act(
      ExecutionEventType type, {
      UserReportedResult? report,
    }) async {
      final detail = (await missions.findDetail(missionId: doneId))!;
      await missions.execute(
        missions.prepareExecution(detail: detail, type: type, report: report),
      );
    }

    await act(ExecutionEventType.start);
    now = now.add(const Duration(minutes: 2));
    await act(ExecutionEventType.pause);
    await act(ExecutionEventType.end, report: UserReportedResult.completed);
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<void> open(
    WidgetTester tester,
    Widget home, {
    double width = 390,
    double height = 844,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, height);
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
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    // 懒加载列表只构建视口附近的行。图表里的横向滚动区位于列表中部，
    // 从列表中心拖动会被它截走手势，所以从列表底部空白处垂直拖动；
    // 目标可能在当前位置上方或下方：先回列表顶部，再向下逐屏构建。
    final dragPoint = Offset(30, tester.view.physicalSize.height - 64);
    if (finder.evaluate().isEmpty) {
      await tester.dragFrom(dragPoint, const Offset(0, 100000));
      await tester.pumpAndSettle();
    }
    for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
      await tester.dragFrom(dragPoint, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
    }
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await scrollTo(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('跨日期六阶段可筛，取消可进入详情，统计分别按计划和 END 日期', (tester) async {
    await open(
      tester,
      AllMissionsPage(
        missions: missions,
        goals: goals,
        clock: () => DateTime(2026, 10, 25),
      ),
    );
    expect(find.text('课表'), findsNothing);
    expect(find.text('列表'), findsNothing);
    await tap(tester, 'all-missions-filters');
    await tap(tester, 'all-missions-date-all-shortcut');
    // 自选任务现在会同时出现在图（timetable-bar-）和列表行（all-mission-）；
    // 这里的“恰好一个”断言只针对列表行。
    await scrollTo(tester, 'all-mission-$doneId');
    expect(find.byKey(Key('all-mission-$doneId')), findsOneWidget);
    await scrollTo(tester, 'all-mission-$cancelledId');
    expect(find.byKey(Key('all-mission-$cancelledId')), findsOneWidget);
    await scrollTo(tester, 'all-mission-$oldId');
    expect(find.byKey(Key('all-mission-$oldId')), findsOneWidget);
    await tap(tester, 'all-missions-statistics');
    expect(find.text('计划 2 项 · 报告完成 1 项'), findsOneWidget);
    await tap(tester, 'all-missions-phase-cancelled');
    await scrollTo(tester, 'all-mission-$cancelledId');
    expect(find.byKey(Key('all-mission-$cancelledId')), findsOneWidget);
    expect(find.byKey(Key('all-mission-$doneId')), findsNothing);
    await tap(tester, 'all-missions-phase-all');
    await tap(tester, 'all-missions-past');
    await scrollTo(tester, 'all-mission-$oldId');
    expect(find.byKey(Key('all-mission-$oldId')), findsOneWidget);
    expect(find.byKey(Key('all-mission-$doneId')), findsNothing);
    await tap(tester, 'all-missions-past');
    await tap(tester, 'all-missions-goal-all');
    await tester.tap(find.text('学习目标').last);
    await tester.pumpAndSettle();
    await scrollTo(tester, 'all-mission-$doneId');
    expect(find.byKey(Key('all-mission-$doneId')), findsOneWidget);
    expect(find.byKey(Key('all-mission-$oldId')), findsNothing);
    await tap(tester, 'all-missions-date');
    expect(find.byKey(const Key('app-date-confirm')), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('今天页的全部任务入口与固定日程查看全部分开', (tester) async {
    await open(
      tester,
      TodayPage(
        missionService: missions,
        goalService: goals,
        clock: () => DateTime.utc(2026, 10, 25, 10),
      ),
    );
    await tap(tester, 'today-all-missions-entry');
    expect(find.byType(AllMissionsPage), findsOneWidget);
    expect(find.text('课表'), findsNothing);
    await tap(tester, 'all-missions-filters');
    await tap(tester, 'all-missions-date-all-shortcut');
    await scrollTo(tester, 'all-mission-$cancelledId');
    expect(find.byKey(Key('all-mission-$cancelledId')), findsOneWidget);
  });

  Future<void> fixed(
    String title,
    int hour,
    int minute,
    int duration, {
    MissionOwnership ownership = const MissionOwnership(),
  }) async {
    await missions.create(
      title: title,
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      timePolicy: TimePolicy.fixed,
      fixedStartAt: DateTime.utc(2026, 10, 25, hour - 8, minute),
      plannedDurationMinutes: duration,
      ownership: ownership,
    );
  }

  testWidgets('日课表比例、冲突详情、筛选隐藏提醒和日期往返', (tester) async {
    await fixed('英语阅读', 10, 30, 90);
    await fixed('项目讨论', 11, 0, 90, ownership: MissionOwnership(goalId: goalId));
    await open(
      tester,
      AllMissionsPage(missions: missions, goals: goals, clock: () => now),
    );
    final details = await missions.findAllDetails();
    final english = details.singleWhere((d) => d.mission.title == '英语阅读');
    final discussion = details.singleWhere((d) => d.mission.title == '项目讨论');
    expect(find.byType(MissionTimetable), findsOneWidget);
    expect(find.text('左右滑动查看并排任务'), findsNothing);
    final a = tester.getRect(
      find.byKey(Key('timetable-slot-${english.mission.id}')),
    );
    final b = tester.getRect(
      find.byKey(Key('timetable-slot-${discussion.mission.id}')),
    );
    expect(a.height, closeTo(180, 0.001));
    expect(b.top - a.top, 60);
    expect(a.right, lessThanOrEqualTo(b.left));
    await tap(tester, 'all-missions-filters');
    await tap(tester, 'all-missions-goal-all');
    await tester.tap(find.text('独立任务').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('timetable-slot-${discussion.mission.id}')),
      findsNothing,
    );
    await tap(tester, 'timetable-conflicts');
    expect(find.text('计划时间冲突'), findsOneWidget);
    expect(find.textContaining('已被筛选隐藏'), findsOneWidget);
    await tester.tap(find.text('项目讨论').last);
    await tester.pumpAndSettle();
    expect(find.text('任务详情'), findsOneWidget);
    await tester.tap(find.byTooltip('返回').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tap(tester, 'timetable-next-day');
    expect(find.text('2026年10月26日 · 周一'), findsOneWidget);
    expect(
      find.byKey(Key('timetable-slot-${english.mission.id}')),
      findsNothing,
    );
    await tap(tester, 'all-missions-back-today');
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('timetable-slot-${english.mission.id}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('日期快捷切换和筛选摘要明确且互不丢失', (tester) async {
    await open(
      tester,
      AllMissionsPage(missions: missions, goals: goals, clock: () => now),
    );
    expect(find.text('计划日期'), findsNothing);
    await tap(tester, 'all-missions-date-all-shortcut');
    expect(find.text('全部日期'), findsNWidgets(2));
    expect(find.byKey(const Key('all-missions-back-today')), findsOneWidget);
    await tap(tester, 'all-missions-filters');
    await tap(tester, 'all-missions-phase-cancelled');
    await tap(tester, 'all-missions-filters');
    expect(find.text('筛选 · 1'), findsOneWidget);
    expect(find.textContaining('筛选：已取消'), findsOneWidget);
    await tap(tester, 'all-missions-back-today');
    expect(find.text('2026年10月25日 · 周日'), findsOneWidget);
    expect(find.textContaining('筛选：已取消'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏大字号可选所有阶段并显示筛选空态', (tester) async {
    await open(
      tester,
      AllMissionsPage(missions: missions, goals: goals, clock: () => now),
      width: 320,
      scale: 2,
    );
    await tap(tester, 'timetable-next-day');
    expect(find.text('这一天没有固定日程。'), findsOneWidget);
    await tap(tester, 'all-missions-filters');
    await tap(tester, 'all-missions-phase-cancelled');
    await scrollTo(tester, 'all-missions-list');
    expect(find.text('这一天没有符合筛选条件的固定日程。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自选任务按实际区间上图，短任务条内显示标题', (tester) async {
    await fixed('五分钟复盘', 9, 15, 5);
    await open(
      tester,
      AllMissionsPage(missions: missions, goals: goals, clock: () => now),
    );
    // setUp 里的“已完成目标任务”是自选任务：实际执行区间画上时间轴。
    expect(find.byKey(Key('timetable-bar-$doneId')), findsOneWidget);
    expect(find.textContaining('实际 '), findsWidgets);
    // 短任务条内直接写“标题 · 时段”，不再是一根认不出的条。
    expect(find.textContaining('五分钟复盘 · '), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('实际区间随时间重绘延伸，相邻短条增高后仍不遮挡', (tester) async {
    await fixed('第一分钟', 18, 15, 1);
    await fixed('第二分钟', 18, 16, 1);
    await missions.execute(
      missions.prepareExecution(
        detail: (await missions.findDetail(missionId: oldId))!,
        type: ExecutionEventType.start,
      ),
    );
    now = now.add(const Duration(minutes: 20));
    await open(tester, AllMissionsPage(missions: missions, clock: () => now));
    final slot = find.byKey(Key('timetable-slot-$oldId'));
    final before = tester.getSize(slot).height;
    now = now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 30));
    expect(tester.getSize(slot).height, before + 20);
    final details = await missions.findAllDetails();
    final first = details.singleWhere((d) => d.mission.title == '第一分钟');
    final second = details.singleWhere((d) => d.mission.title == '第二分钟');
    final a = tester.getRect(
      find.byKey(Key('timetable-slot-${first.mission.id}')),
    );
    final b = tester.getRect(
      find.byKey(Key('timetable-slot-${second.mission.id}')),
    );
    expect(a.overlaps(b), isFalse);
    expect(find.byKey(const Key('timetable-conflicts')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('320窄屏双倍字号，三项冲突和短任务仍可阅读操作', (tester) async {
    await fixed('英语阅读练习与章节总结', 9, 0, 60);
    await fixed('小组项目讨论', 9, 0, 90);
    await fixed('五分钟复盘', 9, 15, 5);
    await open(
      tester,
      AllMissionsPage(missions: missions, goals: goals, clock: () => now),
      width: 320,
      scale: 2,
    );
    expect(find.text('左右滑动查看并排任务'), findsOneWidget);
    await tap(tester, 'all-missions-filters');
    expect(tester.takeException(), isNull);
    await tap(tester, 'timetable-conflicts');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
