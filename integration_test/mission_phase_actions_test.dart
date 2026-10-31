import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/domain/entities/analysis_scope.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_assistant_reader.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/web/web_settings_store.dart';
import 'package:mission_book/presentation/assistant/assistant_settings_page.dart';
import 'package:mission_book/presentation/records/context_settings_page.dart';
import 'package:http/http.dart' as http;
import '../test/support/assistant_fakes.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_page.dart';
import 'package:mission_book/presentation/missions/execution/mission_execution_page.dart';
import 'package:mission_book/presentation/records/analysis_panel.dart';
import 'package:mission_book/presentation/records/record_scope.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 执行详情只读、逾期确认与结束后补材料', (tester) async {
    // 使用隔离的内存库，设备上已有任务和用户凭据不参与验收。
    var now = DateTime.utc(2026, 10, 31, 8);
    final db = AppDatabase(executor: NativeDatabase.memory());
    final service = MissionService(
      DriftMissionRepository(db, clock: () => now),
      clock: () => now,
    );
    final records = RecordService(
      DriftRecordRepository(db, clock: () => now),
      service,
    );
    final analysis = AnalysisService(
      store: DriftAnalysisStore(db),
      mainBusy: () => false,
      model: (p, {imageKey, mime, json = false}) async => '隔离的分析模型，不调用供应商',
    );
    final memory = MemoryService(DriftMemoryRepository(db));
    final web = WebService(
      settings: _PreviewWebSettings(),
      quota: DriftSearchQuota(db),
      fetchClient: http.Client.new,
    );
    final goals = GoalService(DriftGoalRepository(db));
    final assistant = AssistantController(
      reader: DriftAssistantReader(db),
      sessionStore: DriftSessionStore(db),
      settingsStore: MemoryAssistantSettingsStore(),
      missions: service,
      goals: goals,
    );
    addTearDown(() async {
      await assistant.close();
      await goals.dispose();
      await analysis.dispose();
      await service.dispose();
      await db.close();
    });

    Future<MissionDetail> seed(String title, {bool overdue = false}) async {
      final creation = service.prepareCreation(
        title: title,
        objective: '按步骤完成今天的学习内容',
        scheduledDate: '2026-10-31',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 60,
        timePolicy: overdue ? TimePolicy.fixed : TimePolicy.flexible,
        fixedStartAt: overdue ? DateTime.utc(2026, 10, 31, 2) : null,
      );
      await service.createPrepared(creation);
      return (await service.findDetail(missionId: creation.mission.id))!;
    }

    Future<void> mount(Widget home) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => RecordScope(
            service: records,
            analysis: analysis,
            memory: memory,
            web: web,
            child: child!,
          ),
          home: home,
        ),
      );
      await tester.pumpAndSettle();
    }

    var running = await seed('阅读与笔记');
    await service.execute(
      service.prepareExecution(detail: running, type: ExecutionEventType.start),
    );
    now = now.add(const Duration(minutes: 6));
    running = (await service.findDetail(missionId: running.mission.id))!;
    await mount(
      MissionExecutionPage(detail: running, service: service, clock: () => now),
    );
    await tester.tap(find.byTooltip('任务详情'));
    await tester.pumpAndSettle();
    expect(find.byType(AnalysisPanel), findsNothing);
    expect(find.text('查看记录'), findsNothing);
    expect(find.text('添加材料'), findsNothing);
    expect(find.text('确认完成情况'), findsNothing);
    expect(find.text('返回执行任务'), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-running-detail');
    await tester.tap(find.byKey(const Key('detail-return-execution')));
    await tester.pumpAndSettle();
    expect(
      (await service.findDetail(missionId: running.mission.id))!.events,
      hasLength(1),
    );
    await tester.tap(find.byKey(const Key('execution-end')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('report-completed')))
          .selected,
      isTrue,
    );
    expect(
      (await service.findDetail(
        missionId: running.mission.id,
      ))!.endReportedCompleted,
      isFalse,
    );
    await binding.takeScreenshot('05-default-end-report');
    await tester.tap(find.byKey(const Key('report-confirm')));
    await tester.pumpAndSettle();
    expect(
      (await service.findDetail(
        missionId: running.mission.id,
      ))!.endReportedCompleted,
      isTrue,
    );

    final overdue = await seed('上午课程与练习', overdue: true);
    await mount(
      MissionDetailPage(missionId: overdue.mission.id, missionService: service),
    );
    expect(find.text('这项任务完成了吗？'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('retrospective-completed')))
          .selected,
      isTrue,
    );
    await binding.takeScreenshot('02-overdue-confirmation');
    await tester.tap(find.byKey(const Key('execution-report-confirm')));
    await tester.pumpAndSettle();
    final completed = (await service.findDetail(
      missionId: overdue.mission.id,
    ))!;
    expect(completed.phase, MissionPhase.closed);
    expect(completed.events.single.isRetrospective, isTrue);
    expect(completed.effectiveUserReport!.duration, const Duration(hours: 1));
    await binding.takeScreenshot('03-completed-detail');
    final add = find.byKey(Key('evidence-open-${completed.mission.id}'));
    await tester.scrollUntilVisible(
      add,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('mission-detail-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-supplementary-materials');
    final addText = find.byKey(const Key('evidence-add-text'));
    await tester.ensureVisible(addText);
    await tester.pumpAndSettle();
    await tester.tap(addText);
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    await tester.ensureVisible(input);
    await tester.pumpAndSettle();
    await tester.enterText(input, '课后补充：今天完成了阅读和练习。');
    final submit = find.byKey(const Key('evidence-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      (await service.findDetail(
        missionId: overdue.mission.id,
      ))!.effectiveEvidence.single.content,
      '课后补充：今天完成了阅读和练习。',
    );
    expect(
      (await service.findDetail(
        missionId: overdue.mission.id,
      ))!.events.single.id,
      completed.events.single.id,
    );
    await mount(const MemoryPage());
    expect(find.text('还没有记忆'), findsOneWidget);
    await binding.takeScreenshot('06-diary-empty');
    await memory.save({
      'id': 'preview-memory',
      'content': '我喜欢安静地分步骤学习',
      'kind': 'preference',
      'certainty': 'stated',
      'source': '用户手动记录',
    }, userEdited: true);
    await mount(const MemoryPage());
    await binding.takeScreenshot('07-diary-entry');
    await mount(const WebSettingsPage());
    expect(find.text('搜索尚未配置'), findsOneWidget);
    await binding.takeScreenshot('08-web-settings');
    await mount(const AnalysisSettingsPage());
    await tester.tap(find.byKey(const Key('analysis-auto-record')));
    await tester.tap(find.byKey(const Key('analysis-save-settings')));
    await tester.pumpAndSettle();
    expect(analysis.automaticFor(AnalysisScope.record), isFalse);
    await binding.takeScreenshot('09-analysis-settings');
    await assistant.initialize();
    await mount(AssistantSettingsPage(controller: assistant));
    final role = find.byKey(const Key('assistant-persona-section'));
    await tester.scrollUntilVisible(
      role,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(role);
    await tester.pumpAndSettle();
    final address = find.byKey(const Key('assistant-user-address'));
    await tester.ensureVisible(address);
    await tester.enterText(address, '小刘');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('10-assistant-address');
    await tester.tap(find.byKey(const Key('assistant-save-settings')));
    await tester.pumpAndSettle();
    expect(assistant.persona.userAddress, '小刘');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _PreviewWebSettings implements WebSettingsStore {
  @override
  Future<String?> key() async => null;
  @override
  Future<int> limit() async => 1000;
  @override
  Future<void> save(String? key, int limit) async {}
}
