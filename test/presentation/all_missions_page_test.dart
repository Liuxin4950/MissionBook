import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:mission_book/presentation/missions/all/mission_week_timetable.dart';
import 'package:mission_book/presentation/missions/all/all_missions_page.dart';
import 'package:mission_book/presentation/today/today_page.dart';

const _captureDir = String.fromEnvironment('UI_CAPTURE_DIR');
final _screen = GlobalKey();

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDir.isEmpty) return;
  final boundary =
      _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(_captureDir).create(recursive: true);
    await File(
      '$_captureDir/$name.png',
    ).writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (_captureDir.isEmpty) return;
    final font = FontLoader('UiPreview');
    font.addFont(
      File(
        '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      ).readAsBytes().then(ByteData.sublistView),
    );
    await font.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
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
      RepaintBoundary(
        key: _screen,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _captureDir.isEmpty
              ? AppTheme.light
              : AppTheme.light.copyWith(
                  textTheme: AppTheme.light.textTheme.apply(
                    fontFamily: 'UiPreview',
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: AppTheme.light.textButtonTheme.style?.copyWith(
                      textStyle: WidgetStatePropertyAll(
                        AppTheme.light.textTheme.labelSmall?.copyWith(
                          fontFamily: 'UiPreview',
                        ),
                      ),
                    ),
                  ),
                ),
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

  Future<void> scrollListToTop(WidgetTester tester) async {
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('all-missions-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollable.position.jumpTo(scrollable.position.minScrollExtent);
    await tester.pumpAndSettle();
  }

  Future<void> chooseFilterOption(
    WidgetTester tester,
    String label,
    String option,
  ) async {
    await scrollListToTop(tester);
    final dropdown = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<dynamic> &&
          widget.decoration.labelText == label,
    );
    expect(dropdown, findsOneWidget);
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    final optionFinder = find.text(option).last;
    await tester.ensureVisible(optionFinder);
    await tester.pumpAndSettle();
    await tester.tap(optionFinder);
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
    await chooseFilterOption(tester, '日期范围', '全部日期');
    expect(find.text('全部日期'), findsOneWidget);
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
    await chooseFilterOption(tester, '任务阶段', '已取消');
    await scrollTo(tester, 'all-mission-$cancelledId');
    expect(find.byKey(Key('all-mission-$cancelledId')), findsOneWidget);
    expect(find.byKey(Key('all-mission-$doneId')), findsNothing);
    await chooseFilterOption(tester, '任务阶段', '全部阶段');
    await chooseFilterOption(tester, '日期范围', '以前未开始 · 1');
    await scrollTo(tester, 'all-mission-$oldId');
    expect(find.byKey(Key('all-mission-$oldId')), findsOneWidget);
    expect(find.byKey(Key('all-mission-$doneId')), findsNothing);
    await chooseFilterOption(tester, '日期范围', '全部日期');
    await chooseFilterOption(tester, '目标归属', '学习目标');
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
    await chooseFilterOption(tester, '日期范围', '全部日期');
    expect(find.text('全部日期'), findsOneWidget);
    await scrollTo(tester, 'all-mission-$cancelledId');
    expect(find.byKey(Key('all-mission-$cancelledId')), findsOneWidget);
  });

  Future<String> fixed(
    String title,
    int hour,
    int minute,
    int duration, {
    MissionOwnership ownership = const MissionOwnership(),
    String day = '2026-10-25',
  }) async {
    final date = DateTime.parse(day);
    await missions.create(
      title: title,
      scheduledDate: day,
      timeZone: 'Asia/Shanghai',
      timePolicy: TimePolicy.fixed,
      fixedStartAt: DateTime.utc(
        date.year,
        date.month,
        date.day,
        hour - 8,
        minute,
      ),
      plannedDurationMinutes: duration,
      ownership: ownership,
    );
    return (await missions.findAllDetails())
        .singleWhere((detail) => detail.mission.title == title)
        .mission
        .id;
  }

  testWidgets('整周冲突合并、隐藏任务明细与跨周往返', (tester) async {
    final english = await fixed('英语阅读', 10, 30, 90);
    final discussion = await fixed(
      '项目讨论',
      11,
      0,
      90,
      ownership: MissionOwnership(goalId: goalId),
    );
    await open(
      tester,
      AllMissionsPage(missions: missions, goals: goals, clock: () => now),
    );
    expect(find.byType(MissionWeekTimetable), findsOneWidget);
    expect(find.text('2026年10月19日—10月25日'), findsOneWidget);
    for (var day = 19; day <= 25; day++) {
      expect(find.byKey(Key('week-day-2026-10-$day')), findsOneWidget);
    }
    final merged = find.byKey(Key('week-block-2026-10-25-$english'));
    expect(merged, findsOneWidget);
    expect(find.byKey(Key('week-task-$discussion')), findsNothing);
    await tester.ensureVisible(merged);
    await tester.tap(merged);
    await tester.pumpAndSettle();
    expect(find.text('英语阅读'), findsOneWidget);
    expect(find.text('项目讨论'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tap(tester, 'all-missions-filters');
    await chooseFilterOption(tester, '目标归属', '独立任务');
    await tap(tester, 'timetable-conflicts');
    expect(find.text('计划时间冲突'), findsOneWidget);
    expect(find.textContaining('已被筛选隐藏'), findsOneWidget);
    await tester.tap(find.text('项目讨论').last);
    await tester.pumpAndSettle();
    expect(find.text('任务详情'), findsOneWidget);
    await tester.tap(find.byTooltip('返回').last);
    await tester.pumpAndSettle();
    await tap(tester, 'timetable-next-week');
    expect(
      find.descendant(
        of: find.byKey(const Key('all-missions-date')),
        matching: find.text('2026年10月26日—11月1日'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(Key('week-task-$english')), findsNothing);
    await tap(tester, 'timetable-previous-week');
    expect(find.byKey(Key('week-task-$english')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('日期范围与筛选摘要明确，返回本周保留阶段', (tester) async {
    await open(
      tester,
      AllMissionsPage(missions: missions, goals: goals, clock: () => now),
    );
    await tap(tester, 'all-missions-filters');
    await chooseFilterOption(tester, '日期范围', '全部日期');
    await chooseFilterOption(tester, '任务阶段', '已取消');
    await tap(tester, 'all-missions-filters');
    expect(find.byTooltip('筛选任务，2项条件'), findsOneWidget);
    expect(find.textContaining('筛选：全部日期 · 已取消'), findsOneWidget);
    await tap(tester, 'all-missions-current-week');
    expect(find.text('2026年10月19日—10月25日'), findsOneWidget);
    expect(find.byTooltip('筛选任务，1项条件'), findsOneWidget);
    expect(find.textContaining('筛选：已取消'), findsOneWidget);
    await tap(tester, 'timetable-next-week');
    expect(find.textContaining('筛选：2026年10月26日—11月1日 · 已取消'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏大字号保留七列、整周空态与可操作的日期展开', (tester) async {
    await open(
      tester,
      AllMissionsPage(missions: missions, goals: goals, clock: () => now),
      width: 320,
      scale: 2,
    );
    await tap(tester, 'timetable-next-week');
    expect(find.text('本周暂无任务安排。'), findsOneWidget);
    final first = tester.getRect(find.byKey(const Key('week-day-2026-10-26')));
    final last = tester.getRect(find.byKey(const Key('week-day-2026-11-01')));
    expect(first.left, greaterThanOrEqualTo(0));
    expect(last.right, lessThanOrEqualTo(320));
    await tap(tester, 'all-missions-filters');
    await chooseFilterOption(tester, '任务阶段', '已取消');
    expect(find.text('本周没有符合筛选条件的任务。'), findsOneWidget);
    expect(find.text('周列表'), findsNothing);
    await tap(tester, 'week-day-2026-11-01');
    expect(find.text('2026-11-01 · 周日'), findsOneWidget);
    expect(find.text('这一天没有符合条件的任务。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自选实际区间和短任务均保留，点击日期可读完整任务', (tester) async {
    final short = await fixed('五分钟复盘', 9, 15, 5);
    await open(
      tester,
      AllMissionsPage(missions: missions, goals: goals, clock: () => now),
    );
    expect(find.byKey(Key('week-task-$doneId')), findsOneWidget);
    expect(find.byKey(Key('week-task-$short')), findsOneWidget);
    await tap(tester, 'week-day-2026-10-25');
    expect(find.text('五分钟复盘'), findsOneWidget);
    expect(find.textContaining('09:15–09:20'), findsOneWidget);
    expect(find.textContaining('实际 18:00–18:02'), findsOneWidget);
    await tester.tap(find.text('五分钟复盘'));
    await tester.pumpAndSettle();
    expect(find.text('任务详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('实际区间按共享比例实时延伸，当前线只落在当天列', (tester) async {
    await missions.execute(
      missions.prepareExecution(
        detail: (await missions.findDetail(missionId: oldId))!,
        type: ExecutionEventType.start,
      ),
    );
    now = now.add(const Duration(minutes: 20));
    await open(tester, AllMissionsPage(missions: missions, clock: () => now));
    final slot = find.byKey(Key('week-block-2026-10-25-$oldId'));
    final before = tester.getSize(slot).height;
    now = now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 30));
    expect(tester.getSize(slot).height, closeTo(before + 9, .001));
    final line = tester.getRect(find.byKey(const Key('week-timetable-now')));
    final sunday = tester.getRect(find.byKey(const Key('week-day-2026-10-25')));
    expect(line.left, closeTo(sunday.left, .01));
    expect(line.right, closeTo(sunday.right, .01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (width, scale) in [
    (320.0, 2.0),
    (390.0, 1.0),
    (480.0, 1.0),
    (768.0, 1.0),
    (1440.0, 1.0),
  ]) {
    testWidgets('七列完整适配 $width / $scale，无横向和内部纵向滚动', (tester) async {
      for (var offset = 0; offset < 7; offset++) {
        await fixed(
          const [
            '高等数学',
            '英语阅读',
            '数据结构',
            '项目实践',
            '学习复盘',
            '户外运动',
            '下周计划',
          ][offset],
          9 + offset,
          0,
          90,
          day: '2026-10-${19 + offset}',
        );
      }
      await open(
        tester,
        AllMissionsPage(missions: missions, clock: () => now),
        width: width,
        scale: scale,
      );
      final week = find.byType(MissionWeekTimetable);
      expect(
        find.descendant(of: week, matching: find.byType(Scrollable)),
        findsNothing,
      );
      final columns = [
        for (var day = 19; day <= 25; day++)
          tester.getRect(find.byKey(Key('week-day-2026-10-$day'))),
      ];
      expect(columns.last.right, lessThanOrEqualTo(width));
      for (var index = 1; index < 7; index++) {
        expect(columns[index].left, closeTo(columns[index - 1].right, .01));
        expect(columns[index].width, closeTo(columns.first.width, .01));
      }
      await _capture(tester, 'week-${width.toInt()}-${scale.toInt()}');
      expect(find.text('周时间表'), findsNothing);
      expect(find.text('周列表'), findsNothing);
      await tap(tester, 'week-day-2026-10-25');
      expect(find.text('2026-10-25 · 周日'), findsOneWidget);
      expect(find.text('下周计划'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('实时区间进入所选周后，顶栏批量操作使用新的覆盖范围', (tester) async {
    await missions.execute(
      missions.prepareExecution(
        detail: (await missions.findDetail(missionId: oldId))!,
        type: ExecutionEventType.start,
      ),
    );
    await open(tester, AllMissionsPage(missions: missions, clock: () => now));
    await tap(tester, 'timetable-next-week');
    expect(find.byKey(Key('week-task-$oldId')), findsNothing);
    now = now.add(const Duration(hours: 6));
    await tester.pump(const Duration(seconds: 30));
    expect(find.byKey(Key('week-task-$oldId')), findsOneWidget);
    await tester.tap(find.byTooltip('批量操作当前筛选结果'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除筛选结果'));
    await tester.pumpAndSettle();
    expect(find.text('永久删除 1 项任务？'), findsOneWidget);
    await tester.tap(find.text('返回').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('批量操作限定整周且跨日任务只计一次，下一周不被纳入', (tester) async {
    final cross = await fixed('周日跨周任务', 23, 30, 120);
    await fixed('下周任务', 9, 0, 60, day: '2026-10-26');
    await open(tester, AllMissionsPage(missions: missions, clock: () => now));
    await tester.tap(find.byTooltip('批量操作当前筛选结果'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除筛选结果'));
    await tester.pumpAndSettle();
    expect(find.text('永久删除 4 项任务？'), findsOneWidget);
    expect(find.textContaining('下周任务'), findsNothing);
    // 确认弹层中仅显示本周四项，不执行删除。
    await tester.tap(find.text('返回').last);
    await tester.pumpAndSettle();
    await tap(tester, 'timetable-next-week');
    expect(find.byKey(Key('week-task-$cross')), findsOneWidget);
    await tester.tap(find.byTooltip('批量操作当前筛选结果'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除筛选结果'));
    await tester.pumpAndSettle();
    expect(find.text('永久删除 2 项任务？'), findsOneWidget);
    await tester.tap(find.text('返回').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
