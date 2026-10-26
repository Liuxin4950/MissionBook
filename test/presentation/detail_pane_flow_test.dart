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
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/presentation/goals/list/goals_page.dart';
import 'package:mission_book/presentation/missions/shared/mission_phase_icon.dart';
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
      clock: () => now,
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
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    expect(finder, findsOneWidget, reason: '操作前应存在唯一入口：$key');
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

  testWidgets('上海跨年仍按注入时钟查询今天，不使用宿主日期或UTC日期', (tester) async {
    // UTC 仍是上一年；页面必须展示上海已经进入的 2032-01-01。
    now = DateTime.utc(2031, 12, 31, 16, 5);
    await missions.create(
      title: '跨年任务',
      scheduledDate: '2032-01-01',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
    );
    final nextYearMission = (await missions.findScheduledOn(
      scheduledDate: '2032-01-01',
    )).single;
    await open(tester, width: 1280);
    expect(find.byKey(Key('mission-$missionId')), findsNothing);
    await tapKey(tester, 'mission-${nextYearMission.mission.id}');
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.text('跨年任务'), findsWidgets);
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

  testWidgets('宽屏结束后不退出右栏，今天立即显示已结束并移除当前任务', (tester) async {
    await open(tester, width: 1280);
    await tapKey(tester, 'mission-$missionId');
    await tapKey(tester, 'execution-start');
    now = now.add(const Duration(minutes: 3));
    await tapKey(tester, 'execution-end');
    await tapKey(tester, 'report-completed');
    await tapKey(tester, 'report-confirm');
    final row = find.byKey(Key('mission-$missionId'));
    expect(
      find.descendant(of: row, matching: find.textContaining('已结束')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<MissionPhaseIcon>(
            find.descendant(of: row, matching: find.byType(MissionPhaseIcon)),
          )
          .phase,
      MissionPhase.closed,
    );
    expect(find.byKey(const Key('active-mission')), findsNothing);
    expect(
      (await missions.findDetail(missionId: missionId))!.phase,
      MissionPhase.closed,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('宽屏点击主导航会关闭旧面板，目标立即出现在可见工作区', (tester) async {
    await open(tester, width: 1280);
    await tapKey(tester, 'mission-$missionId');
    await tester.tap(find.byTooltip('目标'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalsPage), findsOneWidget);
    expect(find.byType(MissionDetailPage), findsNothing);
    expect(
      tester
          .widget<DetailPaneHost>(find.byType(DetailPaneHost))
          .controller
          .hasContent,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('主导航切换先确认草稿，取消不偷换底层页面', (tester) async {
    await open(tester, width: 1280);
    await tapKey(tester, 'mission-$missionId');
    await tapKey(tester, 'edit-mission');
    await tester.enterText(find.byKey(const Key('mission-title')), '导航草稿');
    await tester.tap(find.byTooltip('目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(find.text('导航草稿'), findsOneWidget);
    expect(find.byType(GoalsPage), findsNothing);
    await tester.tap(find.byTooltip('目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalsPage), findsOneWidget);
    expect(
      (await missions.findDetail(missionId: missionId))!.mission.title,
      '验收任务',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('左侧选择另一任务替换右栏，返回不再翻出旧任务', (tester) async {
    await missions.create(
      title: '第二任务',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
    );
    final second = (await missions.findScheduledOn(
      scheduledDate: '2026-10-25',
    )).firstWhere((item) => item.mission.id != missionId);
    await open(tester, width: 1280);
    await tapKey(tester, 'mission-$missionId');
    await tapKey(tester, 'mission-${second.mission.id}');
    final detail = tester.widget<MissionDetailPage>(
      find.byType(MissionDetailPage),
    );
    expect(detail.missionId, second.mission.id);
    final controller = tester
        .widget<DetailPaneHost>(find.byType(DetailPaneHost))
        .controller;
    expect(controller.entries, hasLength(1));
    final background = tester.widget<ColoredBox>(
      find.byKey(const Key('workspace-background')),
    );
    expect(background.color, AppTheme.light.scaffoldBackgroundColor);
    await tapBack(tester);
    expect(find.byType(MissionDetailPage), findsNothing);
    expect(controller.entries, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('当前任务固定在底部，多个暂停任务只在点开后展示，小窗大字体仍可滚动', (tester) async {
    final first = (await missions.findDetail(missionId: missionId))!;
    await missions.execute(
      missions.prepareExecution(detail: first, type: ExecutionEventType.start),
    );
    final running = (await missions.findDetail(missionId: missionId))!;
    await missions.execute(
      missions.prepareExecution(
        detail: running,
        type: ExecutionEventType.pause,
      ),
    );
    await missions.create(
      title: '正在专注的第二项',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
    );
    final second = (await missions.findScheduledOn(
      scheduledDate: '2026-10-25',
    )).firstWhere((item) => item.mission.id != missionId);
    final next = (await missions.findDetail(missionId: second.mission.id))!;
    await missions.execute(
      missions.prepareExecution(detail: next, type: ExecutionEventType.start),
    );
    for (final width in [320.0, 390.0, 768.0, 1280.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = width == 320 ? 2 : 1;
      await open(tester, width: width);
      final bar = tester.getRect(find.byKey(const Key('active-mission')));
      final list = tester.getRect(find.byKey(const Key('today-list')));
      expect(bar.top, greaterThan(list.top + list.height * .5));
      expect(bar.height, lessThan(120));
      expect(find.byType(ExpansionTile), findsNothing);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.tap(find.byKey(const Key('active-missions-picker')));
    await tester.pumpAndSettle();
    expect(find.text('当前任务'), findsOneWidget);
    final paused = find.widgetWithText(ListTile, '验收任务');
    expect(paused, findsOneWidget);
    await tester.tap(paused);
    await tester.pumpAndSettle();
    expect(find.byType(MissionExecutionPage), findsOneWidget);
    expect(
      (await missions.findDetail(missionId: missionId))!.phase,
      MissionPhase.paused,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('切换主导航不能丢失结束报告草稿', (tester) async {
    await open(tester, width: 1280);
    await tapKey(tester, 'mission-$missionId');
    await tapKey(tester, 'execution-start');
    await tapKey(tester, 'execution-end');
    await tapKey(tester, 'report-not-completed');
    await tester.enterText(find.byKey(const Key('report-reason')), '报告草稿');
    await tester.tap(find.byTooltip('目标'));
    await tester.pumpAndSettle();
    expect(find.text('放弃本次报告？'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(find.text('报告草稿'), findsOneWidget);
    expect(find.byType(GoalsPage), findsNothing);
    expect(
      (await missions.findDetail(missionId: missionId))!.phase,
      MissionPhase.paused,
    );
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
