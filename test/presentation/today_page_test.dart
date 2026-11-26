import '../support/unused_mission_writes.dart';
import '../support/me_fakes.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/domain/entities/execution_command.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;
import 'package:flutter/semantics.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/domain/entities/goal.dart';
import 'package:mission_book/domain/repositories/goal_repository.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_page.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:mission_book/domain/repositories/mission_repository.dart';
import 'package:mission_book/presentation/today/schedule_section.dart';
import 'package:mission_book/presentation/today/today_page.dart';
import 'package:mission_book/presentation/missions/all/all_missions_page.dart';
import 'package:mission_book/presentation/missions/all/mission_timetable.dart';
import 'package:mission_book/presentation/widgets/app_illustration.dart';
import 'package:mission_book/presentation/missions/form/mission_form_page.dart';
import 'package:timezone/timezone.dart' as tz;

// 每次读取都有独立 Future，用来控制等待、失败、重试和乱序返回。
class ControlledQueryRepository
    with UnusedMissionWrites
    implements MissionRepository {
  @override
  Future<List<String>> reconcileScheduledEnds() async => [];

  @override
  Future<List<String>> reconcileScheduledMissions() async => <String>[];

  @override
  Future<List<MissionGoalChoices>> findGoalChoices() async => [];
  @override
  Future<MissionOwnershipInfo?> findOwnershipInfo(
    MissionOwnership ownership,
  ) async => null;
  @override
  Future<List<MissionDetail>> findForGoal(String goalId) async => [];

  @override
  Future<ExecutionEvent> execute(ExecutionCommand command) =>
      throw UnsupportedError('本替身不执行任务');
  @override
  Future<List<MissionDetail>> findActive() async => [];
  @override
  Future<List<MissionDetail>> findFinished() async => [];
  @override
  Future<List<MissionDetail>> findAllDetails() async => [];
  @override
  Future<List<MissionDetail>> findCancelled() async => [];
  @override
  Future<List<MissionDetail>> findPendingEvidence() async => [];
  @override
  Future<int> reconcileEvidenceDeadlines() async => 0;
  @override
  Future<Set<String>> referencedAttachmentKeys() async => {};
  @override
  Future<EvidenceSubmissionResult> submitEvidence(
    EvidenceSubmission submission,
  ) => throw UnsupportedError('本替身不提交材料');
  @override
  Future<Evidence> correctEvidence(EvidenceCorrection correction) =>
      throw UnsupportedError('本替身不修正材料');
  @override
  Future<void> skipOptionalEvidence(String missionId) =>
      throw UnsupportedError('本替身不跳过材料');

  @override
  Future<void> edit({
    required MissionDetail original,
    required String title,
    required String objective,
    required MissionScheduleRevision schedule,
    ExecutionPlanContent? content,
    VerificationPolicy? verificationPolicy,
    String? verificationCriteria,
    MissionOwnership? ownership,
    String? description,
    String? why,
    bool updateContext = false,
    String? location,
    bool updateLocation = false,
    String? operationId,
  }) => throw UnsupportedError('本测试不编辑任务');

  @override
  Future<void> cancel(String missionId, {String? operationId}) =>
      throw UnsupportedError('列表查询替身不取消任务');

  // 列表测试默认不会进入详情；导航测试可指定要返回的完整结果。
  MissionDetail? detail;
  final detailIds = <String>[];

  @override
  Future<MissionDetail?> findDetail(String missionId) async {
    detailIds.add(missionId);
    return detail;
  }

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

// 重建组件时仍复用同一服务，与 App 的实际装配一致；换仓储才是换数据源。
final _testServices = Expando<MissionService>();
final _goalServices = Expando<GoalService>();

// 默认在 08:00 读列表，早于样本的 09:00 固定任务；当前时段另有专门用例。
DateTime _todayClock() => DateTime.utc(2026, 10, 21);

// 此文件只验收任务列表，目标入口使用明确的空查询替身，不访问用户数据。
class _EmptyGoals implements GoalRepository {
  // 今天页的控制查询测试不会打开目标节点；意外调用应明确失败。
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('本测试不操作目标节点：${invocation.memberName}');

  @override
  Future<void> create(Goal goal) => throw UnsupportedError('本测试不创建目标');
  @override
  Future<List<Goal>> findAll() async => [];
  @override
  Future<Goal?> findById(String id) async => null;
}

Widget testApp(
  MissionRepository repository, {
  bool shell = false,
  DateTime Function()? clock,
}) {
  final effectiveClock = clock ?? _todayClock;
  final missionService = _testServices[repository] ??= MissionService(
    repository,
    clock: effectiveClock,
  );
  if (_goalServices[repository] == null) {
    final goals = GoalService(_EmptyGoals());
    _goalServices[repository] = goals;
    addTearDown(goals.dispose);
  }
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: shell
        ? AppShell(
            backupService: TestBackup(),
            device: TestAppDevice(),
            missionService: missionService,
            goalService: _goalServices[repository]!,
            clock: effectiveClock,
          )
        : Scaffold(
            body: TodayPage(
              missionService: missionService,
              clock: effectiveClock,
            ),
          ),
  );
}

/// 读屏动作可能挂在分组节点，也可能由内部可点节点提供；
/// 这里找到真正带点击动作的语义节点，再断言并派发同一次动作。
SemanticsNode tappableSemanticsNode(SemanticsNode node) {
  if (node.getSemanticsData().hasAction(SemanticsAction.tap)) return node;
  SemanticsNode? found;
  node.visitChildren((child) {
    found ??= tappableSemanticsNode(child);
    return found == null;
  });
  final target = found;
  if (target == null) {
    throw StateError('语义节点 ${node.getSemanticsData().label} 没有读屏点击动作');
  }
  return target;
}

ScheduledMission example(
  String id, {
  String? location,
  bool fixed = false,
  bool cancelled = false,
  DateTime? start,
  int plannedDurationMinutes = 20,
  String timeZone = 'Asia/Shanghai',
  MissionPhase phase = MissionPhase.notStarted,
  List<ExecutionEvent> events = const [],
}) {
  final now = DateTime.utc(2026, 10, 21);
  return ScheduledMission(
    phase: phase,
    events: events,
    mission: Mission(
      id: id,
      title: id,
      location: location,
      createdAt: now,
      updatedAt: now,
      cancelledAt: cancelled ? now : null,
    ),
    schedule: MissionScheduleRevision(
      id: '$id-schedule',
      missionId: id,
      revisionNumber: 1,
      scheduledDate: '2026-10-21',
      timeZone: timeZone,
      timePolicy: fixed ? TimePolicy.fixed : TimePolicy.flexible,
      fixedStartAt: fixed ? start ?? DateTime.utc(2026, 10, 21, 1) : null,
      plannedDurationMinutes: plannedDurationMinutes,
      changedAt: now,
    ),
  );
}

Future<void> chooseMissionAction(WidgetTester tester, String action) async {
  if (find.byKey(Key('$action-mission')).evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('mission-more')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(Key('$action-mission')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('自选任务直接显示地点，无地点隐藏地点行', (tester) async {
    final repo = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repo));
    repo.requests.single.complete([
      example('有地点', location: '图书馆'),
      example('无地点'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('📍 图书馆'), findsOneWidget);
    expect(find.byKey(const ValueKey('mission-location-无地点')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('四个导航项具有读屏点击动作，读屏切页后更新选中状态', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final repository = ControlledQueryRepository();
      await tester.pumpWidget(testApp(repository, shell: true));
      repository.requests.single.complete([]);
      await tester.pumpAndSettle();

      for (final label in ['今天', '目标', '历史', '我的']) {
        // “今天”也出现在页头，所以同时按按钮角色定位导航项。
        final navigationItem = find.byWidgetPredicate((widget) {
          return widget is Semantics &&
              widget.properties.label == label &&
              widget.properties.button == true;
        });
        final node = tester.getSemantics(navigationItem);
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(
          tappableSemanticsNode(
            node,
          ).getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
      }

      // 目标页已接通，页头也有“目标”；按导航按钮角色定位，避免匹配正文标题。
      final goalNavigation = find.byWidgetPredicate((widget) {
        return widget is Semantics &&
            widget.properties.label == '目标' &&
            widget.properties.button == true;
      });
      final target = tester.getSemantics(goalNavigation);
      final actionable = tappableSemanticsNode(target);
      final owner = actionable.owner;
      if (owner == null) {
        throw StateError('导航语义节点尚未挂载');
      }
      // 从语义树派发动作，验证读屏实际走到切页逻辑，而非只检查有一个回调。
      owner.performAction(actionable.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-empty-state')), findsOneWidget);
      expect(
        TickerMode.valuesOf(
          tester.element(find.byType(TodayPage, skipOffstage: false)),
        ).enabled,
        isFalse,
      );
      final selectedTarget = tester.getSemantics(goalNavigation);
      expect(
        selectedTarget.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(repository.requests, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('真实创建、详情取消与返回刷新走完整链路，首页移除但数据库保留任务', (tester) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final repository = DriftMissionRepository(database);
    await tester.pumpWidget(testApp(repository, shell: true));
    await tester.pumpAndSettle();
    // 空数据时两个区域标题常驻，各显示一行空态提示。
    expect(find.text('计划日程'), findsOneWidget);
    expect(find.text('自选时间'), findsOneWidget);
    expect(find.text('这一天还没有固定任务'), findsOneWidget);
    expect(find.text('这一天还没有自选任务'), findsOneWidget);

    await tester.tap(find.byTooltip('创建任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '真实阅读任务');
    await tester.enterText(
      find.byKey(const ValueKey('mission-duration')),
      '20',
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('任务已创建'), findsOneWidget);
    await tester.tap(find.text('返回原页面'));
    await tester.pumpAndSettle();
    expect(find.text('真实阅读任务'), findsOneWidget);
    expect(find.text('自选时间'), findsOneWidget);
    expect(find.text('计划 20 分钟'), findsOneWidget);
    // 标题与默认具体目标同名且没有步骤时省略重复的方案区块，标题只出现一次。
    await Scrollable.ensureVisible(
      tester.element(find.text('真实阅读任务')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('真实阅读任务'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.text('真实阅读任务'), findsOneWidget);
    expect(find.text('20 分'), findsOneWidget);
    expect(find.byTooltip('今天'), findsNothing); // 子页不复制底部导航。
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('真实阅读任务'), findsOneWidget);
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
    // 通过真实详情、业务入口及数据库取消；返回后复用原有日期刷新。
    await tester.tap(find.text('真实阅读任务'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await chooseMissionAction(tester, 'cancel');
    await tester.pumpAndSettle();
    expect(find.text('取消这个任务？'), findsOneWidget);
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    expect(find.text('已取消'), findsOneWidget);
    expect(find.text('没有执行记录'), findsOneWidget);
    expect(find.byKey(const Key('cancel-mission')), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('真实阅读任务'), findsNothing);
    expect(find.byKey(const Key('cancelled-missions')), findsNothing);
    final cancelled = await tester.runAsync(
      () => database.select(database.missions).get(),
    );
    expect(cancelled, hasLength(1));
    expect(cancelled!.single.cancelledAt, isNotNull);
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
    expect(find.text('计划日程'), findsOneWidget);
    expect(find.text('自选时间'), findsOneWidget);
    expect(find.text('这一天还没有固定任务'), findsOneWidget);
    expect(find.text('这一天还没有自选任务'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('固定与自选行按自身编号读取任务，读屏可点击且缺失任务不叠页', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final repository = ControlledQueryRepository();
      final items = [example('固定入口', fixed: true), example('自选入口')];
      await tester.pumpWidget(testApp(repository, shell: true));
      repository.requests.single.complete(items);
      await tester.pumpAndSettle();
      // 先选另一天，验证缺失任务不会重置所选日期。
      final now = tz.TZDateTime.from(
        _todayClock(),
        tz.getLocation('Asia/Shanghai'),
      );
      final day = now.day == 1 ? 2 : 1;
      await tester.tap(find.byKey(const Key('today-date-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$day').last);
      await tester.tap(find.text('确定'));
      // 新日期的受控查询尚未完成，加载指示器会持续动画。
      await tester.pump(const Duration(milliseconds: 400));
      repository.requests.last.complete(items);
      await tester.pumpAndSettle();
      final selectedDate = repository.dates.last;

      for (final item in items) {
        final row = find.byKey(ValueKey('mission-${item.mission.id}'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final timeLabel = item.schedule.timePolicy == TimePolicy.fixed
            ? '09:00'
            : '自选时间';
        // 固定行读屏用页面实际显示的计划状态；自选行仍沿用执行阶段文字。
        final status = item.schedule.timePolicy == TimePolicy.fixed
            ? '待到时'
            : '待开始';
        // 从任务的完整语义标签定位按钮，避免取到时间轴内部的布局节点。
        final node = tester.getSemantics(
          find.bySemanticsLabel(
            '$timeLabel，${item.mission.title}，计划 20 分钟，$status',
          ),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        if (item.mission.id == '固定入口') {
          // 使用实际语义动作，而非只检查回调存在。
          node.owner!.performAction(node.id, SemanticsAction.tap);
          node.owner!.performAction(node.id, SemanticsAction.tap);
        } else {
          await tester.tap(row);
        }
        await tester.pumpAndSettle();
        expect(find.byType(MissionDetailPage), findsNothing);
        expect(repository.detailIds.last, item.mission.id);
        expect(repository.dates.last, selectedDate);
      }
      expect(repository.detailIds, items.map((item) => item.mission.id));
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('区域标题在空数据时仍显示，空固定列表不启动每秒时钟', (tester) async {
    var reads = 0;
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(
      testApp(
        repository,
        clock: () {
          reads++;
          return DateTime.utc(2026, 10, 22, 1);
        },
      ),
    );
    repository.requests.single.complete([example('仅有自选任务')]);
    await tester.pumpAndSettle();
    // 固定区没有任务：标题和“全部任务”入口仍在，列表位置是空态提示。
    expect(find.text('计划日程'), findsOneWidget);
    expect(find.text('这一天还没有固定任务'), findsOneWidget);
    expect(find.textContaining('当日记录'), findsNothing);
    expect(find.text('仅有自选任务'), findsOneWidget);
    expect(find.text('这一天还没有自选任务'), findsNothing);
    // 空固定列表没有时间轴可画，不应进入每秒读取。
    final readsAfterLoad = reads;
    await tester.pump(const Duration(seconds: 3));
    expect(reads, readsAfterLoad);

    // 刷新成只剩取消任务的一天：两个区域仍常驻，不再用整句替换内容。
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('today-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('today-list')),
      const Offset(0, 400),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    repository.requests.last.complete([example('已取消任务', cancelled: true)]);
    await tester.pumpAndSettle();
    expect(find.text('计划日程'), findsOneWidget);
    expect(find.text('自选时间'), findsOneWidget);
    expect(find.textContaining('当日记录'), findsNothing);
    expect(find.text('这一天还没有固定任务'), findsOneWidget);
    expect(find.text('这一天还没有自选任务'), findsOneWidget);
    expect(find.text('这一天没有未取消的任务'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('下拉才再次读取，空列表也可以下拉刷新', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([]);
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(1));
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('today-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await tester.pump();
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
    // 父组件重建后仍显示已加载的数据，不依赖今天页内部的私有组件类型。
    await tester.pumpWidget(testApp(repository));
    expect(find.text('下拉刷新的任务'), findsOneWidget);
    expect(repository.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('空日程下拉刷新保留卡片与插画，失败重试不重播入场：$width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = ControlledQueryRepository();
      await tester.pumpWidget(testApp(repository));
      repository.requests.single.complete([]);
      await tester.pumpAndSettle();
      final illustration = find.byType(AppIllustration);
      expect(illustration, findsOneWidget);
      final originalState = tester.state(illustration);
      final schedule = find.text('这一天还没有固定任务');
      final originalElement = tester.element(schedule);
      await tester.drag(
        find.byKey(const Key('today-list')),
        const Offset(0, 400),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(repository.requests, hasLength(2));
      expect(schedule, findsOneWidget);
      expect(tester.element(schedule), same(originalElement));
      expect(tester.state(illustration), same(originalState));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repository.requests.last.completeError(StateError('模拟刷新失败'));
      await tester.pumpAndSettle();
      expect(find.text('刷新失败，当前显示上次加载的任务'), findsOneWidget);
      expect(tester.element(schedule), same(originalElement));
      expect(tester.state(illustration), same(originalState));
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(tester.state(illustration), same(originalState));
      repository.requests.last.complete([]);
      await tester.pumpAndSettle();
      expect(tester.state(illustration), same(originalState));
      expect(tester.element(schedule), same(originalElement));
      expect(find.text('刷新失败，当前显示上次加载的任务'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('刷新失败保留任务和展开状态，重试成功替换为新快照', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([
      for (var index = 1; index <= 5; index++) example('保留项$index'),
    ]);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('flexible-missions-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flexible-missions-toggle')));
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('today-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('today-list')),
      const Offset(0, 400),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    repository.requests.last.completeError(StateError('刷新失败'));
    await tester.pumpAndSettle();
    expect(find.text('刷新失败，当前显示上次加载的任务'), findsOneWidget);
    expect(find.text('保留项5'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(repository.requests, hasLength(3));
    repository.requests.last.complete([example('最新项')]);
    await tester.pumpAndSettle();
    expect(find.text('最新项'), findsOneWidget);
    expect(find.text('保留项1'), findsNothing);
    expect(find.text('刷新失败，当前显示上次加载的任务'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('快速重复点击只打开一份新建页和日期选择器', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([]);
    await tester.pumpAndSettle();
    final createButton = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '创建任务',
      ),
    );
    createButton.onPressed!();
    createButton.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(MissionFormPage, skipOffstage: false), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.requests, hasLength(2));
    repository.requests.last.complete([]);
    await tester.pumpAndSettle();
    final dateButton = tester.widget<TextButton>(
      find.byKey(const Key('today-date-picker')),
    );
    dateButton.onPressed!();
    dateButton.onPressed!();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('app-date-confirm'), skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('任务读屏一次包含完整名称时长和计划状态，展开按钮提供展开状态', (tester) async {
    final semantics = tester.ensureSemantics();
    final repository = ControlledQueryRepository();
    final start = DateTime.utc(2026, 10, 22, 1);
    const longTitle = '读屏需要保留这个超过一行显示宽度的完整任务名称';
    await tester.pumpWidget(testApp(repository, clock: () => start));
    repository.requests.single.complete([
      example(longTitle, fixed: true, start: start),
      for (var index = 1; index <= 4; index++) example('自选$index'),
    ]);
    await tester.pumpAndSettle();
    final activeNode = tester.getSemantics(
      find.bySemanticsLabel('09:00，$longTitle，计划 20 分钟，当前时段，计划时段剩余 20 分钟'),
    );
    expect(
      activeNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue, // 任务行现在已接通详情入口，读屏也应提供同一个点击动作。
    );
    expect(activeNode.childrenCount, 0);
    expect(
      find.bySemanticsLabel('自选时间，自选1，待处理 · 计划 20 分钟，待开始'),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('计划日程'))
          .getSemanticsData()
          .flagsCollection
          .isHeader,
      isTrue,
    );
    final toggle = find.byKey(const Key('flexible-missions-toggle'));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('展开全部（4）'))
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isFalse,
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('收起'))
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('固定任务只保留计划信息与阶段，去除重复专注计时', (tester) async {
    // 标题优先，辅助行只保留计划信息和真实阶段。
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final repository = ControlledQueryRepository();
    final start = DateTime.utc(2026, 10, 21, 1);
    final events = [
      ExecutionEvent(
        id: 'start',
        missionId: '已结束任务',
        sequence: 1,
        type: ExecutionEventType.start,
        occurredAt: start,
        scheduleRevisionId: '已结束任务-schedule',
      ),
      ExecutionEvent(
        id: 'end',
        missionId: '已结束任务',
        sequence: 2,
        type: ExecutionEventType.end,
        occurredAt: start,
        userReportedResult: UserReportedResult.completed,
      ),
    ];
    await tester.pumpWidget(
      testApp(repository, clock: () => DateTime.utc(2026, 10, 21, 3)),
    );
    repository.requests.single.complete([
      example(
        '已结束任务',
        fixed: true,
        start: start,
        plannedDurationMinutes: 100,
        phase: MissionPhase.closed,
        events: events,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('已结束'), findsOneWidget);
    expect(find.text('09:00–10:40'), findsOneWidget);
    expect(find.textContaining('专注'), findsNothing);
    expect(find.text('00:00'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('计划 100 分钟'), findsNothing);
    expect(find.textContaining('已结束 ·'), findsNothing);
    expect(find.bySemanticsLabel('09:00，已结束任务，计划 100 分钟，已结束'), findsOneWidget);
    final row = tester.getRect(find.byKey(const ValueKey('mission-已结束任务')));
    final title = tester.getRect(find.text('已结束任务'));
    final status = tester.getRect(find.text('已结束'));
    final duration = tester.getRect(find.text('09:00–10:40'));
    // 轨道 16dp 后是标题，辅助行再向内收 8dp。
    expect(title.left - row.left, closeTo(16, 0.5));
    expect(duration.left - title.left, closeTo(8, 0.5));
    expect(duration.top, greaterThan(title.bottom));
    // 时间区间与阶段在辅助行内分开，空间不足时换行。
    if ((status.top - duration.top).abs() < 1) {
      expect(status.left, greaterThanOrEqualTo(duration.right - 1));
    } else {
      expect(status.top, greaterThan(duration.bottom - 1));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('未来固定任务以起止时刻紧凑展示，不重复时长文本', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final repository = ControlledQueryRepository();
    final start = DateTime.utc(2026, 10, 21, 11);
    await tester.pumpWidget(
      testApp(repository, clock: () => DateTime.utc(2026, 10, 21, 3)),
    );
    repository.requests.single.complete([
      example(
        '品牌与营销管理实务',
        fixed: true,
        start: start,
        plannedDurationMinutes: 210,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('待到时'), findsOneWidget);
    expect(find.text('19:00–22:30'), findsOneWidget);
    expect(find.text('计划 210 分钟'), findsNothing);
    expect(find.textContaining('专注'), findsNothing);
    expect(
      find.bySemanticsLabel('19:00，品牌与营销管理实务，计划 210 分钟，待到时'),
      findsOneWidget,
    );
    // 安排概览也会显示同一任务名，这里只量计划日程行内的标题。
    final titleFinder = find.descendant(
      of: find.byType(ScheduleMissionRow),
      matching: find.text('品牌与营销管理实务'),
    );
    final title = tester.getRect(titleFinder);
    final status = tester.getRect(find.text('待到时'));
    final duration = tester.getRect(find.text('19:00–22:30'));
    expect(duration.left - title.left, closeTo(8, 0.5));
    expect(duration.top, greaterThan(title.bottom));
    if ((status.top - duration.top).abs() < 1) {
      expect(status.left, greaterThanOrEqualTo(duration.right - 1));
    } else {
      expect(status.top, greaterThan(duration.bottom - 1));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('隐藏区域停止读时钟，恢复时立即显示最新计划状态且不查库', (tester) async {
    final visible = ValueNotifier(true);
    final repository = ControlledQueryRepository();
    final start = DateTime.utc(2026, 10, 22, 1);
    var now = start;
    var reads = 0;
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, enabled, child) =>
            TickerMode(enabled: enabled, child: child!),
        child: testApp(
          repository,
          clock: () {
            reads++;
            return now;
          },
        ),
      ),
    );
    repository.requests.single.complete([
      example('可见任务', fixed: true, start: start),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-current-time')), findsNothing);
    expect(find.text('当前时段'), findsOneWidget);
    visible.value = false;
    await tester.pump();
    final hiddenReads = reads;
    now = start.add(const Duration(hours: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(reads, hiddenReads);
    visible.value = true;
    await tester.pump();
    expect(find.text('时段已过'), findsOneWidget);
    expect(reads, greaterThan(hiddenReads));
    expect(repository.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    visible.dispose();
  });

  testWidgets('自选折叠先显示未开始，执行结束后的刷新会让待做任务前移', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([
      for (var index = 1; index <= 3; index++)
        example('旧任务 $index', phase: MissionPhase.closed),
      example('待做任务'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('待做任务'), findsOneWidget);
    expect(find.text('旧任务 3'), findsNothing);
    expect(find.text('展开全部（4）'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('today-list')),
      const Offset(0, 500),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    repository.requests.last.complete([
      example('待做任务', phase: MissionPhase.closed),
      example('新增待做'),
      for (var index = 1; index <= 3; index++)
        example('旧任务 $index', phase: MissionPhase.closed),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('新增待做'), findsOneWidget);
    expect(find.text('旧任务 3'), findsNothing);
  });

  testWidgets('自选默认前三项，可展开收起且不查库；三项时不显示展开按钮', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([
      for (var index = 1; index <= 5; index++) example('自选任务 $index'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('自选任务 1'), findsOneWidget);
    expect(find.text('自选任务 3'), findsOneWidget);
    expect(find.text('自选任务 4'), findsNothing);
    expect(find.text('展开全部（5）'), findsOneWidget);
    final titleStyle = tester.widget<Text>(find.text('自选任务 1')).style!;
    expect(titleStyle.fontSize, AppTheme.light.textTheme.labelSmall?.fontSize);
    expect(titleStyle.fontWeight, FontWeight.w500);
    expect(find.text('5 项安排 · 计划 1 小时 40 分钟'), findsOneWidget);
    expect(find.text('安排概览'), findsNothing);
    expect(find.text('计划分钟'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('flexible-missions-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('flexible-missions-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flexible-missions-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('自选任务 4'), findsOneWidget);
    expect(find.text('自选任务 5'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);
    // 父页面重建不重置用户刚展开的区域，也不会多查一次数据库。
    await tester.pumpWidget(testApp(repository));
    expect(find.text('自选任务 5'), findsOneWidget);
    expect(repository.requests, hasLength(1));

    await tester.ensureVisible(
      find.byKey(const Key('flexible-missions-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('flexible-missions-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flexible-missions-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('自选任务 3'), findsOneWidget);
    expect(find.text('自选任务 4'), findsNothing);
    expect(repository.requests, hasLength(1));

    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('today-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('today-list')),
      const Offset(0, 500),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(repository.requests, hasLength(2));
    repository.requests.last.complete([
      example('仅有的自选任务 1'),
      example('仅有的自选任务 2'),
      example('仅有的自选任务 3'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('仅有的自选任务 3'), findsOneWidget);
    expect(find.byKey(const Key('flexible-missions-toggle')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('周日期栏标记今天，同周直接点今天，跨周保留紧凑入口', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('22'));
    repository.requests.last.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('回到今天'), findsNothing);
    expect(find.byKey(const Key('today-return-current-week')), findsNothing);
    await tester.tap(find.byKey(const Key('today-week-day-2026-10-21')));
    repository.requests.last.complete([]);
    await tester.pumpAndSettle();
    expect(repository.dates.last, '2026-10-21');
    await tester.tap(find.byKey(const Key('today-date-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.byKey(const Key('app-date-confirm')));
    await tester.pump();
    repository.requests.last.complete([]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-return-current-week')), findsOneWidget);
    await tester.tap(find.byKey(const Key('today-return-current-week')));
    await tester.pump();
    repository.requests.last.complete([]);
    await tester.pumpAndSettle();
    expect(repository.dates.last, '2026-10-21');
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 768.0, 1578.0]) {
    testWidgets('滑动只移动日期选中块，正文原位交叉淡化 $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = ControlledQueryRepository();
      await tester.pumpWidget(testApp(repository));
      repository.requests.single.complete([example('旧日期的内容')]);
      await tester.pumpAndSettle();
      final selection = find.byKey(const Key('today-week-selection'));
      final startX = tester.getCenter(selection).dx;
      final targetX = tester
          .getCenter(find.byKey(const Key('today-week-day-2026-10-22')))
          .dx;
      final content = find.byKey(const Key('today-content-switcher'));
      final contentX = tester.getTopLeft(content).dx;
      final surface = find.byKey(const Key('today-day-swipe'));
      final gesture = await tester.startGesture(tester.getCenter(surface));
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-90, 0));
      await tester.pump();
      expect(tester.getTopLeft(content).dx, contentX);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(repository.dates.last, '2026-10-22');
      expect(tester.getCenter(selection).dx, inExclusiveRange(startX, targetX));
      expect(find.text('旧日期的内容').hitTestable(), findsNothing);
      repository.requests.last.complete([example('新日期的内容')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('旧日期的内容'), findsOneWidget);
      expect(find.text('新日期的内容'), findsOneWidget);
      final fade = find
          .ancestor(
            of: find.byKey(const ValueKey('today-content-2026-10-22')),
            matching: find.byType(FadeTransition),
          )
          .first;
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        inExclusiveRange(0, 1),
      );
      expect(tester.getTopLeft(content).dx, contentX);
      await tester.pumpAndSettle();
      expect(tester.getCenter(selection).dx, closeTo(targetX, .01));
      expect(find.text('旧日期的内容'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final reduceMotion in [false, true]) {
    testWidgets('日期背景块连续移动且尊重减少动效 $reduceMotion', (tester) async {
      final repository = ControlledQueryRepository();
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: reduceMotion);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(testApp(repository));
      repository.requests.single.complete([]);
      await tester.pumpAndSettle();
      final selection = find.byKey(const Key('today-week-selection'));
      for (final day in ['22', '21']) {
        final startX = tester.getCenter(selection).dx;
        final targetX = tester
            .getCenter(find.byKey(Key('today-week-day-2026-10-$day')))
            .dx;
        await tester.tap(find.text(day));
        repository.requests.last.complete([]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final x = tester.getCenter(selection).dx;
        if (reduceMotion) {
          expect(x, closeTo(targetX, .01));
        } else {
          expect(
            x,
            inExclusiveRange(
              startX < targetX ? startX : targetX,
              startX > targetX ? startX : targetX,
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(tester.getCenter(selection).dx, closeTo(targetX, .01));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('查询期间旧卡片不可交互，返回原日期仍等待本次查询，迟到结果被丢弃', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([example('旧日期的任务')]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('22'));
    await tester.pump();
    expect(find.text('旧日期的任务').hitTestable(), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('21'));
    await tester.pump();
    expect(find.text('旧日期的任务').hitTestable(), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    repository.requests.last.complete([]);
    await tester.pumpAndSettle();
    repository.requests[1].complete([example('另一日期的迟到任务')]);
    await tester.pumpAndSettle();
    expect(find.text('另一日期的迟到任务'), findsNothing);
    expect(find.text('这一天还没有固定任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('统一内容边线：页头、日期带与各分区共用页面左右边距', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([
      example('固定任务', fixed: true),
      example('自选任务'),
    ]);
    await tester.pumpAndSettle();
    final dateChip = tester.getRect(find.byKey(const Key('today-date-picker')));
    final create = tester.getRect(find.byTooltip('创建任务'));
    final schedule = tester.getRect(
      find.byKey(const Key('today-schedule-section')),
    );
    final flexible = tester.getRect(
      find.byKey(const Key('today-flexible-section')),
    );
    final overview = tester.getRect(
      find.byKey(const Key('today-overview-section')),
    );
    // 页头日期、分区外框与顶栏动作共用同一条左右边线。
    expect(schedule.left, closeTo(dateChip.left, .5));
    expect(flexible.left, closeTo(dateChip.left, .5));
    expect(overview.left, closeTo(dateChip.left, .5));
    expect(schedule.right, closeTo(create.right, .5));
    expect(flexible.right, closeTo(create.right, .5));
    expect(overview.right, closeTo(create.right, .5));
    // 同性内边距：窄栏同一列都用 12dp，卡头动作贴另一侧内容边线。
    for (final (card, header) in [(schedule, '计划日程'), (flexible, '自选时间')]) {
      final title = tester.getRect(find.text(header));
      expect(title.left - card.left, closeTo(12, .5));
    }
    final seeAll = tester.getRect(find.byKey(const Key('today-all-missions')));
    expect(seeAll.right, closeTo(schedule.right - 12, .5));
    // 区块间距统一 16dp。
    expect(flexible.top - schedule.bottom, closeTo(16, .5));
    expect(overview.top - flexible.bottom, closeTo(16, .5));
    expect(overview.height, lessThan(48));
    expect(find.text('安排概览'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('卡头查看全部在宽窄都进所选日期的当日日程，顶栏全部任务仍进整周页', (tester) async {
    for (final width in [390.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = ControlledQueryRepository();
      await tester.pumpWidget(testApp(repository));
      repository.requests.single.complete([example('固定任务', fixed: true)]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today-all-missions')), findsOneWidget);
      await tester.tap(find.byKey(const Key('today-all-missions')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(repository.requests, hasLength(2));
      repository.requests.last.complete([example('固定任务', fixed: true)]);
      await tester.pumpAndSettle();
      expect(find.text('当日日程'), findsOneWidget);
      expect(repository.dates.last, '2026-10-21');
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      repository.requests.last.complete([example('固定任务', fixed: true)]);
      await tester.pumpAndSettle();
      // 顶栏入口仍进入整周页，不与当日日程混用。
      await tester.tap(find.byKey(const Key('today-all-missions-entry')));
      await tester.pumpAndSettle();
      expect(find.byType(AllMissionsPage), findsOneWidget);
      expect(find.text('日程列表'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('宽仪表盘保留 840dp 阈值与 3:2 双区，间隙 16dp，字号放大回单区', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([
      example('固定任务', fixed: true),
      example('自选任务'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-dashboard-columns')), findsOneWidget);
    final left = tester.getRect(find.byKey(const Key('today-timetable-panel')));
    final right = tester.getRect(
      find.byKey(const Key('today-flexible-section')),
    );
    final overview = tester.getRect(
      find.byKey(const Key('today-overview-section')),
    );
    final create = tester.getRect(find.byTooltip('创建任务'));
    final dateChip = tester.getRect(find.byKey(const Key('today-date-picker')));
    // 左右区外沿与页头共用页面边距。
    expect(left.left, closeTo(dateChip.left, .5));
    expect(right.right, closeTo(create.right, .5));
    expect(left.right + 16, closeTo(right.left, .5));
    expect(left.width / right.width, closeTo(1.5, .03));
    expect(right.left, closeTo(overview.left, .5));
    expect(right.right, closeTo(overview.right, .5));
    expect(right.right, closeTo(create.right, .5));
    expect(overview.top - right.bottom, closeTo(16, .5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());

    // 文字变大后按所需宽度回单区，不再硬塞两栏。
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final scaled = ControlledQueryRepository();
    await tester.pumpWidget(testApp(scaled));
    scaled.requests.single.complete([
      example('固定任务', fixed: true),
      example('自选任务'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-dashboard-columns')), findsNothing);
    expect(find.byKey(const Key('today-flexible-section')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('宽仪表盘仍在正文宽度 840dp 处开始分栏', (tester) async {
    // 888 减去两侧页面边距正好 840，838 少 2dp 就回到单列。
    for (final (width, expectWide) in [(888.0, true), (887.0, false)]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = ControlledQueryRepository();
      await tester.pumpWidget(testApp(repository));
      repository.requests.single.complete([example('固定任务', fixed: true)]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('today-dashboard-columns')).evaluate().isNotEmpty,
        expectWide,
        reason: '正文宽度 $width 的分栏结果',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('调整窗口与系统字号不额外读库，保留所选日期与展开状态', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([
      for (var index = 1; index <= 5; index++) example('自选任务 $index'),
    ]);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('flexible-missions-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flexible-missions-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('收起'), findsOneWidget);
    // 相当于拖门后的最窄/最宽与系统字号变化：只重排，不重查。
    for (final size in [
      const Size(320, 1000),
      const Size(520, 1000),
      const Size(1024, 1000),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
    }
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(1));
    expect(repository.dates, hasLength(1));
    expect(find.text('收起'), findsOneWidget);
    expect(find.text('自选任务 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [320.0, 390.0, 768.0, 1024.0, 1280.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('今天页 $width 宽、$scale 字号不溢出并保留入口', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repository = ControlledQueryRepository();
        await tester.pumpWidget(testApp(repository));
        repository.requests.single.complete([
          example('固定任务', fixed: true),
          example('无日期记录任务'),
        ]);
        await tester.pumpAndSettle();
        expect(find.text('计划日程'), findsOneWidget);
        final dashboard = find
            .byKey(const Key('today-dashboard-columns'))
            .evaluate()
            .isNotEmpty;
        if (dashboard) {
          // 宽仪表盘保留时间轴，计数仍在列表模式与日程卡里。
          expect(
            find.byKey(const Key('today-timetable-panel')),
            findsOneWidget,
          );
          expect(find.byType(MissionTimetable), findsOneWidget);
        } else {
          expect(find.text('共 1 项'), findsOneWidget);
        }
        expect(find.byKey(const Key('today-all-missions')), findsOneWidget);
        expect(
          find.byKey(const Key('today-all-missions-entry')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('切日期清除旧结果，迟到请求不能覆盖新日期，新建沿用所选日期', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    // 初次查询先不返回，模拟它比用户切日期后的查询更慢。
    final now = tz.TZDateTime.from(
      _todayClock(),
      tz.getLocation('Asia/Shanghai'),
    );
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
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('计划日期'))
          .getSemanticsData()
          .value,
      repository.dates.last,
    );
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
