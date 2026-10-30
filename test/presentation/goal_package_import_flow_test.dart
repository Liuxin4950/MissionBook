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
    await tap('goal-import-paste-toggle');
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
  for (final width in [320.0, 768.0, 1578.0]) {
    testWidgets('导入错误可理解、输入可修正、格式示例可真正导入 $width', (tester) async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      final stage = GoalImportDatabase(executor: NativeDatabase.memory());
      final goals = GoalService(
        DriftGoalRepository(db),
        packages: GoalPackageImportService(
          stage: stage,
          repository: DriftGoalPackageRepository(db),
        ),
      );
      addTearDown(() async {
        await goals.dispose();
        await stage.close();
        await db.close();
      });
      tester.view.physicalSize = Size(width, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(width == 320 ? 2 : 1)),
            child: child!,
          ),
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
      await tap('goal-import-paste-toggle');
      for (final invalid in [
        '{',
        '{}',
        '{"Schema": "mission-book.goal-outline"}',
      ]) {
        await tester.enterText(
          find.byKey(const Key('goal-import-input')),
          invalid,
        );
        await tap('goal-import-preview');
        final error = tester
            .widget<Text>(find.byKey(const Key('goal-import-error')))
            .data!;
        expect(
          error,
          invalid == '{' ? contains('括号、引号与逗号') : contains('查看支持的格式'),
        );
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byKey(const Key('goal-import-input')),
                  matching: find.byType(TextField),
                ),
              )
              .controller!
              .text,
          invalid,
        );
        expect(await db.select(db.goals).get(), isEmpty);
        expect(tester.takeException(), isNull);
      }
      await tap('goal-import-format-help');
      final example = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      await tester.enterText(
        find.byKey(const Key('goal-import-input')),
        example,
      );
      await tap('goal-import-preview');
      expect(find.byKey(const Key('goal-import-error')), findsNothing);
      expect(await db.select(db.goals).get(), isEmpty);
      await tap('goal-import-confirm');
      expect(await db.select(db.goals).get(), hasLength(1));
      expect(await db.select(db.goalNodes).get(), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
