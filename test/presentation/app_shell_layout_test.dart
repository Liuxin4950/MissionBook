import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/settings/motion_settings.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/presentation/today/today_page.dart';
import 'package:mission_book/presentation/widgets/motion_settings_scope.dart';
import '../support/me_fakes.dart';

void main() {
  late AppDatabase database;
  late MissionService missions;
  late GoalService goals;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    goals = GoalService(DriftGoalRepository(database));
    missions = MissionService(DriftMissionRepository(database));
  });
  tearDown(() async {
    await goals.dispose();
    await missions.dispose();
    await database.close();
  });

  Future<void> open(
    WidgetTester tester, {
    required double width,
    double height = 844,
    MotionSettings? motion,
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
        builder: (_, child) => motion == null
            ? child!
            : MotionSettingsHost(settings: motion, child: child!),
        home: AppShell(
          missionService: missions,
          goalService: goals,
          backupService: TestBackup(),
          device: TestAppDevice(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [390.0, 768.0, 1280.0]) {
    testWidgets('导航选中底色移动并在减少动效时立即到位 $width', (tester) async {
      final motion = MotionSettings(
        read: () async => null,
        write: (_) async {},
      );
      addTearDown(motion.dispose);
      await open(tester, width: width, motion: motion);
      final surface = find.byKey(const Key('navigation-selection-surface'));
      final initial = tester.getCenter(surface);
      await tester.tap(find.byTooltip('我的'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final during = tester.getCenter(surface);
      await tester.pumpAndSettle();
      final end = tester.getCenter(surface);
      final vertical = width >= 600;
      expect(
        vertical ? during.dy : during.dx,
        inExclusiveRange(
          vertical ? initial.dy : initial.dx,
          vertical ? end.dy : end.dx,
        ),
      );
      for (final label in ['目标', '历史', '今天']) {
        await tester.tap(find.byTooltip(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
      }
      await motion.select(MotionPreference.reduced);
      await tester.pump();
      final destination = tester.getCenter(find.byTooltip('今天'));
      expect(tester.getCenter(surface).dx, closeTo(destination.dx, .1));
      expect(tester.getCenter(surface).dy, closeTo(destination.dy, .1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('390 手机宽度用底部胶囊导航，不出现侧栏', (tester) async {
    await open(tester, width: 390);
    expect(find.byKey(const Key('nav-capsule')), findsOneWidget);
    expect(find.byKey(const Key('nav-side-rail')), findsNothing);
    expect(find.byTooltip('今天'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('768 平板宽度换左侧导航栏，语义与胶囊一致', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await open(tester, width: 768);
      expect(find.byKey(const Key('nav-side-rail')), findsOneWidget);
      expect(find.byKey(const Key('nav-capsule')), findsNothing);
      for (final label in ['今天', '目标', '历史', '我的']) {
        // 侧栏项沿用胶囊的语义外壳：标签 + 按钮 + Tooltip。
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == label &&
                widget.properties.button == true,
          ),
          findsOneWidget,
        );
        expect(find.byTooltip(label), findsOneWidget);
      }
      expect(find.byType(TodayPage, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('1280 桌面宽度侧栏加宽并保留导航语义', (tester) async {
    await open(tester, width: 1280);
    expect(find.byKey(const Key('nav-side-rail')), findsOneWidget);
    expect(find.byKey(const Key('nav-capsule')), findsNothing);
    expect(find.byTooltip('目标'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Rect railItemRect(WidgetTester tester, String label) =>
      tester.getRect(find.byTooltip(label));

  Finder railLabel(String label) =>
      find.descendant(of: find.byTooltip(label), matching: find.text(label));

  testWidgets('768 紧凑侧栏的图标与文字对准侧栏中线，选中面贴合真实项', (tester) async {
    await open(tester, width: 768);
    final rail = tester.getRect(find.byKey(const Key('navigation-rail-width')));
    final railCenter = rail.center.dx;
    for (var index = 0; index < 4; index++) {
      final label = ['今天', '目标', '历史', '我的'][index];
      final item = railItemRect(tester, label);
      final icon = tester.getRect(
        find.byKey(ValueKey('navigation-icon-$index')),
      );
      expect(item.center.dx, closeTo(railCenter, 1));
      expect(icon.center.dx, closeTo(railCenter, 1));
      expect(
        tester.getRect(railLabel(label)).center.dx,
        closeTo(railCenter, 1),
      );
      // 图标在上、文字在下。
      expect(
        icon.bottom,
        lessThanOrEqualTo(tester.getRect(railLabel(label)).top),
      );
    }
    // 选中底色跟真实目的项边界移动，不按 1/4 估算。
    expect(
      tester.getRect(find.byKey(const Key('navigation-selection-surface'))),
      railItemRect(tester, '今天'),
    );
    await tester.tap(find.byTooltip('历史'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('navigation-selection-surface'))),
      railItemRect(tester, '历史'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('1280 宽侧栏图文组居中、四项同槽宽、选中不横向跳动', (tester) async {
    await open(tester, width: 1280);
    final rail = tester.getRect(find.byKey(const Key('navigation-rail-width')));
    final railCenter = rail.center.dx;
    expect(rail.width, 192);
    // 品牌字标随侧栏中线。
    expect(
      tester.getCenter(find.byKey(const Key('navigation-brand'))).dx,
      closeTo(railCenter, 1),
    );
    final labelOffsets = <double>[];
    for (var index = 0; index < 4; index++) {
      final label = ['今天', '目标', '历史', '我的'][index];
      final item = railItemRect(tester, label);
      final icon = tester.getRect(
        find.byKey(ValueKey('navigation-icon-$index')),
      );
      final text = tester.getRect(railLabel(label));
      // 图标＋标签组合居中在整项中线。
      final group = icon.expandToInclude(text);
      expect(group.center.dx, closeTo(railCenter, 1));
      // 四项图标与标签各用相同槽宽：标签中心相对侧栏中线一致。
      labelOffsets.add(text.center.dx - railCenter);
      // 图文同行。
      expect(icon.center.dy, closeTo(text.center.dy, 6));
      expect(item.width, 176);
    }
    for (final offset in labelOffsets) {
      expect(offset, closeTo(labelOffsets.first, 0.6));
    }
    // 选中加粗不把整组推偏。
    final before = tester.getRect(railLabel('我的')).center.dx;
    await tester.tap(find.byTooltip('我的'));
    await tester.pumpAndSettle();
    expect(tester.getRect(railLabel('我的')).center.dx, closeTo(before, 0.6));
    expect(
      tester.getRect(find.byKey(const Key('navigation-selection-surface'))),
      railItemRect(tester, '我的'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('短窗口侧栏可滚动，选中面跟着真实项一起移动', (tester) async {
    await open(tester, width: 768, height: 280);
    final selection = find.byKey(const Key('navigation-selection-surface'));
    final before = tester.getRect(selection);
    expect(before, railItemRect(tester, '今天'));
    final railScroll = find
        .descendant(
          of: find.byKey(const Key('navigation-rail-width')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(railScroll, const Offset(0, -120));
    await tester.pumpAndSettle();
    final after = tester.getRect(selection);
    expect(after.top, lessThan(before.top));
    expect(after, railItemRect(tester, '今天'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('高字号下侧栏仍中线居中并按实际文字增高，保留 48dp 触控', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, width: 1280);
    final rail = tester.getRect(find.byKey(const Key('navigation-rail-width')));
    final railCenter = rail.center.dx;
    final normalTextHeight = tester.getRect(railLabel('今天')).height;
    final normalItemHeight = railItemRect(tester, '今天').height;
    expect(normalItemHeight, greaterThanOrEqualTo(48));

    // 字号跟系统：放大后文字与行高按实际文字增长。
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    expect(
      tester.getRect(railLabel('今天')).height,
      greaterThan(normalTextHeight),
    );
    for (var index = 0; index < 4; index++) {
      final label = ['今天', '目标', '历史', '我的'][index];
      final item = railItemRect(tester, label);
      expect(item.height, greaterThanOrEqualTo(48));
      final icon = tester.getRect(
        find.byKey(ValueKey('navigation-icon-$index')),
      );
      final text = tester.getRect(railLabel(label));
      final group = icon.expandToInclude(text);
      expect(group.center.dx, closeTo(railCenter, 1));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('没有助手会话时宽屏不出现橱窗门', (tester) async {
    await open(tester, width: 1280);
    expect(find.byKey(const Key('assistant-split-door')), findsNothing);
    expect(find.byKey(const Key('assistant-split-door-track')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('平板横屏为正文保留双栏空间，缩放后仍保留当前页面', (tester) async {
    await open(tester, width: 1024);
    final rail = find.byKey(const Key('navigation-rail-width'));
    expect(tester.getSize(rail).width, 88);
    expect(find.byKey(const Key('today-dashboard-columns')), findsOneWidget);
    await tester.tap(find.byTooltip('我的'));
    await tester.pumpAndSettle();
    final profile = find.byKey(const Key('profile-card'));
    final overview = find.byKey(const Key('activity-overview'));
    expect(tester.getTopLeft(profile).dy, tester.getTopLeft(overview).dy);

    tester.view.physicalSize = const Size(840, 1000);
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 88);
    expect(
      tester.getTopLeft(overview).dy,
      greaterThan(tester.getBottomLeft(profile).dy),
    );

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 192);
    expect(find.byKey(const Key('me-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-heading-我的')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
