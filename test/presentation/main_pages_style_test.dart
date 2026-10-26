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
    (1200.0, 900.0, 1.0),
  ]) {
    testWidgets('四页标题坐标一致且无溢出 $scenario', (tester) async {
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
        final finder = find.byKey(ValueKey('page-heading-$title'));
        final point = tester.getTopLeft(finder);
        first ??= point;
        expect(point, first, reason: '$title 应与今天页标题对齐');
        final text = tester.widget<Text>(finder);
        expect(text.style!.fontSize, 28);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await missions.dispose();
      await goals.dispose();
      await db.close();
    });
  }
}
