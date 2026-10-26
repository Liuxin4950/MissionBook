import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_file_picker.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/domain/entities/goal_outline_import.dart';
import 'package:mission_book/presentation/goals/list/goals_page.dart';

const outline = '''{"schema":"mission-book.goal-outline","version":1,
"goal":{"title":"完成自己的项目","why":"持续练习"},
"nodes":[{"key":"interface","title":"界面","children":[{"key":"routes","title":"导航"}]},
{"key":"data","title":"数据"}]}''';

class _Picker implements GoalFilePicker {
  Uint8List? bytes;
  @override
  Future<Uint8List?> pickBytes() async => bytes;
}

class _UncertainImportRepository extends DriftGoalRepository {
  _UncertainImportRepository(super.database);
  bool loseReply = false;
  @override
  Future<void> importOutline(GoalOutlineCreation request) async {
    await super.importOutline(request);
    if (loseReply) {
      loseReply = false;
      throw StateError('测试：保存成功但回复丢失');
    }
  }
}

void main() {
  late AppDatabase db;
  late GoalService goals;
  late _Picker picker;
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    picker = _Picker();
    goals = GoalService(DriftGoalRepository(db), filePicker: picker);
  });
  tearDown(() async {
    await goals.dispose();
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
        home: GoalsPage(service: goals),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('粘贴校验预览完整树，确认之前零写入，确认后原位显示正式目标', (tester) async {
    await open(tester);
    await tap(tester, 'goal-create-import');
    await tester.enterText(find.byKey(const Key('goal-import-input')), outline);
    await tap(tester, 'goal-import-preview');
    expect(find.text('完整大纲 · 3 个节点'), findsOneWidget);
    expect(find.text('• 导航'), findsOneWidget);
    expect(await goals.findAll(), isEmpty);
    await tap(tester, 'goal-import-confirm');
    expect((await goals.findAll()).single.title, '完成自己的项目');
    final saved = (await goals.findAll()).single;
    expect(await goals.findNodes(saved.id), hasLength(3));
    expect(find.byKey(const Key('goal-import-section')), findsNothing);
    expect(find.byKey(Key('goal-${saved.id}')), findsOneWidget);
  });

  testWidgets('非法字段指出位置，取消文件选择保留粘贴内容，放弃预览不写入', (tester) async {
    await open(tester);
    await tap(tester, 'goal-create-import');
    await tester.enterText(
      find.byKey(const Key('goal-import-input')),
      outline.replaceFirst('"key":"data"', '"key":"interface"'),
    );
    await tap(tester, 'goal-import-preview');
    expect(find.textContaining('nodes[1].key'), findsOneWidget);
    expect(await goals.findAll(), isEmpty);
    await tap(tester, 'goal-import-file'); // 系统选择取消，不清空草稿。
    expect(find.textContaining('"interface"'), findsWidgets);
    await tester.enterText(find.byKey(const Key('goal-import-input')), outline);
    await tap(tester, 'goal-import-preview');
    await tester.drag(find.byType(ListView), const Offset(0, 650));
    await tester.pumpAndSettle();
    await tap(tester, 'goal-create');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tap(tester, 'goal-import-confirm');
    expect((await goals.findAll()).single.title, '完成自己的项目');
  });

  testWidgets('从文件读取后走同一预览与确认流程', (tester) async {
    picker.bytes = Uint8List.fromList(utf8.encode(outline));
    await open(tester);
    await tap(tester, 'goal-create-import');
    await tap(tester, 'goal-import-file');
    expect(find.text('完整大纲 · 3 个节点'), findsOneWidget);
    expect(await goals.findAll(), isEmpty);
  });

  testWidgets('提交成功但回复丢失后确认同一请求，不产生第二棵树', (tester) async {
    await goals.dispose();
    final repository = _UncertainImportRepository(db);
    goals = GoalService(repository, filePicker: picker);
    await open(tester);
    await tap(tester, 'goal-create-import');
    await tester.enterText(find.byKey(const Key('goal-import-input')), outline);
    await tap(tester, 'goal-import-preview');
    repository.loseReply = true;
    await tap(tester, 'goal-import-confirm');
    expect(await goals.findAll(), hasLength(1));
    expect(find.byKey(const Key('goal-import-check-result')), findsOneWidget);
    await tap(tester, 'goal-import-check-result');
    final saved = (await goals.findAll()).single;
    expect(await goals.findNodes(saved.id), hasLength(3));
    expect(find.byKey(const Key('goal-import-section')), findsNothing);
  });

  testWidgets('已有目标从更多菜单打开导入，收起后仍能直接新建', (tester) async {
    await goals.create(goals.prepareCreation(title: '已有目标'));
    await open(tester);
    await tap(tester, 'goal-more-filters');
    await tap(tester, 'goal-import-menu');
    expect(find.byKey(const Key('goal-import-input')), findsOneWidget);
    await tester.tap(find.text('收起导入区'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-import-section')), findsNothing);
    await tap(tester, 'goal-create');
    expect(find.byKey(const Key('goal-title-input')), findsOneWidget);
    expect(await goals.findAll(), hasLength(1));
  });
}
