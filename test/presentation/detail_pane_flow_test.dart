import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_page.dart';
import 'package:mission_book/presentation/missions/form/mission_form_page.dart';
import 'package:mission_book/presentation/missions/execution/mission_execution_page.dart';
import 'package:mission_book/presentation/widgets/detail_pane.dart';
import 'package:mission_book/application/notifications/app_notification_service.dart';
import 'package:mission_book/data/notifications/notification_dispatcher.dart';
import 'package:mission_book/data/notifications/reminder_store.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/notifications/reminder_request.dart';
import '../support/me_fakes.dart';

/// Phase 2 验收闸口：右栏导航链（列表 → 详情 → 编辑 → 保存 → 返回）
/// 在宽屏/窄屏两载体下业务结果一致，缩放迁移不丢页面。
void main() {
  late AppDatabase database;
  late MissionService missions;
  late GoalService goals;
  late DateTime now;
  late String missionId;

  setUp(() async {
    now = DateTime.utc(2026, 10, 25, 0);
    database = AppDatabase(executor: NativeDatabase.memory());
    goals = GoalService(DriftGoalRepository(database));
    missions = MissionService(
      DriftMissionRepository(database, clock: () => now),
    );
    await missions.create(
      title: '验收任务',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    missionId = (await missions.findScheduledOn(
      scheduledDate: '2026-10-25',
    )).single.mission.id;
  });
  tearDown(() async {
    await goals.dispose();
    await missions.dispose();
    await database.close();
  });

  Future<void> open(
    WidgetTester tester, {
    required double width,
    AppNotificationService? notifications,
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
        home: AppShell(
          missionService: missions,
          goalService: goals,
          backupService: TestBackup(),
          device: TestAppDevice(),
          notifications: notifications,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
  }

  testWidgets('宽屏右栏：列表→详情→编辑→保存→返回，结果与 push 载体一致', (tester) async {
    await open(tester, width: 1280);
    await tapKey(tester, 'mission-$missionId');
    // 真正进入嵌套右栏：左侧列表和导航同时保留，不能回退成全屏push。
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.byTooltip('今天'), findsOneWidget);
    final host = tester.widget<DetailPaneHost>(find.byType(DetailPaneHost));
    expect(host.controller.hasContent, isTrue);
    expect(host.controller.entries.single.label, '任务详情');
    final listBounds = tester.getRect(find.byKey(const Key('today-list')));
    final detailBounds = tester.getRect(find.byType(MissionDetailPage));
    expect(listBounds.width, greaterThanOrEqualTo(480));
    expect(detailBounds.width, inInclusiveRange(360, 640));
    expect(listBounds.right, lessThan(detailBounds.left));
    await tapKey(tester, 'edit-mission');
    expect(find.byType(MissionFormPage), findsOneWidget);
    await tester.enterText(find.byKey(const Key('mission-title')), '验收任务改');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    // 保存结果回传：返回链回到详情并显示新标题。
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.text('验收任务改'), findsWidgets);
    await tapBack(tester);
    // 返回链走空后外壳恢复，导航回归。
    expect(find.byTooltip('今天'), findsOneWidget);
    final saved = (await missions.findDetail(missionId: missionId))!;
    expect(saved.mission.title, '验收任务改');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('右栏表单未保存时返回先确认，取消保留草稿，放弃才离开', (tester) async {
    await open(tester, width: 1280);
    await tapKey(tester, 'mission-$missionId');
    await tapKey(tester, 'edit-mission');
    await tester.enterText(find.byKey(const Key('mission-title')), '未保存草稿');
    await tester.pumpAndSettle();
    await tapBack(tester);
    // 未保存确认出现：继续填写保留草稿。
    expect(find.text('放弃本次修改？'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionFormPage), findsOneWidget);
    expect(find.text('未保存草稿'), findsOneWidget);
    await tapBack(tester);
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionFormPage), findsNothing);
    // 放弃后原任务不变。
    final saved = (await missions.findDetail(missionId: missionId))!;
    expect(saved.mission.title, '验收任务');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窗口缩放只换载体：右栏栈原样保留，返回链和页面身份不丢', (tester) async {
    await open(tester, width: 1280);
    await tapKey(tester, 'mission-$missionId');
    await tapKey(tester, 'edit-mission');
    await tester.enterText(find.byKey(const Key('mission-title')), '缩放保留');
    await tester.pumpAndSettle();
    final originalFormState = tester.state(find.byType(MissionFormPage));
    // 1280（并排）→ 390（全屏接管）：同一个表单实例，草稿还在。
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byType(MissionFormPage), findsOneWidget);
    expect(find.text('缩放保留'), findsOneWidget);
    expect(tester.state(find.byType(MissionFormPage)), same(originalFormState));
    // 390 → 1280：仍然是同一个表单，未重建。
    tester.view.physicalSize = const Size(1280, 844);
    await tester.pumpAndSettle();
    expect(find.byType(MissionFormPage), findsOneWidget);
    expect(find.text('缩放保留'), findsOneWidget);
    expect(tester.state(find.byType(MissionFormPage)), same(originalFormState));
    await tapBack(tester);
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏全屏接管：链路与宽屏一致，子页不复制底部导航', (tester) async {
    await open(tester, width: 390);
    await tapKey(tester, 'mission-$missionId');
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.byTooltip('今天'), findsNothing);
    await tapBack(tester);
    expect(find.byTooltip('今天'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('替换或清空右栏不能绕过未保存表单守卫', (tester) async {
    await open(tester, width: 1280);
    await tapKey(tester, 'mission-$missionId');
    await tapKey(tester, 'edit-mission');
    await tester.enterText(find.byKey(const Key('mission-title')), '保留的草稿');
    await tester.pumpAndSettle();
    final controller = tester
        .widget<DetailPaneHost>(find.byType(DetailPaneHost))
        .controller;
    for (final replace in [DetailPaneReplace.top, DetailPaneReplace.all]) {
      final result = controller.open<void>(
        DetailPaneEntry('其他任务', (_) => const Scaffold(body: Text('替换目标'))),
        replace: replace,
      );
      result.ignore();
      await tester.pumpAndSettle();
      expect(find.text('放弃本次修改？'), findsOneWidget);
      await tester.tap(find.text('继续填写'));
      await tester.pumpAndSettle();
      expect(find.text('保留的草稿'), findsOneWidget);
      expect(find.text('替换目标'), findsNothing);
      expect(controller.entries, hasLength(2));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('通知服务晚于外壳挂载仍能接收停止意图', (tester) async {
    final dir = Directory.systemTemp.createTempSync('shell_notification_fix_');
    final notifications = AppNotificationService(
      missions: missions,
      store: ReminderStore(File('${dir.path}/reminders.json')),
      dispatcher: const UnsupportedNotificationDispatcher(),
      now: () => now,
    );
    addTearDown(() async {
      await tester.runAsync(notifications.dispose);
      dir.deleteSync(recursive: true);
    });
    final before = (await missions.findDetail(missionId: missionId))!;
    await missions.execute(
      missions.prepareExecution(detail: before, type: ExecutionEventType.start),
    );
    await open(tester, width: 1280);
    await open(tester, width: 1280, notifications: notifications);
    final running = (await missions.findDetail(missionId: missionId))!;
    await tester.runAsync(
      () => notifications.handleAction(
        ReminderRequest(
          idempotencyKey: 'test-stop',
          notificationId: 88,
          missionId: missionId,
          scheduleRevisionId: running.schedule.id,
          kind: ReminderKind.executionRunning,
          title: '',
          body: '',
          expectedSequence: running.lastSequence,
          candidateEventIds: const {'pause': 'test-pause'},
        ),
        actionId: 'stop',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MissionExecutionPage), findsOneWidget);
    final paused = await tester.runAsync(
      () => missions.findDetail(missionId: missionId),
    );
    expect(paused!.phase.name, 'paused');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
