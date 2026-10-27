import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_package_import_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/goal_import/goal_import_database.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_package_repository.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/presentation/goals/list/goals_page.dart';

void main() {
  testWidgets('完整目标包从粘贴到预览确认，写入真实任务与排期', (tester) async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final stage = GoalImportDatabase(executor: NativeDatabase.memory());
    final packages = GoalPackageImportService(
      stage: stage,
      repository: DriftGoalPackageRepository(
        db,
        clock: () => DateTime.utc(2026, 10, 27, 4),
      ),
    );
    final goals = GoalService(DriftGoalRepository(db), packages: packages);
    addTearDown(() async {
      await goals.dispose();
      await stage.close();
      await db.close();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: GoalsPage(service: goals),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(String key) async {
      final target = find.byKey(Key(key));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap('goal-create-import');
    final input = File(
      'docs/设计/目标计划导入/examples/课标试运行.goal-package.v1.json',
    ).readAsStringSync();
    await tester.enterText(find.byKey(const Key('goal-import-input')), input);
    await tap('goal-import-preview');
    expect(find.textContaining('6 个节点；5 个任务'), findsOneWidget);
    expect(await db.select(db.goals).get(), isEmpty);
    await tap('goal-import-confirm');
    expect(await db.select(db.goals).get(), hasLength(1));
    expect(await db.select(db.missions).get(), hasLength(5));
    expect(await db.select(db.executionPlans).get(), hasLength(5));
    expect(await db.select(db.missionScheduleRevisions).get(), hasLength(5));
    expect(await db.select(db.executionEvents).get(), isEmpty);
  });
}
