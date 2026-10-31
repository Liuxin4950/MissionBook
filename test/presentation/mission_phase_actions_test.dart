import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_page.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_content.dart';
import 'package:mission_book/presentation/missions/evidence/mission_evidence_section.dart';
import 'package:mission_book/presentation/missions/execution/mission_execution_page.dart';
import 'package:mission_book/presentation/records/analysis_panel.dart';
import 'package:mission_book/presentation/records/record_scope.dart';
import 'package:mission_book/presentation/records/records_page.dart';
import 'package:mission_book/presentation/widgets/app_settings_row.dart';

void main() {
  late DateTime now;
  late AppDatabase db;
  late MissionService service;
  late RecordService records;
  late AnalysisService analysis;
  setUp(() {
    now = DateTime.utc(2026, 10, 31, 8);
    db = AppDatabase(executor: NativeDatabase.memory());
    service = MissionService(
      DriftMissionRepository(db, clock: () => now),
      clock: () => now,
    );
    records = RecordService(
      DriftRecordRepository(db, clock: () => now),
      service,
    );
    analysis = AnalysisService(
      store: DriftAnalysisStore(db),
      mainBusy: () => false,
      model: (p, {imageKey, mime, json = false}) async => '测试摘要',
    );
  });
  tearDown(() async {
    await analysis.dispose();
    await service.dispose();
    await db.close();
  });

  Future<MissionDetail> seed({
    bool fixed = false,
    DateTime? start,
    VerificationPolicy policy = VerificationPolicy.optionalEvidence,
  }) async {
    final request = service.prepareCreation(
      title: '上午的任务',
      scheduledDate: '2026-10-31',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 60,
      timePolicy: fixed ? TimePolicy.fixed : TimePolicy.flexible,
      fixedStartAt: fixed ? start ?? DateTime.utc(2026, 10, 31, 2) : null,
      verificationPolicy: policy,
      verificationCriteria: policy == VerificationPolicy.requiredEvidence
          ? '提供课堂笔记'
          : null,
      evidenceDeadlineAt: policy == VerificationPolicy.requiredEvidence
          ? now.add(const Duration(hours: 4))
          : null,
    );
    await service.createPrepared(request);
    return (await service.findDetail(missionId: request.mission.id))!;
  }

  Future<void> open(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
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
          analysis: analysis,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
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

  void expectNoAftercare(WidgetTester tester) {
    expect(
      tester
          .widget<MissionDetailContent>(find.byType(MissionDetailContent))
          .materialSection,
      isNull,
    );
    expect(find.byType(AnalysisPanel), findsNothing);
    expect(find.byType(RecordsEntry), findsNothing);
    expect(find.byType(MissionEvidenceSection), findsNothing);
    expect(find.byKey(const Key('execution-report-entry')), findsNothing);
  }

  for (final phase in [
    MissionPhase.notStarted,
    MissionPhase.running,
    MissionPhase.paused,
    MissionPhase.reportPending,
  ]) {
    testWidgets('$phase 的方案详情不显示结束后的评价、补记、记录或材料入口', (tester) async {
      var d = await seed(
        fixed: phase == MissionPhase.reportPending,
        start: now.subtract(const Duration(minutes: 30)),
      );
      if (phase != MissionPhase.notStarted) {
        await service.execute(
          service.prepareExecution(detail: d, type: ExecutionEventType.start),
        );
        if (phase == MissionPhase.paused) {
          d = (await service.findDetail(missionId: d.mission.id))!;
          await service.execute(
            service.prepareExecution(detail: d, type: ExecutionEventType.pause),
          );
        }
        if (phase == MissionPhase.reportPending) {
          now = now.add(const Duration(hours: 1));
          await service.reconcileScheduledMissions();
        }
      }
      final before = (await service.findDetail(missionId: d.mission.id))!;
      expect(before.phase, phase);
      await open(
        tester,
        MissionDetailPage.fromExecution(
          missionId: d.mission.id,
          missionService: service,
        ),
      );
      expectNoAftercare(tester);
      if (phase != MissionPhase.notStarted) {
        expect(
          find.byKey(const Key('detail-return-execution')),
          findsOneWidget,
        );
      }
      expect(
        (await service.findDetail(missionId: d.mission.id))!.events.length,
        before.events.length,
      );
      await close(tester);
    });
  }

  testWidgets('未来计划不能补记或提前确认完成', (tester) async {
    final d = await seed(fixed: true, start: now.add(const Duration(hours: 2)));
    await open(
      tester,
      MissionDetailPage(missionId: d.mission.id, missionService: service),
    );
    expectNoAftercare(tester);
    expect(find.text('这项任务完成了吗？'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('execution-start')))
          .onPressed,
      isNull,
    );
    await close(tester);
  });

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('整段错过后打开自动确认，默认完成，单次确认不造START $size', (tester) async {
      final d = await seed(fixed: true);
      await open(
        tester,
        MissionDetailPage(missionId: d.mission.id, missionService: service),
        size: size,
      );
      expect(find.text('这项任务完成了吗？'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('retrospective-completed')),
            )
            .selected,
        isTrue,
      );
      expect(find.textContaining('10:00'), findsWidgets);
      expect(
        (await service.findDetail(missionId: d.mission.id))!.events,
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('execution-report-confirm')));
      await tester.pumpAndSettle();
      final saved = (await service.findDetail(missionId: d.mission.id))!;
      expect(saved.phase, MissionPhase.closed);
      expect(saved.events.single.type, ExecutionEventType.end);
      expect(saved.events.single.isRetrospective, isTrue);
      expect(saved.effectiveUserReport!.duration, const Duration(hours: 1));
      expect(saved.effectiveUserReport!.occurrenceDate, '2026-10-31');
      expect(find.byType(MissionEvidenceSection), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byKey(const Key('execution-report-entry')), findsOneWidget);
      expect(
        tester.widget(find.byKey(const Key('execution-report-entry'))),
        isA<AppSettingsRow>(),
      );
      expect(find.byKey(const Key('execution-makeup')), findsNothing);
      await close(tester);
    });
  }

  testWidgets('稍后处理不保存事实，返回详情仍可确认、改期或现在补做', (tester) async {
    final d = await seed(fixed: true);
    await open(
      tester,
      MissionDetailPage(missionId: d.mission.id, missionService: service),
    );
    await tester.tap(find.text('稍后处理'));
    await tester.pumpAndSettle();
    expect(find.text('这项任务完成了吗？'), findsNothing);
    expect(find.byKey(const Key('execution-report-entry')), findsOneWidget);
    expect(find.byKey(const Key('execution-makeup')), findsOneWidget);
    expect(find.byKey(const Key('execution-start')), findsNothing);
    expect(find.text('改期 / 修改任务'), findsOneWidget);
    expect(
      (await service.findDetail(missionId: d.mission.id))!.events,
      isEmpty,
    );
    await tester.tap(find.byKey(const Key('execution-makeup')));
    await tester.pumpAndSettle();
    expect(
      (await service.findDetail(missionId: d.mission.id))!.phase,
      MissionPhase.running,
    );
    expect(find.byType(MissionExecutionPage), findsOneWidget);
    await close(tester);
  });

  testWidgets('未执行确认不保存计划时段作为实际时长', (tester) async {
    final d = await seed(fixed: true);
    await open(
      tester,
      MissionDetailPage(missionId: d.mission.id, missionService: service),
    );
    await tester.tap(find.byKey(const Key('retrospective-not-completed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('execution-report-confirm')));
    await tester.pumpAndSettle();
    final saved = (await service.findDetail(missionId: d.mission.id))!;
    expect(
      saved.events.single.userReportedResult,
      UserReportedResult.notCompleted,
    );
    expect(saved.effectiveUserReport!.duration, isNull);
    expect(saved.phase, MissionPhase.closed);
    await tester.tap(find.byKey(const Key('execution-report-entry')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('execution-report-time-summary')))
          .data,
      contains('具体时段未知'),
    );
    expect(find.byKey(const Key('retrospective-completed')), findsNothing);
    expect(
      (await service.findDetail(missionId: d.mission.id))!.events.single.id,
      saved.events.single.id,
    );
    await close(tester);
  });

  testWidgets('强制材料任务确认后进入待补材料，补记入口变为时间更正', (tester) async {
    final d = await seed(
      fixed: true,
      policy: VerificationPolicy.requiredEvidence,
    );
    await open(
      tester,
      MissionDetailPage(missionId: d.mission.id, missionService: service),
    );
    await tester.tap(find.byKey(const Key('execution-report-confirm')));
    await tester.pumpAndSettle();
    final saved = (await service.findDetail(missionId: d.mission.id))!;
    expect(saved.phase, MissionPhase.evidencePending);
    expect(find.byType(MissionEvidenceSection), findsOneWidget);
    expect(find.text('更正实际日期 / 时段'), findsOneWidget);
    expect(find.byKey(const Key('retrospective-completed')), findsNothing);
    await close(tester);
  });

  testWidgets('确认期间其他入口启动任务，旧确认被拒绝且不会结束执行', (tester) async {
    final d = await seed(fixed: true);
    await open(
      tester,
      MissionDetailPage(missionId: d.mission.id, missionService: service),
    );
    await service.startMakeup(d, 'other-entry-start');
    await tester.tap(find.byKey(const Key('execution-report-confirm')));
    await tester.pumpAndSettle();
    final saved = (await service.findDetail(missionId: d.mission.id))!;
    expect(saved.phase, MissionPhase.running);
    expect(saved.events, hasLength(1));
    expect(saved.userReports, isEmpty);
    expect(find.textContaining('任务已变化'), findsOneWidget);
    await close(tester);
  });

  testWidgets('停留详情跨过计划结束边界时出现待确认入口，不自动保存完成', (tester) async {
    now = DateTime.utc(2026, 10, 31, 2, 59, 59);
    final d = await seed(fixed: true);
    await open(
      tester,
      MissionDetailPage(missionId: d.mission.id, missionService: service),
    );
    expect(find.text('这项任务完成了吗？'), findsNothing);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('这项任务完成了吗？'), findsOneWidget);
    expect(
      (await service.findDetail(missionId: d.mission.id))!.events,
      isEmpty,
    );
    await close(tester);
  });

  testWidgets('窄屏大字展开补记表单后仍能滚动确认，键盘不引起溢出', (tester) async {
    final d = await seed(fixed: true);
    await open(
      tester,
      MissionDetailPage(missionId: d.mission.id, missionService: service),
      size: const Size(320, 640),
      scale: 1.4,
    );
    await tester.ensureVisible(find.text('修改日期、时段或补充说明'));
    await tester.tap(find.text('修改日期、时段或补充说明'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('execution-report-confirm'));
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(
      (await service.findDetail(missionId: d.mission.id))!.endReportedCompleted,
      isTrue,
    );
    await close(tester);
  });

  testWidgets('自选任务在排期时区跨日后才进入补记确认', (tester) async {
    now = DateTime.utc(2026, 10, 31, 15, 59, 59);
    final d = await seed();
    await open(
      tester,
      MissionDetailPage(missionId: d.mission.id, missionService: service),
    );
    expect(find.text('这项任务完成了吗？'), findsNothing);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('这项任务完成了吗？'), findsOneWidget);
    expect(find.textContaining('2026-10-31 · 具体时段未知'), findsOneWidget);
    await tester.tap(find.byKey(const Key('execution-report-confirm')));
    await tester.pumpAndSettle();
    final saved = (await service.findDetail(missionId: d.mission.id))!;
    expect(saved.effectiveUserReport!.occurrenceDate, '2026-10-31');
    expect(saved.effectiveUserReport!.duration, isNull);
    expect(saved.events.single.isRetrospective, isTrue);
    await close(tester);
  });
}
