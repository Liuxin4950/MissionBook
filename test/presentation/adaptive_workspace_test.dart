import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/domain/entities/goal.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/presentation/missions/execution/mission_execution_page.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/presentation/missions/all/mission_timetable.dart';
import 'package:mission_book/presentation/missions/form/mission_form_page.dart';
import '../support/me_fakes.dart';

// 可选的真实字体截图只用于本机视觉复核，普通 CI 不依赖系统字体或输出目录。
const _captureDir = String.fromEnvironment('UI_CAPTURE_DIR');
final _screen = GlobalKey();

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDir.isEmpty) return;
  // Widget测试的图片解码不一定随着pump完成；截图前等待真实首帧，避免把空占位当成外观。
  await tester.runAsync(() async {
    for (final asset in [
      'assets/illustrations/goal-path.png',
      'assets/illustrations/day-plan.png',
      'assets/illustrations/history-pages.png',
      'assets/illustrations/profile-paper-background.png',
      'assets/illustrations/profile-notebook.png',
      'assets/illustrations/settings-notebook.png',
      'assets/illustrations/focus-hourglass.png',
    ]) {
      await precacheImage(AssetImage(asset), _screen.currentContext!);
    }
    // 页面按实际展示尺寸缓存，截图需预解码同一 ResizeImage，而不仅是原图。
    for (final (asset, width) in [
      ('assets/illustrations/profile-notebook.png', 630),
      ('assets/illustrations/settings-notebook.png', 300),
      ('assets/illustrations/focus-hourglass.png', 240),
      ('assets/illustrations/goal-path.png', 240),
      ('assets/illustrations/history-pages.png', 240),
    ]) {
      await precacheImage(
        ResizeImage(AssetImage(asset), width: width),
        _screen.currentContext!,
      );
    }
  });
  await tester.pumpAndSettle();
  final boundary =
      _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(_captureDir).create(recursive: true);
    await File(
      '$_captureDir/$name.png',
    ).writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late String goalId;
  late DateTime now;

  setUpAll(() async {
    if (_captureDir.isEmpty) return;
    final font = FontLoader('UiPreview');
    font.addFont(
      File(
        '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await font.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() async {
    now = DateTime.utc(2030, 10, 26, 2, 30);
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(db, clock: () => now),
      clock: () => now,
    );
    goals = GoalService(DriftGoalRepository(db));
    for (final title in ['系统学习 Flutter', '完善个人技术网站', '提升软件测试能力']) {
      final goal = goals.prepareCreation(
        title: title,
        description: '把方向拆成清晰的行动，记录每一次实践。',
      );
      await goals.create(goal);
      if (title == '系统学习 Flutter') goalId = goal.id;
    }
    for (final title in ['布局基础', '状态管理', '项目实践']) {
      final node = goals.prepareNodeCreation(
        goalId: goalId,
        title: title,
        description: '学习并完成一次独立练习',
      );
      await goals.createNode(node);
      await missions.createPrepared(
        missions.prepareCreation(
          title: '练习$title',
          scheduledDate: '2030-10-26',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 30,
          ownership: MissionOwnership(goalId: goalId, goalNodeId: node.id),
        ),
      );
    }
    for (final (title, hour, minutes) in [
      ('学习 Flutter 页面布局', 1, 90),
      ('整理项目需求', 2, 60),
      ('练习 Spring Boot API', 6, 60),
    ]) {
      await missions.create(
        title: title,
        scheduledDate: '2030-10-26',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: minutes,
        timePolicy: TimePolicy.fixed,
        fixedStartAt: DateTime.utc(2030, 10, 26, hour),
      );
    }
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<void> open(
    WidgetTester tester,
    Size size, {
    double scale = 1,
    Widget? home,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var theme = AppTheme.light;
    if (_captureDir.isNotEmpty) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'UiPreview'),
        chipTheme: theme.chipTheme.copyWith(
          labelStyle: theme.chipTheme.labelStyle?.copyWith(
            fontFamily: 'UiPreview',
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          labelStyle: theme.inputDecorationTheme.labelStyle?.copyWith(
            fontFamily: 'UiPreview',
          ),
          hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
            fontFamily: 'UiPreview',
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: theme.textButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(
              theme.textTheme.labelLarge?.copyWith(fontFamily: 'UiPreview'),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: theme.filledButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(
              theme.textTheme.labelLarge?.copyWith(fontFamily: 'UiPreview'),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: theme.outlinedButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(
              theme.textTheme.labelLarge?.copyWith(fontFamily: 'UiPreview'),
            ),
          ),
        ),
      );
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: _screen,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home:
              home ??
              AppShell(
                missionService: missions,
                goalService: goals,
                backupService: TestBackup(),
                device: TestAppDevice(),
                clock: () => now,
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (width, scale) in [
    (320.0, 2.0),
    (390.0, 1.0),
    (768.0, 1.0),
    (1200.0, 1.0),
    (1536.0, 1.0),
    (1920.0, 1.0),
  ]) {
    testWidgets('真实数据在 $width / $scale 下重组布局，目标三个分类都可点击', (tester) async {
      await open(tester, Size(width, 1000), scale: scale);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('today-dashboard-columns')),
        width >= 1200 ? findsOneWidget : findsNothing,
      );
      if (width >= 1200) {
        expect(find.byType(MissionTimetable), findsOneWidget);
        final schedule = tester.getRect(
          find.byKey(const Key('today-timetable-panel')),
        );
        final flexible = tester.getRect(find.text('自选时间'));
        expect(flexible.left, greaterThan(schedule.right));
      }
      await _capture(tester, 'today-${width.toInt()}');
      await tester.tap(find.byTooltip('目标'));
      await tester.pumpAndSettle();
      for (final status in ['paused', 'achieved', 'active']) {
        final tab = find.byKey(Key('goal-filter-$status'));
        expect(tab.hitTestable(), findsOneWidget);
        final rect = tester.getRect(tab);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        await tester.tap(tab);
        await tester.pumpAndSettle();
      }
      if (width >= 1200) {
        await tester.tap(find.byKey(Key('goal-outline-toggle-$goalId')));
        await tester.pumpAndSettle();
        final library = tester.getRect(
          find.byKey(const Key('goal-library-pane')),
        );
        final path = tester.getRect(find.byKey(const Key('goal-action-pane')));
        expect(path.left, greaterThan(library.right));
        for (final label in ['布局基础', '状态管理', '项目实践']) {
          expect(find.text(label), findsOneWidget);
        }
      }
      await _capture(tester, 'goals-${width.toInt()}');
      await tester.tap(find.byTooltip('我的'));
      await tester.pumpAndSettle();
      await _capture(tester, 'profile-${width.toInt()}');
      await tester.tap(find.byKey(const Key('me-settings')));
      await tester.pumpAndSettle();
      await _capture(tester, 'settings-${width.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('目标空态与已放弃分类视觉复核', (tester) async {
    for (final goal in await goals.findAll()) {
      await goals.setGoalStatus(goal, GoalStatus.dropped);
    }
    // 下一天没有测试排期；只改变注入时钟，不删除任务，更不读取用户数据库。
    now = now.add(const Duration(days: 1));
    for (final (width, scale) in [
      (320.0, 2.0),
      (390.0, 1.0),
      (768.0, 1.0),
      (1280.0, 1.0),
      (1920.0, 1.0),
    ]) {
      await open(tester, Size(width, 900), scale: scale);
      await _capture(tester, 'today-empty-${width.toInt()}');
      await tester.tap(find.byTooltip('目标'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-create')), findsOneWidget);
      await _capture(tester, 'goals-empty-${width.toInt()}');
      if (width == 1280) {
        for (final status in ['paused', 'achieved']) {
          await tester.tap(find.byKey(Key('goal-filter-$status')));
          await tester.pumpAndSettle();
          await _capture(tester, 'goals-empty-$status-no-active-1280');
        }
        await tester.tap(find.byKey(const Key('goal-filter-active')));
        await tester.pumpAndSettle();
      }
      final create = find.byKey(const Key('goal-create'));
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      // 创建入口直接进入表单；不再经过创建方式选择器。
      expect(find.byKey(const Key('goal-title-input')), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('历史'));
      await tester.pumpAndSettle();
      expect(find.text('还没有执行结束的记录'), findsOneWidget);
      await _capture(tester, 'history-empty-${width.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await open(tester, const Size(1280, 900));
    await tester.tap(find.byTooltip('目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-more-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已放弃的目标'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-filter-dropped')), findsOneWidget);
    await _capture(tester, 'goals-dropped-1280');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('目标状态空态在各宽度保持分类隔离，进行中目标从对应分类进入', (tester) async {
    for (final (width, scale) in [
      (320.0, 2.0),
      (390.0, 1.0),
      (768.0, 1.0),
      (1280.0, 1.0),
      (1920.0, 1.0),
    ]) {
      await open(tester, Size(width, 900), scale: scale);
      await tester.tap(find.byTooltip('目标'));
      await tester.pumpAndSettle();
      for (final (status, title) in [
        ('paused', '没有已搁置的目标'),
        ('achieved', '没有已达成的目标'),
      ]) {
        await tester.tap(find.byKey(Key('goal-filter-$status')));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(
          find.byKey(Key('goal-empty-illustration-$status')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('goal-empty-next-pane')), findsNothing);
        expect(find.byKey(Key('goal-$goalId')), findsNothing);
        expect(find.byKey(const Key('goal-create')), findsNothing);
        expect(find.byKey(const Key('goal-import-input')), findsNothing);
        expect(find.text('进行中的目标'), findsNothing);
        if (width == 1280) {
          final hero = tester.getRect(
            find.byKey(const Key('goal-empty-state')),
          );
          final firstTab = tester.getRect(
            find.byKey(const Key('goal-filter-active')),
          );
          final lastTab = tester.getRect(
            find.byKey(const Key('goal-filter-achieved')),
          );
          expect(hero.left, closeTo(firstTab.left - 4, .01));
          expect(hero.right, closeTo(lastTab.right + 4, .01));
          await _capture(tester, 'goals-empty-$status-1280');
        }
        expect(tester.takeException(), isNull);
      }
      final activeFilter = find.byKey(const Key('goal-filter-active'));
      await tester.ensureVisible(activeFilter);
      await tester.tap(activeFilter);
      await tester.pumpAndSettle();
      final activeGoal = find.byKey(Key('goal-$goalId'));
      await tester.ensureVisible(activeGoal);
      await tester.pumpAndSettle();
      await tester.tap(activeGoal);
      await tester.pumpAndSettle();
      expect(find.text('目标详情'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('goal-$goalId')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('独立导入工作区在缩放中保留草稿，返回前确认丢弃', (tester) async {
    for (final goal in await goals.findAll()) {
      await goals.setGoalStatus(goal, GoalStatus.dropped);
    }
    await open(tester, const Size(1280, 900));
    await tester.tap(find.byTooltip('目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-create-import')));
    await tester.pumpAndSettle();
    const draft = '{"尚未保存的目标草稿":true}';
    final input = find.byKey(const Key('goal-import-input'));
    await tester.enterText(input, draft);
    expect(find.byKey(const Key('goal-import-section')), findsOneWidget);
    for (final width in [390.0, 768.0, 1536.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, draft);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('离开目标导入？'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, draft);
    expect(await goals.findAll(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('执行工作区视觉复核：底部紧凑任务栏与结束后左右一致', (tester) async {
    final task = (await missions.findAllDetails()).firstWhere(
      (detail) => detail.mission.title == '整理项目需求',
    );
    await missions.execute(
      missions.prepareExecution(detail: task, type: ExecutionEventType.start),
    );
    now = now.add(const Duration(minutes: 12, seconds: 34));
    await open(tester, const Size(1280, 900));
    await _capture(tester, 'active-bottom-1280');
    await tester.tap(find.byKey(const Key('active-mission')));
    await tester.pumpAndSettle();
    expect(find.byType(MissionExecutionPage), findsOneWidget);
    await _capture(tester, 'execution-split-1280');
    for (final key in ['execution-end', 'report-completed', 'report-confirm']) {
      final control = find.byKey(Key(key));
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('active-mission')), findsNothing);
    await _capture(tester, 'ended-split-1280');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('连续创建使用新编号，返回关闭表单；缩放保留草稿和选中日期', (tester) async {
    await open(
      tester,
      const Size(1536, 1000),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => MissionFormPage(
                  missionService: missions,
                  initialScheduledDate: '2030-10-26',
                  clock: () => now,
                ),
              ),
            ),
            child: const Text('打开创建'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开创建'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mission-title')), '第一项新任务');
    await tester.enterText(find.byKey(const Key('mission-duration')), '25');
    await _capture(tester, 'form-desktop');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mission-title')))
          .controller!
          .text,
      '第一项新任务',
    );
    await _capture(tester, 'form-phone');
    await tester.tap(find.text('创建任务'));
    await tester.pumpAndSettle();
    expect(find.text('任务已创建'), findsOneWidget);
    await tester.tap(find.text('继续新建'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('mission-title')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('2030年10月26日'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('mission-title')), '第二项新任务');
    await tester.enterText(find.byKey(const Key('mission-duration')), '15');
    await tester.tap(find.text('创建任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回原页面'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionFormPage), findsNothing);
    final saved = (await missions.findAllDetails())
        .where((detail) => detail.mission.title.endsWith('项新任务'))
        .toList();
    expect(saved, hasLength(2));
    expect(saved[0].mission.id, isNot(saved[1].mission.id));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
