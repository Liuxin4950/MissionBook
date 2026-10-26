import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
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
    await goals.setGoalStatus(goal, GoalStatus.paused);
    await tester.pumpAndSettle();
    final goalStat = find.byKey(const ValueKey('profile-stat-进行中目标'));
    await tester.ensureVisible(goalStat);
    expect(tester.widget<Text>(goalStat).data, '0 个');
  });
}
