import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/settings/app_device.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/goal.dart';
import 'package:mission_book/presentation/me/me_page.dart';
import '../support/me_fakes.dart';
import '../data/repositories/mission_cancellation_test.dart' show seedMission;

class _Device extends TestAppDevice {
  bool fail = false;
  bool failRead = false;
  @override
  Future<LocalProfile> readProfile() async {
    if (failRead) throw StateError('读取失败');
    return super.readProfile();
  }

  int saves = 0;
  Completer<void>? pending;
  @override
  Future<void> saveProfile(LocalProfile value) async {
    saves++;
    if (fail) throw StateError('保存失败');
    await pending?.future;
    await super.saveProfile(value);
  }
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late _Device device;
  late DateTime now;
  late DriftMissionRepository repository;
  setUp(() {
    now = DateTime.utc(2026, 10, 23, 6);
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftMissionRepository(db, clock: () => now);
    missions = MissionService(repository, clock: () => now);
    goals = GoalService(DriftGoalRepository(db));
    device = _Device();
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    Size size = const Size(390, 1000),
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: MePage(
            device: device,
            backup: TestBackup(),
            missions: missions,
            goals: goals,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('个人主页从右上角进入设置，返回保留主页；资料保存后重开仍可读取', (tester) async {
    await open(tester);
    expect(find.text('本机使用者'), findsOneWidget);
    expect(find.text('提醒与权限'), findsNothing);
    await tap(tester, 'me-settings');
    expect(find.text('提醒与权限'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('本机使用者'), findsOneWidget);
    await tap(tester, 'profile-edit');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('profile-name-input')),
        matching: find.byType(TextFormField),
      ),
      '小林',
    );
    await tap(tester, 'profile-save');
    expect(find.text('小林'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(find.text('小林'), findsOneWidget);
  });

  testWidgets('保存失败保留资料草稿，保存期间阻止重复提交及返回', (tester) async {
    await open(tester, scale: 2);
    await tap(tester, 'profile-edit');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('profile-name-input')),
        matching: find.byType(TextFormField),
      ),
      '修改后的称呼',
    );
    device.fail = true;
    await tap(tester, 'profile-save');
    expect(find.text('资料保存失败，输入已保留，请重试'), findsOneWidget);
    expect(device.profile.name, '本机使用者');
    device.fail = false;
    device.pending = Completer<void>();
    await tap(tester, 'profile-save');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('编辑本机资料'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('profile-save')))
          .onPressed,
      isNull,
    );
    expect(device.saves, 2);
    device.pending!.complete();
    await tester.pumpAndSettle();
    expect(device.profile.name, '修改后的称呼');
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统返回保护资料草稿，放弃不保存', (tester) async {
    await open(tester);
    await tap(tester, 'profile-edit');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('profile-name-input')),
        matching: find.byType(TextFormField),
      ),
      '未保存',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('未保存'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.text('编辑本机资料'), findsNothing);
    expect(device.saves, 0);
  });

  testWidgets('概览读取真实目标及END专注，未结束任务不混入累计专注；变更后刷新', (tester) async {
    final goal = goals.prepareCreation(title: '真实目标');
    await goals.create(goal);
    await seedMission(repository, 'done');
    var detail = (await missions.findDetail(missionId: 'done'))!;
    await missions.execute(
      missions.prepareExecution(detail: detail, type: ExecutionEventType.start),
    );
    now = now.add(const Duration(minutes: 5));
    detail = (await missions.findDetail(missionId: 'done'))!;
    await missions.execute(
      missions.prepareExecution(
        detail: detail,
        type: ExecutionEventType.end,
        report: UserReportedResult.completed,
      ),
    );
    await seedMission(repository, 'ongoing');
    final ongoing = (await missions.findDetail(missionId: 'ongoing'))!;
    await missions.execute(
      missions.prepareExecution(
        detail: ongoing,
        type: ExecutionEventType.start,
      ),
    );
    now = now.add(const Duration(minutes: 10));
    await open(tester);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('profile-stat-进行中目标')))
          .data,
      '1 个',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('profile-stat-已结束任务')))
          .data,
      '1 项',
    );
    final focus = find.byKey(const ValueKey('profile-stat-累计专注'));
    await tester.ensureVisible(focus);
    expect(tester.widget<Text>(focus).data, '5 分钟');
    final record = find.byKey(const ValueKey('profile-record-done'));
    expect(record, findsOneWidget);
    expect(find.byKey(const ValueKey('profile-record-ongoing')), findsNothing);
    await tester.ensureVisible(record);
    await tester.pumpAndSettle();
    await tester.tap(record);
    await tester.pumpAndSettle();
    expect(find.text('执行记录'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await goals.setGoalStatus(goal, GoalStatus.paused);
    await tester.pumpAndSettle();
    final goalStat = find.byKey(const ValueKey('profile-stat-进行中目标'));
    await tester.ensureVisible(goalStat);
    expect(tester.widget<Text>(goalStat).data, '0 个');
  });
  testWidgets('空态使用真实零值，插画尊重减少动画且不重复播报', (tester) async {
    final semantics = tester.ensureSemantics();

    await open(tester, reduceMotion: true);
    expect(find.text('我的行动记录'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('profile-stat-进行中目标')))
          .data,
      '0 个',
    );
    expect(
      tester.getSemantics(find.byTooltip('设置')).getSemanticsData().tooltip,
      '设置',
    );
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('profile-card')),
        matching: find.byType(Image),
      ),
    );
    expect(image.excludeFromSemantics, isTrue);
    expect(image.image, isNotNull);
    semantics.dispose();
  });

  testWidgets('个人资料与概览按内容宽度和字体大小重排', (tester) async {
    await open(tester, size: const Size(1200, 1000));
    final profile = find.byKey(const Key('profile-card'));
    final overview = find.byKey(const Key('activity-overview'));
    expect(
      tester.getRect(overview).top,
      greaterThan(tester.getRect(profile).bottom),
    );
    await open(tester, size: const Size(390, 1000), scale: 2);
    expect(
      tester.getRect(overview).top,
      greaterThan(tester.getRect(profile).bottom),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('资料读取失败不冒充默认资料，重试成功后可编辑', (tester) async {
    device.failRead = true;
    await open(tester);
    expect(find.text('本机资料暂时无法读取，请重试'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('profile-edit')))
          .onPressed,
      isNull,
    );
    device.failRead = false;
    await tester.tap(find.text('重新读取资料'));
    await tester.pumpAndSettle();
    expect(find.text('本机使用者'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('profile-edit')))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('设置入口可通过键盘焦点与回车打开', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('提醒与权限'), findsOneWidget);
  });
  testWidgets('行动概览列出真实进行中目标，可打开详情并随状态变更刷新', (tester) async {
    final goal = goals.prepareCreation(title: '真正的目标');
    await goals.create(goal);
    await open(tester, size: const Size(1200, 1000));
    final shortcut = find.byKey(ValueKey('profile-goal-${goal.id}'));
    expect(shortcut, findsOneWidget);
    await tester.ensureVisible(shortcut);
    await tester.pumpAndSettle();
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-edit')), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await goals.setGoalStatus(goal, GoalStatus.paused);
    await tester.pumpAndSettle();
    expect(shortcut, findsNothing);
    expect(find.text('我的行动记录'), findsOneWidget);
  });
}
