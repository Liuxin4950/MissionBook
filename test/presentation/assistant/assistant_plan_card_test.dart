import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/assistant/drift_assistant_reader.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/presentation/assistant/assistant_plan_card.dart';

import '../../support/assistant_fakes.dart';

const _captureDir = String.fromEnvironment('PLAN_CAPTURE_DIR');

void main() {
  setUpAll(() async {
    if (_captureDir.isEmpty) return;
    final font = FontLoader('PlanPreview');
    font.addFont(
      File(
        'C:/Windows/Fonts/msyh.ttc',
      ).readAsBytes().then(ByteData.sublistView),
    );
    await font.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('计划卡在手机大字和平板不溢出，逐项编辑和移除接通控制器', (tester) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final missions = MissionService(DriftMissionRepository(database));
    final goals = GoalService(DriftGoalRepository(database));
    final model = ScriptedModel([
      (_) => toolResponse('plan-ui', 'mission_plan', {
        'title': '今天的学习安排',
        'items': [
          {
            'itemId': 'one',
            'kind': 'CREATE',
            'title': '学习数据库事务',
            'objective': '理解事务提交与回滚的实际作用',
            'scheduledDate': '2026-10-29',
            'plannedMinutes': 50,
            'fixedStartLocal': '09:00',
          },
          {
            'itemId': 'two',
            'kind': 'CREATE',
            'title': '实现任务查询',
            'scheduledDate': '2026-10-29',
            'plannedMinutes': 50,
            'fixedStartLocal': '09:30',
          },
          {
            'itemId': 'three',
            'kind': 'CREATE',
            'title': '整理学习笔记',
            'scheduledDate': '2026-10-29',
            'plannedMinutes': 50,
          },
        ],
      }),
      (_) => textResponse('已取消计划。'),
    ]);
    final assistant = AssistantController(
      reader: DriftAssistantReader(database),
      sessionStore: DriftSessionStore(database),
      settingsStore: MemoryAssistantSettingsStore(),
      missions: missions,
      goals: goals,
      modelOverrides: {'deepseek-chat': model, 'deepseek': model},
    );
    addTearDown(() async {
      assistant.stop();
      await assistant.close();
      await missions.dispose();
      await goals.dispose();
      await database.close();
    });
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await assistant.initialize();
    final sending = assistant.send('安排今天');
    await tester.runAsync(() async {
      for (
        var i = 0;
        i < 100 &&
            !assistant.operations.any(
              (item) =>
                  item.status == AssistantOperationStatus.waitingConfirmation,
            );
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    expect(assistant.operations.single.planConflicts, hasLength(2));
    final screen = GlobalKey();
    Future<void> mount(double width, double scale) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: _captureDir.isEmpty
              ? AppTheme.light
              : AppTheme.light.copyWith(
                  textTheme: AppTheme.light.textTheme.apply(
                    fontFamily: 'PlanPreview',
                  ),
                  filledButtonTheme: FilledButtonThemeData(
                    style: AppTheme.light.filledButtonTheme.style!.copyWith(
                      textStyle: WidgetStatePropertyAll(
                        AppTheme.light.textTheme.labelLarge!.copyWith(
                          fontFamily: 'PlanPreview',
                        ),
                      ),
                    ),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: AppTheme.light.textButtonTheme.style!.copyWith(
                      textStyle: WidgetStatePropertyAll(
                        AppTheme.light.textTheme.labelLarge!.copyWith(
                          fontFamily: 'PlanPreview',
                        ),
                      ),
                    ),
                  ),
                ),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('zh', 'CN')],
          locale: const Locale('zh', 'CN'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: screen,
            child: Scaffold(
              appBar: AppBar(title: const Text('助手')),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: AnimatedBuilder(
                    animation: assistant,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        AssistantPlanCard(
                          controller: assistant,
                          operation: assistant.operations.single,
                          onOpenReference: (_, _) {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (_captureDir.isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 200));
        final boundary =
            screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await Directory(_captureDir).create(recursive: true);
          await File(
            '$_captureDir/plan-${width.toInt()}-${scale.toStringAsFixed(1)}.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
    }

    await mount(320, 1.6);
    await mount(390, 1);
    await mount(1106, 1);
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirm-plan-plan-ui')),
    );
    expect(confirm.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('edit-plan-two')));
    await tester.pumpAndSettle();
    final timeField = find.widgetWithText(TextFormField, '开始时间');
    await tester.enterText(timeField, '10:00');
    await tester.tap(find.text('更新预览'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(assistant.operations.single.planConflicts, isEmpty);
    expect(find.text('10:00–10:50 · 50 分钟'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remove-plan-three')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.text('整理学习笔记'), findsNothing);
    expect(find.text('2 项任务 · 100 分钟'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-plan-plan-ui')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.runAsync(() async {
      assistant.cancelProposal('plan-ui');
      await sending;
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(assistant.close);
  });
}
