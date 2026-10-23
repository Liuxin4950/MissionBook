import 'dart:async';
import 'dart:ui' show ImageByteFormat, SemanticsAction, Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderParagraph, RenderRepaintBoundary;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/presentation/missions/mission_detail_page.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:mission_book/domain/repositories/mission_repository.dart';
import 'package:mission_book/presentation/today/today_page.dart';
import 'package:mission_book/presentation/missions/create_mission_page.dart';
import 'package:timezone/timezone.dart' as tz;

// 每次读取都有独立 Future，用来控制等待、失败、重试和乱序返回。
class ControlledQueryRepository implements MissionRepository {
  @override
  Future<void> cancel(String missionId) =>
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

Widget testApp(
  MissionRepository repository, {
  bool shell = false,
  DateTime Function()? clock,
}) {
  final missionService = MissionService(repository);
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: shell
        ? AppShell(missionService: missionService)
        : Scaffold(
            body: TodayPage(
              missionService: missionService,
              clock: clock ?? DateTime.now,
            ),
          ),
  );
}

ScheduledMission example(
  String id, {
  bool fixed = false,
  bool cancelled = false,
  DateTime? start,
  int plannedDurationMinutes = 20,
  String timeZone = 'Asia/Shanghai',
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
      timeZone: timeZone,
      timePolicy: fixed ? TimePolicy.fixed : TimePolicy.flexible,
      fixedStartAt: fixed ? start ?? DateTime.utc(2026, 10, 21, 1) : null,
      plannedDurationMinutes: plannedDurationMinutes,
      changedAt: now,
    ),
  );
}

void main() {
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
        final data = node.getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.flagsCollection.isButton, isTrue);
      }

      final target = tester.getSemantics(find.bySemanticsLabel('目标'));
      final owner = target.owner;
      if (owner == null) {
        throw StateError('导航语义节点尚未挂载');
      }
      // 从语义树派发动作，验证读屏实际走到切页逻辑，而非只检查有一个回调。
      owner.performAction(target.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('目标页面'), findsOneWidget);
      expect(
        TickerMode.valuesOf(
          tester.element(find.byType(TodayPage, skipOffstage: false)),
        ).enabled,
        isFalse,
      );
      final selectedTarget = tester.getSemantics(find.bySemanticsLabel('目标'));
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

  testWidgets('真实创建、详情取消与返回刷新走完整链路，取消折叠保留任务', (tester) async {
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
    expect(find.text('任务已创建，可返回今天页'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('真实阅读任务'), findsOneWidget);
    expect(find.text('自选时间'), findsOneWidget);
    expect(find.text('计划 20 分钟'), findsOneWidget);
    // 从真实列表进入真实详情查询：标题同时是默认具体目标，所以详情中出现两次。
    await tester.tap(find.text('真实阅读任务'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.text('真实阅读任务'), findsNWidgets(2));
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('cancel-mission')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('cancel-mission')));
    await tester.pumpAndSettle();
    expect(find.text('取消这个任务？'), findsOneWidget);
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    expect(find.text('临时任务 · 已取消'), findsOneWidget);
    expect(find.text('没有执行记录'), findsOneWidget);
    expect(find.byKey(const Key('cancel-mission')), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('真实阅读任务'), findsNothing);
    expect(find.byKey(const Key('cancelled-missions')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('cancelled-missions')));
    await tester.tap(find.byKey(const Key('cancelled-missions')));
    await tester.pumpAndSettle();
    expect(find.text('真实阅读任务'), findsOneWidget);
    final cancelled = await tester.runAsync(
      () => database.select(database.missions).get(),
    );
    expect(cancelled, hasLength(1));
    expect(cancelled!.single.cancelledAt, isNotNull);
    await tester.tap(find.text('真实阅读任务'));
    await tester.pumpAndSettle();
    expect(find.text('临时任务 · 已取消'), findsOneWidget);
    expect(find.byKey(const Key('cancel-mission')), findsNothing);
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

  testWidgets('固定、自选与取消行按自身编号打开详情，读屏可点击且重复点击不叠页', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final repository = ControlledQueryRepository();
      final items = [
        example('固定入口', fixed: true),
        example('自选入口'),
        example('取消固定入口', fixed: true, cancelled: true),
        example('取消自选入口', cancelled: true),
      ];
      await tester.pumpWidget(testApp(repository, shell: true));
      repository.requests.single.complete(items);
      await tester.pumpAndSettle();
      // 先选另一天，验证关闭详情后仍刷新这一天，而不是重置成今天。
      final now = tz.TZDateTime.now(tz.getLocation('Asia/Shanghai'));
      final day = now.day == 1 ? 2 : 1;
      await tester.tap(find.byKey(const Key('today-date-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$day').last);
      await tester.tap(find.text('确定'));
      // 新日期的受控查询尚未完成，加载指示器会持续动画，只推进路由关闭。
      await tester.pump(const Duration(milliseconds: 400));
      repository.requests.last.complete(items);
      await tester.pumpAndSettle();
      final selectedDate = repository.dates.last;

      for (final item in items) {
        if (item.mission.cancelledAt != null) {
          final expansion = find.byKey(const Key('cancelled-missions'));
          await tester.ensureVisible(expansion);
          // 刷新沿用同一个取消分区 State：只在第一次需要时展开。
          if (find.text(item.mission.title).evaluate().isEmpty) {
            await tester.tap(find.byKey(const Key('cancelled-missions')));
            await tester.pumpAndSettle();
          }
        }
        final row = find.byKey(ValueKey('mission-${item.mission.id}'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final timeLabel = item.schedule.timePolicy == TimePolicy.fixed
            ? '09:00'
            : '自选时间';
        final cancelLabel = item.mission.cancelledAt == null ? '' : '已取消 · ';
        // 从任务的完整语义标签定位按钮，避免取到时间轴内部的布局节点。
        final node = tester.getSemantics(
          find.bySemanticsLabel(
            '$timeLabel，${item.mission.title}，$cancelLabel计划 20 分钟',
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
        expect(
          find.byType(MissionDetailPage, skipOffstage: false),
          findsOneWidget,
        );
        expect(repository.detailIds.last, item.mission.id);
        expect(find.text('未找到这个任务，请返回列表刷新'), findsOneWidget);
        await tester.tap(find.byTooltip('返回'));
        await tester.pump();
        expect(repository.dates.last, selectedDate);
        repository.requests.last.complete(items);
        await tester.pumpAndSettle();
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
    expect(find.text('仅有自选任务'), findsOneWidget);
    expect(find.text('这一天还没有自选任务'), findsNothing);
    // 空固定列表没有时间轴可画，不应进入每秒读取。
    final readsAfterLoad = reads;
    await tester.pump(const Duration(seconds: 3));
    expect(reads, readsAfterLoad);

    // 刷新成只剩取消任务的一天：两个区域仍常驻，不再用整句替换内容。
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

  testWidgets('刷新失败保留任务和展开状态，重试成功替换为新快照', (tester) async {
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([
      for (var index = 1; index <= 5; index++) example('保留项$index'),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flexible-missions-toggle')));
    await tester.pumpAndSettle();
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
    expect(find.byType(CreateMissionPage, skipOffstage: false), findsOneWidget);
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
    expect(find.byType(DatePickerDialog, skipOffstage: false), findsOneWidget);
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
      find.bySemanticsLabel('当前计划时段，09:00，$longTitle，计划 20 分钟'),
    );
    expect(
      activeNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue, // 任务行现在已接通详情入口，读屏也应提供同一个点击动作。
    );
    expect(activeNode.childrenCount, 0);
    expect(find.bySemanticsLabel('自选时间，自选1，计划 20 分钟'), findsOneWidget);
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
    expect(find.text('现在'), findsOneWidget);
    visible.value = false;
    await tester.pump();
    final hiddenReads = reads;
    now = start.add(const Duration(hours: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(reads, hiddenReads);
    visible.value = true;
    await tester.pump();
    expect(find.text('现在'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(reads, greaterThan(hiddenReads));
    expect(repository.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    visible.dispose();
  });

  testWidgets('单个未来任务前也显示实际时间和推进的绿轨；经过后、跨日及回拨保持一致', (tester) async {
    final repository = ControlledQueryRepository();
    final start = DateTime.utc(2026, 10, 22, 8); // 上海16:00。
    var now = DateTime.utc(2026, 10, 22); // 上海08:00，尚无任务处于计划时段。
    const captureKey = Key('single-future-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: testApp(repository, clock: () => now),
      ),
    );
    repository.requests.single.complete([
      example('未来唯一任务', fixed: true, start: start),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('现在'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    final title = tester.widget<Text>(find.text('未来唯一任务'));
    final root = tester.getRect(find.byKey(captureKey));
    final track = tester.getRect(find.byKey(const Key('timeline-track')));
    final rail = tester.getRect(
      find.byKey(const ValueKey('timeline-rail-未来唯一任务')),
    );
    final nodeY = tester.getRect(find.text('未来唯一任务')).center.dy;
    final beforeNode = track.top + (nodeY - track.top) * 0.6;
    final primary = AppTheme.light.colorScheme.primary.toARGB32() & 0xFFFFFF;
    Future<int> pixelAt(double y) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      final rgb = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
        final offset =
            (((y - root.top).floor() * image.width) +
                (rail.center.dx - root.left).floor()) *
            4;
        image.dispose();
        if (bytes == null) throw StateError('轨道截图读取失败');
        return (bytes.getUint8(offset) << 16) |
            (bytes.getUint8(offset + 1) << 8) |
            bytes.getUint8(offset + 2);
      });
      return rgb!;
    }

    expect(await pixelAt(beforeNode), isNot(primary));
    now = DateTime.utc(2026, 10, 22, 7); // 上海15:00，仍在首项之前。
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('15:00'), findsOneWidget);
    expect(await pixelAt(beforeNode), primary);
    expect(await pixelAt(nodeY), isNot(primary), reason: '现在不能覆盖尚未开始任务的空心节点');
    expect(await pixelAt(nodeY + 10), isNot(primary));
    expect(identical(tester.widget<Text>(find.text('未来唯一任务')), title), isTrue);
    now = DateTime.utc(2026, 10, 22, 12); // 上海20:00，已经过最后一项。
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('20:00'), findsOneWidget);
    expect(await pixelAt(nodeY + 10), primary);
    now = DateTime.utc(2026, 10, 22, 16); // 次日00:00，原日期不能再显示“现在”。
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('timeline-current-time')), findsNothing);
    now = DateTime.utc(2026, 10, 22, 7);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('15:00'), findsOneWidget);
    expect(await pixelAt(nodeY + 10), isNot(primary));
    expect(repository.requests, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('两项任务的空档也保留唯一当前时间，不误亮任何计划时段', (tester) async {
    final repository = ControlledQueryRepository();
    final first = DateTime.utc(2026, 10, 22, 6); // 上海14:00，14:20结束。
    final now = first.add(const Duration(hours: 1)); // 上海15:00，下一项16:00。
    await tester.pumpWidget(testApp(repository, clock: () => now));
    repository.requests.single.complete([
      example('已过时段', fixed: true, start: first),
      example('未来时段', fixed: true, start: first.add(const Duration(hours: 2))),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('现在'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == '当前计划时段',
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('timeline-track')), findsOneWidget);
    expect(repository.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('稳定计划时段只重绘进度，任务文字不重建且绿色确实推进', (tester) async {
    final repository = ControlledQueryRepository();
    final start = DateTime.utc(2026, 10, 22, 1);
    var now = start.add(const Duration(minutes: 5));
    const captureKey = Key('stable-progress-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: testApp(repository, clock: () => now),
      ),
    );
    repository.requests.single.complete([
      example('稳定任务', fixed: true, start: start, plannedDurationMinutes: 60),
      example('下一时刻', fixed: true, start: start.add(const Duration(hours: 1))),
    ]);
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('稳定任务'));
    final rail = tester.getRect(
      find.byKey(const ValueKey('timeline-rail-稳定任务')),
    );
    final root = tester.getRect(find.byKey(captureKey));
    final point = Offset(
      rail.center.dx - root.left,
      (tester.getRect(find.text('稳定任务')).center.dy +
                  tester.getRect(find.text('下一时刻')).center.dy) /
              2 -
          root.top,
    );
    Future<int> readPixel() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      final rgb = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final raw = await image.toByteData(format: ImageByteFormat.rawRgba);
        final width = image.width;
        image.dispose();
        if (raw == null) throw StateError('进度像素读取失败');
        final offset = (point.dy.floor() * width + point.dx.floor()) * 4;
        return (raw.getUint8(offset) << 16) |
            (raw.getUint8(offset + 1) << 8) |
            raw.getUint8(offset + 2);
      });
      if (rgb == null) throw StateError('进度截图未完成');
      return rgb;
    }

    final primary =
        Theme.of(
          tester.element(find.text('稳定任务')),
        ).colorScheme.primary.toARGB32() &
        0xFFFFFF;
    expect(await readPixel(), isNot(primary));
    now = start.add(const Duration(minutes: 45));
    await tester.pump(const Duration(seconds: 1));
    expect(identical(tester.widget<Text>(find.text('稳定任务')), title), isTrue);
    expect(await readPixel(), primary);
    expect(repository.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏双倍字重字距和行高覆盖下，固定时长及时区文字仍在卡片内', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ControlledQueryRepository();
    final start = DateTime.utc(2026, 10, 22, 1);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(2),
          boldText: true,
          lineHeightScaleFactorOverride: 2,
          letterSpacingOverride: 1.5,
          wordSpacingOverride: 2,
          disableAnimations: true,
        ),
        child: testApp(repository, clock: () => start),
      ),
    );
    repository.requests.single.complete([
      example(
        '大字体固定任务',
        fixed: true,
        start: start,
        plannedDurationMinutes: 123456,
        timeZone: 'America/Argentina/Buenos_Aires',
      ),
      example('大字体自选任务标题保持单行省略'),
    ]);
    await tester.pumpAndSettle();
    final card = tester.getRect(
      find.byKey(const ValueKey('schedule-highlight-大字体固定任务')),
    );
    for (final text in [
      '大字体固定任务',
      '计划 123456 分钟',
      'America/Argentina/Buenos_Aires',
    ]) {
      final rect = tester.getRect(find.text(text));
      expect(rect.top, greaterThanOrEqualTo(card.top));
      expect(rect.bottom, lessThanOrEqualTo(card.bottom + 0.01));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
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
    await tester.tap(find.byKey(const Key('flexible-missions-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('自选任务 3'), findsOneWidget);
    expect(find.text('自选任务 4'), findsNothing);
    expect(repository.requests, hasLength(1));

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

  testWidgets('窄屏长标题保持单行和时间轴连续；固定时间按上海显示，取消任务默认折叠', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository));
    repository.requests.single.complete([
      example('固定任务', fixed: true),
      example('固定任务的长标题用于检查单行省略后时间轴仍然连续而不是出现断线', fixed: true),
      example('最后一个固定任务', fixed: true),
      example('很长的自选任务标题需要能够单行省略而不是发生水平溢出'),
      example('取消的任务', cancelled: true),
      example('取消的固定任务', fixed: true, cancelled: true),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('09:00'), findsNWidgets(3));
    expect(find.text('计划日程'), findsOneWidget);
    final allMissions = find.byKey(const Key('today-all-missions'));
    expect(tester.widget<TextButton>(allMissions).onPressed, isNull);
    expect(
      tester.getRect(allMissions).left,
      greaterThanOrEqualTo(tester.getRect(find.text('计划日程')).right),
    );
    final firstRail = tester.getRect(
      find.byKey(const ValueKey('timeline-rail-固定任务')),
    );
    final middleRail = tester.getRect(
      find.byKey(
        const ValueKey('timeline-rail-固定任务的长标题用于检查单行省略后时间轴仍然连续而不是出现断线'),
      ),
    );
    final lastRail = tester.getRect(
      find.byKey(const ValueKey('timeline-rail-最后一个固定任务')),
    );
    // 远近缩放可改变行高，但相邻轨道边界仍需连续。
    expect(firstRail.center.dx, middleRail.center.dx);
    expect(middleRail.center.dx, lastRail.center.dx);
    expect(firstRail.bottom + 8, closeTo(middleRail.top, 0.01));
    expect(middleRail.bottom + 8, closeTo(lastRail.top, 0.01));
    // 从实际排版的字符框检查单行，避免把不同远近字号误当成换行。
    for (final title in [
      '固定任务的长标题用于检查单行省略后时间轴仍然连续而不是出现断线',
      '很长的自选任务标题需要能够单行省略而不是发生水平溢出',
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: title.length),
      );
      expect(boxes.map((box) => box.top).toSet(), hasLength(1));
    }
    expect(find.text('取消的任务'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('cancelled-missions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancelled-missions')));
    await tester.pumpAndSettle();
    expect(find.text('取消的任务'), findsOneWidget);
    expect(find.text('取消的固定任务'), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-rail-取消的固定任务')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('真实时钟刷新计划高亮，重叠时段独立结束；后台恢复与回拨不重新查库', (tester) async {
    final start = DateTime.utc(2026, 10, 22, 1);
    var now = start.subtract(const Duration(seconds: 1));
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository, clock: () => now));
    repository.requests.single.complete([
      example('短时段', fixed: true, start: start, plannedDurationMinutes: 10),
      example('长时段', fixed: true, start: start, plannedDurationMinutes: 30),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('现在'), findsOneWidget);
    expect(find.text('08:59'), findsOneWidget);

    now = start;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('现在'), findsOneWidget);
    now = start.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('现在'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mission-长时段')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '当前计划时段',
        ),
      ),
      findsOneWidget,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = start.add(const Duration(minutes: 30));
    await tester.pump(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('现在'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);

    // 回拨时重新投影真实时刻，不把上次的视觉状态当成事实累加。
    now = start.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('现在'), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
    expect(repository.requests, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('全天轨道经过首节点且已到达轨道与激活节点连续', (tester) async {
    final start = DateTime.utc(2026, 10, 22, 1);
    final now = start.add(const Duration(minutes: 15));
    final repository = ControlledQueryRepository();
    const captureKey = Key('timeline-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: testApp(repository, clock: () => now),
      ),
    );
    repository.requests.single.complete([
      example(
        '过去项',
        fixed: true,
        start: start.subtract(const Duration(hours: 1)),
      ),
      example('激活项', fixed: true, start: start, plannedDurationMinutes: 60),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('现在'), findsOneWidget);
    final root = tester.getRect(find.byKey(captureKey));
    final rail = tester.getRect(
      find.byKey(const ValueKey('timeline-rail-过去项')),
    );
    final firstCard = tester.getRect(
      find.byKey(const ValueKey('schedule-highlight-过去项')),
    );
    final activeTitle = tester.getRect(find.text('激活项'));
    final firstTitle = tester.getRect(find.text('过去项'));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    final snapshot = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final raw = await image.toByteData(format: ImageByteFormat.rawRgba);
      final width = image.width;
      image.dispose();
      if (raw == null) throw StateError('无法读取轨道渲染像素');
      return (raw: raw, width: width);
    });
    if (snapshot == null) throw StateError('轨道渲染截图未完成');
    final expectedColor =
        Theme.of(
          tester.element(find.text('激活项')),
        ).colorScheme.primary.toARGB32() &
        0xFFFFFF;
    final x = (rail.center.dx - root.left).floor();
    final brokenRows = <int>[];
    // 已经过的当天时间从首节点上方接入，不因第一个任务开始而重新归零。
    for (
      var y = (firstCard.top - root.top + 1).ceil();
      y < (firstTitle.center.dy - root.top - 6).floor();
      y++
    ) {
      final offset = (y * snapshot.width + x) * 4;
      final rgb =
          (snapshot.raw.getUint8(offset) << 16) |
          (snapshot.raw.getUint8(offset + 1) << 8) |
          snapshot.raw.getUint8(offset + 2);
      expect(rgb, expectedColor, reason: '首个任务之前经过的时间也属于当天进度');
    }
    // 从首个圆点中心到激活节点下方，包含圆点两侧和8像素连接区。
    for (
      var y = (firstTitle.center.dy - root.top).ceil();
      y <= (activeTitle.center.dy - root.top + 2).floor();
      y++
    ) {
      final offset = (y * snapshot.width + x) * 4;
      final rgb =
          (snapshot.raw.getUint8(offset) << 16) |
          (snapshot.raw.getUint8(offset + 1) << 8) |
          snapshot.raw.getUint8(offset + 2);
      if (rgb != expectedColor) brokenRows.add(y);
    }
    expect(brokenRows, isEmpty, reason: '绿色连线应连续穿过段间连接和已到达节点');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('激活卡片与对应轨道段在伸缩动画的每一帧等高，邻项同步让位', (tester) async {
    final start = DateTime.utc(2026, 10, 22, 1);
    var now = start.subtract(const Duration(seconds: 1));
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository, clock: () => now));
    repository.requests.single.complete([
      example('本项', fixed: true, start: start, plannedDurationMinutes: 30),
      example('下一项', fixed: true, start: start.add(const Duration(hours: 1))),
    ]);
    await tester.pumpAndSettle();

    Rect card(String id) =>
        tester.getRect(find.byKey(ValueKey('schedule-highlight-$id')));
    void expectAligned() {
      for (final id in ['本项', '下一项']) {
        final rail = tester.getRect(find.byKey(ValueKey('timeline-rail-$id')));
        expect(rail.top, closeTo(card(id).top, 0.001));
        expect(rail.bottom, closeTo(card(id).bottom, 0.001));
        final title = tester.getRect(find.text(id));
        final duration = tester.getRect(
          find.descendant(
            of: find.byKey(ValueKey('schedule-highlight-$id')),
            matching: find.text('计划 ${id == '本项' ? 30 : 20} 分钟'),
          ),
        );
        expect(title.overlaps(duration), isFalse, reason: '展开与收拢中标题和时长不相撞');
        expect(duration.bottom, lessThanOrEqualTo(card(id).bottom + 0.1));
      }
      final gap = tester.getRect(find.byKey(const ValueKey('timeline-gap-本项')));
      expect(gap.top, closeTo(card('本项').bottom, 0.001));
      expect(gap.bottom, closeTo(card('下一项').top, 0.001));
    }

    expectAligned();
    final initialHeight = card('本项').height;
    final initialNextTop = card('下一项').top;
    now = start;
    await tester.pump(const Duration(seconds: 1));
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 70));
      expectAligned();
    }
    final expandedHeight = card('本项').height;
    expect(expandedHeight, greaterThan(initialHeight));
    expect(card('下一项').top, greaterThan(initialNextTop));

    now = start.add(const Duration(minutes: 30));
    await tester.pump(const Duration(seconds: 1));
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 70));
      expectAligned();
    }
    expect(card('本项').height, lessThan(expandedHeight));
    expect(repository.requests, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('七项日程向两端递减并压成单行，激活切换后焦点和轨道一起移动', (tester) async {
    final start = DateTime.utc(2026, 10, 22, 1);
    var now = start.add(const Duration(hours: 4, minutes: 5));
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository, clock: () => now));
    repository.requests.single.complete([
      for (var index = 0; index < 7; index++)
        example(
          '日程$index',
          fixed: true,
          start: start.add(Duration(hours: index)),
        ),
    ]);
    await tester.pumpAndSettle();

    Rect card(int index) =>
        tester.getRect(find.byKey(ValueKey('schedule-highlight-日程$index')));
    void expectLens(int focus) {
      for (var index = 0; index < 7; index++) {
        final rail = tester.getRect(
          find.byKey(ValueKey('timeline-rail-日程$index')),
        );
        expect(rail.top, closeTo(card(index).top, 0.001));
        expect(rail.bottom, closeTo(card(index).bottom, 0.001));
        if (index < focus) {
          expect(card(index).height, lessThan(card(index + 1).height));
        } else if (index < 6) {
          expect(card(index).height, greaterThan(card(index + 1).height));
        }
        final title = tester.widget<Text>(find.text('日程$index'));
        expect(title.style!.fontSize, inInclusiveRange(12, 16));
        final duration = find.descendant(
          of: find.byKey(ValueKey('schedule-highlight-日程$index')),
          matching: find.text('计划 20 分钟'),
        );
        final titleRect = tester.getRect(find.text('日程$index'));
        final durationRect = tester.getRect(duration);
        if (index == focus) {
          expect(title.style!.fontSize, 16);
          expect(durationRect.top, greaterThan(titleRect.bottom));
        } else {
          expect(durationRect.center.dy, closeTo(titleRect.center.dy, 0.1));
          expect(durationRect.left, greaterThan(titleRect.right));
        }
      }
      expect(tester.widget<Text>(find.text('日程0')).style!.fontSize, 12);
      expect(tester.widget<Text>(find.text('日程6')).style!.fontSize, 12);
      expect(card(6).bottom - card(0).top, lessThan(300));
    }

    expectLens(4);
    now = start.add(const Duration(hours: 5, minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expectLens(5);
    expect(repository.requests, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏大字体下当前卡片保持单行标题，时间节点相邻连续', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final start = DateTime.utc(2026, 10, 22, 1);
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: testApp(repository, clock: () => start),
      ),
    );
    repository.requests.single.complete([
      example('一个用于检查高亮时长标题省略和时间线连接的任务', fixed: true, start: start),
      example('下一项任务', fixed: true, start: start.add(const Duration(hours: 2))),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('现在'), findsOneWidget);
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('现在'))).scale(10),
      20,
    );
    final first = tester.getRect(
      find.byKey(const ValueKey('timeline-rail-一个用于检查高亮时长标题省略和时间线连接的任务')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('timeline-rail-下一项任务')),
    );
    expect(first.bottom + 8, closeTo(second.top, 0.01));
    expect(first.center.dx, second.center.dx);
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
