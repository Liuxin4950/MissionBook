import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/domain/entities/analysis_scope.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:mission_book/application/analysis/analysis_preferences.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/data/web/web_settings_store.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'package:mission_book/presentation/records/analysis_panel.dart';
import 'package:mission_book/presentation/records/context_settings_page.dart';
import 'package:mission_book/presentation/records/record_scope.dart';
import 'package:mission_book/presentation/widgets/app_top_bar.dart';

class _WebSettings implements WebSettingsStore {
  String? value;
  int cap = 1000, saves = 0;
  bool fail = false;
  @override
  Future<String?> key() async {
    if (fail) throw StateError('测试读取失败');
    return value;
  }

  @override
  Future<int> limit() async => cap;
  @override
  Future<void> save(String? key, int limit) async {
    saves++;
    if (key != null) value = key.isEmpty ? null : key;
    cap = limit;
  }
}

class _Preferences implements AnalysisPreferencesStore {
  Set<AnalysisScope> scopes = {...summaryScopes};
  @override
  Future<Set<AnalysisScope>> load() async => Set.of(scopes);
  @override
  Future<void> save(Set<AnalysisScope> value) async => scopes = Set.of(value);
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late RecordService records;
  late MemoryService memory;
  late AnalysisService analysis;
  late _Preferences preferences;
  late _WebSettings settings;
  late WebService web;
  late int requests;
  late bool analysisDisposed;
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db));
    records = RecordService(DriftRecordRepository(db), missions);
    memory = MemoryService(DriftMemoryRepository(db));
    preferences = _Preferences();
    analysis = AnalysisService(
      store: DriftAnalysisStore(db),
      preferencesStore: preferences,
      mainBusy: () => true,
      model: (p, {imageKey, mime, json = false}) async => '手动生成的摘要',
    );
    settings = _WebSettings();
    requests = 0;
    analysisDisposed = false;
    web = WebService(
      settings: settings,
      quota: DriftSearchQuota(db),
      fetchClient: () => MockClient((_) async => http.Response('unused', 200)),
      searchClient: () => MockClient((_) async {
        requests++;
        return http.Response('{"results":[]}', 200);
      }),
    );
  });
  tearDown(() async {
    if (!analysisDisposed) await analysis.dispose();
    await missions.dispose();
    await db.close();
  });
  Future<void> open(
    WidgetTester tester,
    Widget page, {
    double width = 390,
  }) async {
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
        builder: (c, child) => RecordScope(
          service: records,
          memory: memory,
          analysis: analysis,
          web: web,
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('日记空态有统一返回和新增入口，无空分页和裸文本按钮', (tester) async {
    await open(tester, const MemoryPage());
    expect(find.byType(AppTopBar), findsOneWidget);
    expect(find.text('AI 日记本'), findsOneWidget);
    expect(find.text('还没有记忆'), findsOneWidget);
    expect(find.text('上一页'), findsNothing);
    expect(find.text('等待记忆提取：0 条'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    await tester.tap(find.byTooltip('添加记忆'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('memory-content')), '喜欢分步骤学习');
    await tester.ensureVisible(find.byKey(const Key('memory-save')));
    await tester.tap(find.byKey(const Key('memory-save')));
    await tester.pumpAndSettle();
    expect(find.text('喜欢分步骤学习'), findsOneWidget);
    expect(await memory.core(), contains('喜欢分步骤学习'));
    await close(tester);
  });

  testWidgets('日记按需展示来源，过期内容默认隐藏但可查看', (tester) async {
    await memory.save({
      'id': 'expired',
      'content': '考试周临时安排',
      'kind': 'constraint',
      'source': '用户明确陈述',
      'certainty': 'stated',
      'expiresAt': DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch,
    }, userEdited: true);
    await open(tester, const MemoryPage());
    expect(find.text('考试周临时安排'), findsNothing);
    await tester.tap(find.text('包含过期'));
    await tester.pumpAndSettle();
    expect(find.text('考试周临时安排'), findsOneWidget);
    expect(find.textContaining('已过期'), findsOneWidget);
    await tester.tap(find.text('来源与有效期'));
    await tester.pumpAndSettle();
    expect(find.textContaining('用户明确陈述'), findsWidgets);
    expect(find.textContaining('已停止自动载入'), findsOneWidget);
    await close(tester);
  });

  testWidgets('搜索设置加载后才能保存，验证额度并测试已保存的Key', (tester) async {
    await open(tester, const WebSettingsPage());
    expect(find.byType(AppTopBar), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    await tester.enterText(find.byKey(const Key('web-monthly-limit')), '1001');
    await tester.tap(find.byKey(const Key('web-save-settings')));
    await tester.pumpAndSettle();
    expect(settings.saves, 0);
    await tester.enterText(
      find.byKey(const Key('web-api-key')),
      'test-search-key',
    );
    await tester.enterText(find.byKey(const Key('web-monthly-limit')), '25');
    await tester.tap(find.byKey(const Key('web-save-settings')));
    await tester.pumpAndSettle();
    expect(settings.value, 'test-search-key');
    expect(settings.cap, 25);
    final test = find.text('检查搜索连接');
    await tester.ensureVisible(test);
    await tester.tap(test);
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(await web.quota.used(web.month), 1);
    await tester.ensureVisible(find.text('移除已保存的 Key'));
    await tester.tap(find.text('移除已保存的 Key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除 Key'));
    await tester.pumpAndSettle();
    expect(settings.value, isNull);
    await close(tester);
  });

  testWidgets('搜索设置读取失败不显示假配置、不开放保存，可重试', (tester) async {
    settings.fail = true;
    await open(tester, const WebSettingsPage());
    expect(find.text('搜索设置读取失败，请重试'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('web-save-settings')))
          .onPressed,
      isNull,
    );
    settings.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('web-api-key')), findsOneWidget);
    await close(tester);
  });

  testWidgets('自动总结逐层保存，关闭后对应页面直接显示手动生成按钮', (tester) async {
    await open(tester, const AnalysisSettingsPage());
    await tester.tap(find.byKey(const Key('analysis-auto-record')));
    await tester.tap(find.byKey(const Key('analysis-auto-goal')));
    await tester.tap(find.byKey(const Key('analysis-save-settings')));
    await tester.pumpAndSettle();
    expect(preferences.scopes, {AnalysisScope.mission, AnalysisScope.node});
    await records.save(
      const EvidenceDraft(
        id: 'manual-record',
        type: EvidenceType.text,
        source: EvidenceSource.user,
        content: '新的笔记',
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await open(
      tester,
      const Scaffold(
        body: AnalysisPanel(scope: AnalysisScope.record, id: 'manual-record'),
      ),
    );
    expect(find.textContaining('自动总结已关闭'), findsOneWidget);
    expect(find.text('生成总结'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('generate-summary-record-manual-record')),
    );
    await tester.pumpAndSettle();
    expect(
      (await db.select(db.analysisJobs).get()).single.status,
      'manual_pending',
    );
    expect(find.text('等待总结…'), findsOneWidget);
    expect(analysis.automaticFor(AnalysisScope.record), isFalse);
    await close(tester);
    await analysis.dispose();
    analysisDisposed = true;
  });
}
