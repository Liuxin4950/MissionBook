import '../support/me_fakes.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_page.dart';
import 'package:mission_book/presentation/missions/execution/mission_execution_page.dart';
import 'package:mission_book/presentation/missions/shared/mission_live_status.dart';
import 'package:mission_book/presentation/missions/record/mission_record_page.dart';

void main() {
  late AppDatabase database;
  late DriftMissionRepository repository;
  late MissionService service;
  late GoalService goals;
  late DateTime now;
  late String missionId;
  setUp(() async {
    now = DateTime.utc(2030, 1, 1, 6);
    database = AppDatabase(executor: NativeDatabase.memory());
    goals = GoalService(DriftGoalRepository(database));
    repository = DriftMissionRepository(database, clock: () => now);
    service = MissionService(repository, clock: () => now);
    final local = tz.TZDateTime.from(now, tz.getLocation('Asia/Shanghai'));
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    await service.create(
      title: '同步任务',
      scheduledDate: date,
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
    );
    missionId = (await service.findScheduledOn(
      scheduledDate: date,
    )).single.mission.id;
  });
  tearDown(() async {
    await goals.dispose();
    await service.dispose();
    await database.close();
  });

  Future<void> open(WidgetTester tester, {Widget? home}) async {
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
        home:
            home ??
            AppShell(
              backupService: TestBackup(),
              device: TestAppDevice(),
              missionService: service,
              goalService: goals,
              clock: () => now,
            ),
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

  Future<void> act(
    ExecutionEventType type, {
    UserReportedResult? report,
  }) async {
    final detail = (await service.findDetail(missionId: missionId))!;
    await service.execute(
      service.prepareExecution(detail: detail, type: type, report: report),
    );
  }

  testWidgets('今天→开始→返回→直接回执行；暂停、恢复、结束同步当前任务和历史', (tester) async {
    await open(tester);
    await tap(tester, 'mission-$missionId');
    expect(find.byKey(const Key('edit-mission')), findsOneWidget);
    expect(find.byKey(const Key('cancel-mission')), findsOneWidget);
    await tap(tester, 'execution-start');
    expect(find.byType(MissionExecutionPage), findsOneWidget);
    expect(find.byType(MissionDetailPage), findsNothing);
    expect(find.byKey(const Key('mission-material-card')), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.textContaining('执行中 · 计划 20 分钟'), findsOneWidget);
    expect(find.byKey(const Key('active-mission')), findsOneWidget);
    await tap(tester, 'mission-$missionId');
    expect(find.byType(MissionExecutionPage), findsOneWidget);
    expect((await repository.findDetail(missionId))!.events, hasLength(1));
    final originalExecutionState = tester.state(
      find.byType(MissionExecutionPage),
    );
    await tester.tap(find.byTooltip('任务详情'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.byKey(const Key('execution-ring')), findsNothing);
    expect(find.byKey(const Key('edit-mission')), findsNothing);
    expect(find.byKey(const Key('cancel-mission')), findsNothing);
    await tap(tester, 'detail-return-execution');
    expect(
      tester.state(find.byType(MissionExecutionPage)),
      same(originalExecutionState),
    );
    expect((await repository.findDetail(missionId))!.events, hasLength(1));
    now = now.add(const Duration(minutes: 2));
    await tap(tester, 'execution-toggle');
    await tap(tester, 'pause-confirm');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已暂停 · 计划 20 分钟'), findsOneWidget);
    await tap(tester, 'active-mission');
    expect(find.text('继续执行'), findsOneWidget);
    await tap(tester, 'execution-toggle');
    now = now.add(const Duration(minutes: 1));
    await tap(tester, 'execution-end');
    await tap(tester, 'report-completed');
    await tap(tester, 'report-confirm');
    expect(find.byType(MissionRecordPage), findsOneWidget);
    expect(find.byKey(const Key('execution-ring')), findsNothing);
    expect(find.byKey(const Key('execution-toggle')), findsNothing);
    expect(find.text('03:00'), findsOneWidget);
    await tester.pump(const Duration(minutes: 10));
    expect(find.text('03:00'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byKey(const Key('active-mission')), findsNothing);
    expect(find.textContaining('已结束 · 计划 20 分钟'), findsOneWidget);
    await tap(tester, 'mission-$missionId');
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.text('行动方案'), findsOneWidget);
    expect(find.text('自选时间'), findsOneWidget);
    expect(find.byType(MissionRecordPage), findsNothing);
    expect(find.byKey(const Key('edit-mission')), findsNothing);
    expect(find.byKey(const Key('cancel-mission')), findsNothing);
    final finishedDetailState = tester.state(find.byType(MissionDetailPage));
    await tap(tester, 'detail-view-record');
    expect(find.byType(MissionRecordPage), findsOneWidget);
    final returnToTask = tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.info_outline))
        .onPressed!;
    returnToTask();
    returnToTask();
    await tester.pumpAndSettle();
    expect(
      tester.state(find.byType(MissionDetailPage)),
      same(finishedDetailState),
    );
    expect(find.byType(MissionDetailPage, skipOffstage: false), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同步任务'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionRecordPage), findsOneWidget);
    expect(find.byKey(const Key('execution-summary')), findsOneWidget);
    final historyRecordState = tester.state(find.byType(MissionRecordPage));
    final openDetails = tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.info_outline))
        .onPressed!;
    openDetails();
    openDetails();
    await tester.pumpAndSettle();
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.text('行动方案'), findsOneWidget);
    expect(find.byKey(const Key('detail-view-record')), findsNothing);
    await tap(tester, 'detail-return-record');
    expect(
      tester.state(find.byType(MissionRecordPage)),
      same(historyRecordState),
    );
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('另一入口提交后今天页立即同步；旧日期的执行任务仍可由当前任务栏找回', (tester) async {
    await open(tester);
    await act(ExecutionEventType.start);
    await tester.pumpAndSettle();
    expect(find.textContaining('执行中 · 计划 20 分钟'), findsOneWidget);
    await act(ExecutionEventType.pause);
    await tester.pumpAndSettle();
    expect(find.textContaining('已暂停 · 计划 20 分钟'), findsOneWidget);
    await service.create(
      title: '跨日任务',
      scheduledDate: '2026-01-01',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 10,
    );
    final old = (await service.findScheduledOn(
      scheduledDate: '2026-01-01',
    )).single;
    final oldDetail = (await service.findDetail(missionId: old.mission.id))!;
    await service.execute(
      service.prepareExecution(
        detail: oldDetail,
        type: ExecutionEventType.start,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('目标'));
    await tester.pumpAndSettle();
    await tap(tester, 'active-mission');
    expect(find.byType(MissionExecutionPage), findsOneWidget);
    expect(find.text('跨日任务'), findsOneWidget);
    expect(find.text('暂停'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('已取消可从历史找回；再次尝试保存新身份，原记录保持取消', (tester) async {
    await service.cancel(missionId: missionId);
    await open(tester);
    await tester.tap(find.byTooltip('历史'));
    await tester.pumpAndSettle();
    await tap(tester, 'history-cancelled');
    await tester.tap(find.text('同步任务'));
    await tester.pumpAndSettle();
    expect(find.text('没有执行记录'), findsOneWidget);
    expect(find.byKey(const Key('execution-ring')), findsNothing);
    await tap(tester, 'mission-retry');
    expect(await database.select(database.missions).get(), hasLength(1));
    await tester.ensureVisible(find.text('创建任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建任务'));
    await tester.pumpAndSettle();
    final rows = await database.select(database.missions).get();
    expect(rows, hasLength(2));
    final retryId = rows.singleWhere((row) => row.id != missionId).id;
    final retry = (await repository.findDetail(retryId))!;
    expect(retry.mission.sourceMissionId, missionId);
    expect(retry.mission.relationType, MissionRelationType.retry);
    expect(retry.phase, MissionPhase.notStarted);
    expect(retry.events, isEmpty);
    expect(retry.failures, isEmpty);
    expect(
      (await repository.findDetail(missionId))!.phase,
      MissionPhase.cancelled,
    );
    await tester.tap(find.text('返回原页面'));
    await tester.pumpAndSettle();
    expect(find.text('没有执行记录'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('已结束任务保留完整详情；查看记录再返回保留详情，重试放弃不写新任务', (tester) async {
    await act(ExecutionEventType.start);
    await act(ExecutionEventType.end, report: UserReportedResult.completed);
    await open(
      tester,
      home: MissionDetailPage(missionId: missionId, missionService: service),
    );
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.byType(MissionRecordPage), findsNothing);
    expect(find.byType(MissionExecutionPage), findsNothing);
    expect(find.text('行动方案'), findsOneWidget);
    expect(find.text('已结束'), findsOneWidget);
    expect(find.byKey(const Key('mission-material-card')), findsNothing);
    await tap(tester, 'detail-view-record');
    expect(find.byType(MissionRecordPage), findsOneWidget);
    await tap(tester, 'mission-retry');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionRecordPage), findsOneWidget);
    expect(await database.select(database.missions).get(), hasLength(1));
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(
      (await repository.findDetail(missionId))!.phase,
      MissionPhase.closed,
    );
    expect((await repository.findDetail(missionId))!.events, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('阅读只读详情期间其它入口结束，返回原执行实例后正确进入记录而不替错路由', (tester) async {
    await act(ExecutionEventType.start);
    await open(tester);
    await tap(tester, 'active-mission');
    await tester.tap(find.byTooltip('任务详情'));
    await tester.pumpAndSettle();
    await act(ExecutionEventType.end, report: UserReportedResult.completed);
    await tester.pumpAndSettle();
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.text('已结束'), findsOneWidget);
    await tap(tester, 'detail-return-execution');
    expect(find.byType(MissionRecordPage), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byKey(const Key('active-mission')), findsNothing);
    expect((await repository.findDetail(missionId))!.events, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('外部结束同步保留过期报告草稿，禁止二次END，放弃后才看真实记录', (tester) async {
    await open(
      tester,
      home: MissionDetailPage(missionId: missionId, missionService: service),
    );
    await tap(tester, 'execution-start');
    await tap(tester, 'execution-end');
    await tap(tester, 'report-not-completed');
    await tester.enterText(find.byKey(const Key('report-reason')), '尚未保存的输入');
    await act(ExecutionEventType.end, report: UserReportedResult.completed);
    await tester.pumpAndSettle();
    expect(find.text('尚未保存的输入'), findsOneWidget);
    expect(find.byType(MissionRecordPage), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('report-confirm')))
          .onPressed,
      isNull,
    );
    expect((await repository.findDetail(missionId))!.events, hasLength(3));
    await tap(tester, 'report-cancel');
    await tester.tap(find.text('放弃报告'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionRecordPage), findsOneWidget);
    expect(find.text('用户报告：已完成'), findsOneWidget);
    expect((await repository.findDetail(missionId))!.failures, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('实时标签从事实计算；隐藏停止刷新，恢复追上时钟，暂停后保持不变', (tester) async {
    final events = [
      ExecutionEvent(
        id: 'live-start',
        missionId: missionId,
        sequence: 1,
        type: ExecutionEventType.start,
        occurredAt: now,
        scheduleRevisionId: 'plan',
      ),
    ];
    final started = now;
    var visible = true;
    var phase = MissionPhase.running;
    var reads = 0;
    late StateSetter update;
    await open(
      tester,
      home: StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return Scaffold(
            body: TickerMode(
              enabled: visible,
              child: MissionLiveStatus(
                phase: phase,
                events: events,
                clock: () {
                  reads++;
                  return now;
                },
              ),
            ),
          );
        },
      ),
    );
    now = started.add(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('执行中 · 专注 00:15'), findsOneWidget);
    update(() => visible = false);
    await tester.pump();
    final hiddenReads = reads;
    now = started.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 10));
    expect(reads, hiddenReads);
    update(() => visible = true);
    await tester.pump();
    expect(find.text('执行中 · 专注 02:00'), findsOneWidget);
    events.add(
      ExecutionEvent(
        id: 'live-pause',
        missionId: missionId,
        sequence: 2,
        type: ExecutionEventType.pause,
        occurredAt: now,
      ),
    );
    update(() => phase = MissionPhase.paused);
    await tester.pump();
    now = now.add(const Duration(hours: 1));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('已暂停 · 专注 02:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
