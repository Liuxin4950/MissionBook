import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/presentation/today/today_page.dart';
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

  Future<void> open(WidgetTester tester, {required double width}) async {
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
