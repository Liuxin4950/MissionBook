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
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        key == 'all-missions-statistics' ? 300 : -300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
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
    await tap(tester, 'all-missions-all-dates');
    expect(find.byKey(Key('all-mission-$doneId')), findsOneWidget);
    expect(find.byKey(Key('all-mission-$cancelledId')), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('all-mission-$oldId')), findsOneWidget);
    await tap(tester, 'all-missions-statistics');
    expect(find.text('计划 2 项 · 报告完成 1 项'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
    await tester.pumpAndSettle();
    await tap(tester, 'all-missions-phase-cancelled');
    expect(find.byKey(Key('all-mission-$cancelledId')), findsOneWidget);
    expect(find.byKey(Key('all-mission-$doneId')), findsNothing);
    await tap(tester, 'all-missions-phase-all');
    await tap(tester, 'all-missions-past');
    expect(find.byKey(Key('all-mission-$oldId')), findsOneWidget);
    expect(find.byKey(Key('all-mission-$doneId')), findsNothing);
    await tap(tester, 'all-missions-past');
    await tap(tester, 'all-missions-goal-all');
    await tester.tap(find.text('学习目标').last);
    await tester.pumpAndSettle();
    expect(find.byKey(Key('all-mission-$doneId')), findsOneWidget);
    expect(find.byKey(Key('all-mission-$oldId')), findsNothing);
    await tap(tester, 'all-missions-date');
    expect(find.byType(DatePickerDialog), findsOneWidget);
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
    await tap(tester, 'all-missions-all-dates');
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
    expect(a.height, 180);
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
    expect(find.text('10月26日 · 周一'), findsOneWidget);
    expect(find.byKey(Key('all-mission-${english.mission.id}')), findsNothing);
    await tester.tap(find.text('回到今天'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('timetable-slot-${english.mission.id}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
