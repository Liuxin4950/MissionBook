import 'dart:io';

import 'package:drift/native.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/memory/memory_context.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/memory/drift_memory_settings_store.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/presentation/records/analysis/analysis_settings_page.dart';
import 'package:mission_book/presentation/records/settings/memory_page.dart';
import 'package:mission_book/presentation/records/shared/record_scope.dart';
import 'package:mission_book/presentation/assistant/chat/assistant_page.dart';

import '../test/application/assistant/assistant_controller_test.dart'
    show SwitchableMemory;
import '../test/support/assistant_fakes.dart';

/// 使用设备真实屏幕、键盘和独立 SQLite 文件验证记忆界面与持久化。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File databaseFile;
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late RecordService records;
  late MemoryService memory;
  late AnalysisService analysis;

  void connect() {
    db = AppDatabase(executor: NativeDatabase(databaseFile));
    missions = MissionService(DriftMissionRepository(db));
    goals = GoalService(DriftGoalRepository(db));
    memory = MemoryService(DriftMemoryRepository(db));
    records = RecordService(
      DriftRecordRepository(db),
      missions,
      missions.attachments,
    );
    analysis = AnalysisService(
      store: DriftAnalysisStore(db),
      memorySettings: DriftMemorySettingsStore(db),
      mainBusy: () => true,
      model: (prompt, {imageKey, mime, json = false}) async => '{}',
    );
  }

  Future<void> disconnect() async {
    await analysis.dispose();
    await missions.dispose();
    await goals.dispose();
    await db.close();
  }

  setUp(() async {
    directory = await (await getTemporaryDirectory()).createTemp(
      'memory-audit-',
    );
    databaseFile = File('${directory.path}/memory.sqlite');
    connect();
  });

  tearDown(() async {
    await disconnect();
    await directory.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester,
    Widget page, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => RecordScope(
          service: records,
          memory: memory,
          analysis: analysis,
          goals: goals,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> hideKeyboard(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> saveEditor(WidgetTester tester) async {
    await hideKeyboard(tester);
    await tester.ensureVisible(find.byKey(const Key('memory-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('memory-save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('Android 新增、别名检索、重开数据库、更正和忘记', (tester) async {
    await open(tester, const MemoryPage());
    await tester.tap(find.text('添加记忆'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('memory-content')),
      '设备验收：我习惯早上跑步五公里',
    );
    await tester.ensureVisible(find.byKey(const Key('memory-aliases')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('memory-aliases')), '晨跑，早上跑步');
    await saveEditor(tester);
    expect(find.text('设备验收：我习惯早上跑步五公里'), findsOneWidget);
    expect((await memory.query(search: '晨跑'))['items'] as List, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await disconnect();
    connect();
    await open(tester, const MemoryPage());
    expect(find.text('设备验收：我习惯早上跑步五公里'), findsOneWidget);
    await tester.tap(find.byTooltip('更正记忆'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('memory-content')),
      '设备验收：我现在习惯晚上跑步三公里',
    );
    await saveEditor(tester);
    expect(find.text('设备验收：我现在习惯晚上跑步三公里'), findsOneWidget);
    expect(await db.select(db.memoryVersions).get(), hasLength(2));
    await tester.tap(find.byTooltip('忘记记忆'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '忘记'));
    await tester.pumpAndSettle();
    expect((await memory.query())['items'] as List, isEmpty);
    expect((await db.select(db.memoryItems).getSingle()).forgotten, isTrue);
    expect(
      (await MemoryContextAssembler(memory: memory).assemble()).isEmpty,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android 目标筛选及实际注入隔离', (tester) async {
    final first = goals.prepareCreation(title: '设备目标甲');
    final second = goals.prepareCreation(title: '设备目标乙');
    await goals.create(first);
    await goals.create(second);
    for (final (id, content, goalId) in [
      ('global', '全局学习偏好', null),
      ('first', '甲目标专用记忆', first.id),
      ('second', '乙目标专用记忆', second.id),
    ]) {
      await memory.save({
        'id': id,
        'content': content,
        'topic': content,
        'layer': 'identity',
        'certainty': 'stated',
        'goalId': goalId,
        'sourceKind': 'user',
      });
    }
    await open(tester, const MemoryPage());
    await tester.tap(find.byKey(const Key('memory-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部记忆'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设备目标甲').last);
    await tester.pumpAndSettle();
    expect(find.text('全局学习偏好'), findsOneWidget);
    expect(find.text('甲目标专用记忆'), findsOneWidget);
    expect(find.text('乙目标专用记忆'), findsNothing);
    final context = await MemoryContextAssembler(
      memory: memory,
    ).assemble(goalId: first.id);
    expect(context.text, contains('甲目标专用记忆'));
    expect(context.text, isNot(contains('乙目标专用记忆')));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android 自动整理开关即时持久化并可恢复', (tester) async {
    await open(tester, const AnalysisSettingsPage());
    final toggle = find.byKey(const Key('analysis-auto-memory'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(await DriftMemorySettingsStore(db).extractionEnabled(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await disconnect();
    connect();
    await open(tester, const AnalysisSettingsPage());
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(await DriftMemorySettingsStore(db).extractionEnabled(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android 记忆读取失败时显示提示，恢复后自动清除', (tester) async {
    final failing = SwitchableMemory(DriftMemoryRepository(db))..failing = true;
    final ai = AssistantController(
      unifiedReader: DriftUnifiedReader(db),
      sessionStore: DriftSessionStore(db),
      settingsStore: MemoryAssistantSettingsStore(),
      missions: missions,
      goals: goals,
      memory: failing,
      modelOverrides: {
        'deepseek-chat': ScriptedModel([
          (_) => textResponse('降级回答'),
          (_) => textResponse('正常回答'),
        ]),
      },
    );
    try {
      await ai.initialize();
      await open(tester, AssistantPage(controller: ai));
      await ai.send('读取失败时也要回答');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('assistant-memory-warning')).hitTestable(),
        findsOneWidget,
      );
      expect(ai.errorMessage, isNull);
      failing.failing = false;
      await ai.send('读取恢复后继续');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant-memory-warning')), findsNothing);
      expect(ai.memoryWarning, isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await ai.close();
      ai.dispose();
    }
  });

  testWidgets('Android 双倍字号能滚动进入新增弹层并保存', (tester) async {
    await open(tester, const MemoryPage(), textScale: 2);
    await tester.scrollUntilVisible(
      find.text('添加记忆'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加记忆'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('memory-content')), '双倍字号设备验收');
    await saveEditor(tester);
    expect((await memory.query())['items'] as List, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
