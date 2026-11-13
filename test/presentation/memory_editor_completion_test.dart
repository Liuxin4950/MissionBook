import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/presentation/records/settings/memory_page.dart';
import 'package:mission_book/presentation/records/shared/record_scope.dart';
import 'package:mission_book/presentation/widgets/app_dropdown_form_field.dart';

void main() {
  final now = DateTime.utc(2030, 1, 1);
  late AppDatabase db;
  late MissionService missions;
  late RecordService records;
  late MemoryService memory;
  late AnalysisService analysis;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db));
    records = RecordService(
      DriftRecordRepository(db),
      missions,
      missions.attachments,
    );
    memory = MemoryService(DriftMemoryRepository(db, clock: () => now));
    analysis = AnalysisService(
      store: DriftAnalysisStore(db),
      mainBusy: () => true,
      model: (prompt, {imageKey, mime, json = false}) async => '摘要',
    );
  });
  tearDown(() async {
    await analysis.dispose();
    await missions.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
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
        builder: (context, child) => RecordScope(
          service: records,
          memory: memory,
          analysis: analysis,
          child: child!,
        ),
        home: MemoryPage(clock: () => now),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> saveEditor(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('memory-save')));
    await tester.tap(find.byKey(const Key('memory-save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('真实 episodic 编辑不再触发下拉断言，保存保留 extraction 来源', (tester) async {
    await memory.save({
      'id': 'episode',
      'content': '上次复盘发现晚间效果更好',
      'topic': '上次复盘',
      'layer': 'episodic',
      'certainty': 'stated',
      'importance': 73,
      'sourceKind': 'extraction',
      'sourceRef': '后台抽取原始来源',
    }, userEdited: true);
    await open(tester);
    expect(find.textContaining('重要度 73'), findsOneWidget);
    expect(find.textContaining('全局候选，按相关性与预算选入'), findsOneWidget);
    expect(find.textContaining('每轮稳定载入'), findsNothing);
    await tester.tap(find.byTooltip('更正记忆'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final layer = tester
        .widgetList<AppDropdownFormField<String>>(
          find.byType(AppDropdownFormField<String>),
        )
        .singleWhere((field) => field.decoration?.labelText == '层级');
    expect(layer.initialValue, 'episodic');
    expect(layer.items.map((item) => item.value), contains('episodic'));
    await tester.enterText(find.byKey(const Key('memory-content')), '更正后的情节');
    await saveEditor(tester);
    final saved = ((await memory.query())['items'] as List).single as Map;
    expect(saved['layer'], 'episodic');
    expect(saved['content'], '更正后的情节');
    expect(saved['importance'], 73);
    expect(saved['source_kind'], 'extraction');
    expect(saved['source_ref'], '后台抽取原始来源');
    expect(saved['user_edited'], 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('重要度通过现有下拉交互修改，持久化并回显，保留 reflection 来源', (tester) async {
    await memory.save({
      'id': 'fact',
      'content': '喜欢早上学习',
      'topic': '学习习惯',
      'layer': 'semantic',
      'certainty': 'stated',
      'importance': 50,
      'sourceKind': 'reflection',
    }, userEdited: true);
    await open(tester);
    await tester.tap(find.byTooltip('更正记忆'));
    await tester.pumpAndSettle();
    final importance = find.byKey(const Key('memory-importance'));
    await tester.ensureVisible(importance);
    await tester.tap(importance);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('51').last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('51').hitTestable());
    await tester.pumpAndSettle();
    await saveEditor(tester);
    final saved = ((await memory.query())['items'] as List).single as Map;
    expect(saved['importance'], 51);
    expect(saved['source_kind'], 'reflection');
    expect(find.textContaining('重要度 51'), findsOneWidget);
    await tester.tap(find.byTooltip('更正记忆'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppDropdownFormField<int>>(importance).initialValue,
      51,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('新建记忆保持 manual 来源，说明明确有界候选与预算', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('日记本说明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('每轮从有界候选中'), findsOneWidget);
    Navigator.of(tester.element(find.textContaining('每轮从有界候选中'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加第一条记忆'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('memory-content')), '新增事实');
    await saveEditor(tester);
    final saved = ((await memory.query())['items'] as List).single as Map;
    expect(saved['source_kind'], 'manual');
    expect(saved['importance'], 50);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
