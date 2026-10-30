import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/presentation/goals/detail/goal_detail_page.dart';
import 'package:mission_book/presentation/widgets/app_page_header.dart';
import 'package:mission_book/presentation/widgets/app_segmented_control.dart';
import '../support/me_fakes.dart';

void main() {
  testWidgets('短目标详情从顶栏下方开始，不随屏高垂直居中', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(executor: NativeDatabase.memory());
    final goals = GoalService(DriftGoalRepository(db));
    final goal = goals.prepareCreation(title: '短目标');
    await goals.create(goal);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GoalDetailPage(service: goals, goalId: goal.id),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('短目标')).dy, 88);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await goals.dispose();
    await db.close();
  });
  for (final scenario in [
    (390.0, 844.0, 1.0),
    (320.0, 568.0, 2.0),
    (768.0, 1024.0, 1.0),
    (1024.0, 768.0, 1.0),
    (1200.0, 900.0, 1.0),
  ]) {
    testWidgets('主页面工具栏对齐、移除重复标题且无溢出 $scenario', (tester) async {
      tester.view.physicalSize = Size(scenario.$1, scenario.$2);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(executor: NativeDatabase.memory());
      final missions = MissionService(DriftMissionRepository(db));
      final goals = GoalService(DriftGoalRepository(db));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scenario.$3),
              padding: const EdgeInsets.only(top: 24),
            ),
            child: child!,
          ),
          home: AppShell(
            missionService: missions,
            goalService: goals,
            backupService: TestBackup(),
            device: TestAppDevice(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Offset? first;
      for (final title in ['今天', '目标', '历史', '我的']) {
        await tester.tap(find.byTooltip(title));
        await tester.pumpAndSettle();
        final header = title == '历史'
            ? find.byType(AppSegmentedControl<bool>)
            : find.byType(AppPageHeader);
        final point = tester.getTopLeft(header);
        first ??= point;
        expect(point, first, reason: '$title 的工具栏应使用一致页面边距');
        final heading = find.byKey(ValueKey('page-heading-$title'));
        expect(heading, findsNothing);
        if (title == '历史') {
          expect(find.text('执行报告、专注时间与材料'), findsNothing);
        }
        if (title == '今天') {
          expect(find.byKey(const Key('today-date-picker')), findsOneWidget);
          expect(find.byTooltip('创建任务'), findsOneWidget);
        }
        if (title == '目标') expect(find.text('0 个目标'), findsOneWidget);
        if (title == '我的') {
          expect(find.byKey(const Key('me-settings')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await missions.dispose();
      await goals.dispose();
      await db.close();
    });
  }
}
