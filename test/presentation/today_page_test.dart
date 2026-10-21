import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/create_mission.dart';
import 'package:mission_book/application/get_scheduled_missions.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:mission_book/domain/repositories/mission_repository.dart';
import 'package:mission_book/presentation/today/today_page.dart';
import 'package:timezone/timezone.dart' as tz;

// 每次读取都有独立 Future，用来控制等待、失败、重试和乱序返回。
class ControlledQueryRepository implements MissionRepository {
  final dates = <String>[];
  final requests = <Completer<List<ScheduledMission>>>[];

  @override
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate) {
    dates.add(scheduledDate);
    final request = Completer<List<ScheduledMission>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  }) => throw UnsupportedError('查询状态测试不保存任务');
}

Widget testApp(MissionRepository repository, {bool shell = false}) {
  final create = CreateMission(repository);
  final getMissions = GetScheduledMissions(repository);
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: shell
        ? AppShell(createMission: create, getMissions: getMissions)
        : Scaffold(
            body: TodayPage(createMission: create, getMissions: getMissions),
          ),
  );
}

ScheduledMission example(
  String id, {
  bool fixed = false,
  bool cancelled = false,
}) {
  final now = DateTime.utc(2026, 10, 21);
  return ScheduledMission(
    mission: Mission(
      id: id,
      title: id,
      createdAt: now,
      updatedAt: now,
      cancelledAt: cancelled ? now : null,
    ),
    schedule: MissionScheduleRevision(
      id: '$id-schedule',
      missionId: id,
      revisionNumber: 1,
      scheduledDate: '2026-10-21',
      timeZone: 'Asia/Shanghai',
      timePolicy: fixed ? TimePolicy.fixed : TimePolicy.flexible,
      fixedStartAt: fixed ? DateTime.utc(2026, 10, 21, 1) : null,
      plannedDurationMinutes: 20,
      changedAt: now,
    ),
  );
}

void main() {
  testWidgets('真实创建保存后返回今天页，返回时刷新且只出现一次；导航切换保留列表', (tester) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final repository = DriftMissionRepository(database);
    await tester.pumpWidget(testApp(repository, shell: true));
    await tester.pumpAndSettle();
    expect(find.text('这一天还没有任务'), findsOneWidget);

    await tester.tap(find.byTooltip('创建任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '真实阅读任务');
    await tester.enterText(find.byType(TextField).at(2), '20');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('任务已创建，可返回今天页'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('真实阅读任务'), findsOneWidget);
    expect(find.text('自选时间'), findsOneWidget);
    expect(find.text('计划 20 分钟'), findsOneWidget);
    // SQLite 的真实异步工作在真实时钟区等待，避免被 Widget 测试的假时钟挂起。
    final stored = await tester.runAsync(
      () => database.select(database.missions).get(),
    );
    expect(stored, hasLength(1));

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('今天'));
    await tester.pumpAndSettle();
    expect(find.text('真实阅读任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    // 先发起关闭，再推进 Widget 测试的异步任务。
    final closing = database.close();
    await tester.pumpAndSettle();
    await closing;
  });

  testWidgets('加载失败可重新查询，重试成功显示空列表', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.requests.first.completeError(StateError('模拟读取失败'));
    await tester.pumpAndSettle();
    expect(find.text('任务加载失败，请重试'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    await tester.pump();
    expect(repository.requests, hasLength(2));
    repository.requests.last.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('这一天还没有任务'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('下拉才再次读取，空列表也可以下拉刷新', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([]);
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(1));
    await tester.drag(
      find.byKey(const Key('today-list')),
      const Offset(0, 400),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(repository.requests, hasLength(2));
    repository.requests.last.complete([example('下拉刷新的任务')]);
    await tester.pumpAndSettle();
    expect(find.text('下拉刷新的任务'), findsOneWidget);
    // 普通 build 不会重新查询，避免重建页面带来重复读取。
    await tester.pump();
    expect(repository.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏长标题可滚动；固定时间按上海显示，取消任务默认折叠', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([
      example('固定任务', fixed: true),
      example('固定任务的长标题用于检查换行后时间轴仍然连续而不是出现断线', fixed: true),
      example('最后一个固定任务', fixed: true),
      example('很长的自选任务标题需要能够自动换行而不是发生水平溢出'),
      example('取消的任务', cancelled: true),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('09:00'), findsNWidgets(3));
    expect(find.text('计划日程'), findsOneWidget);
    final firstRail = tester.getRect(
      find.byKey(const ValueKey('timeline-rail-固定任务')),
    );
    final middleRail = tester.getRect(
      find.byKey(const ValueKey('timeline-rail-固定任务的长标题用于检查换行后时间轴仍然连续而不是出现断线')),
    );
    final lastRail = tester.getRect(
      find.byKey(const ValueKey('timeline-rail-最后一个固定任务')),
    );
    // 连接列沿同一条竖轴铺满每个变高行，相邻轨道没有布局空隙。
    expect(firstRail.center.dx, middleRail.center.dx);
    expect(middleRail.center.dx, lastRail.center.dx);
    expect(firstRail.bottom, closeTo(middleRail.top, 0.01));
    expect(middleRail.bottom, closeTo(lastRail.top, 0.01));
    expect(middleRail.height, greaterThan(firstRail.height));
    expect(find.text('取消的任务'), findsNothing);
    await tester.ensureVisible(find.text('已取消（1）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已取消（1）'));
    await tester.pumpAndSettle();
    expect(find.text('取消的任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('切日期清除旧结果，迟到请求不能覆盖新日期，新建沿用所选日期', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    // 初次查询先不返回，模拟它比用户切日期后的查询更慢。
    final now = tz.TZDateTime.now(tz.getLocation('Asia/Shanghai'));
    final day = now.day == 1 ? 2 : 1;
    await tester.tap(find.byKey(const Key('today-date-picker')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('$day').last);
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.dates, hasLength(2));
    repository.requests.last.complete([example('新日期任务')]);
    await tester.pumpAndSettle();
    repository.requests.first.complete([example('旧请求的过期任务')]);
    await tester.pumpAndSettle();
    expect(find.text('新日期任务'), findsOneWidget);
    expect(find.text('旧请求的过期任务'), findsNothing);
    expect(
      repository.dates.last.endsWith('-${day.toString().padLeft(2, '0')}'),
      isTrue,
    );
    await tester.tap(find.byTooltip('创建任务'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      repository.dates.last,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
