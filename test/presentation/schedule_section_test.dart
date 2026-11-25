import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/core/theme/colors.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:mission_book/presentation/today/schedule_section.dart';
import 'package:mission_book/presentation/missions/all/mission_timetable.dart';
import 'package:mission_book/presentation/today/today_display.dart' as display;

import 'today_page_test.dart' show ControlledQueryRepository, example, testApp;

/// 单独渲染计划行，按精确的可用宽度和系统字号验证宽/窄两种排版。
Future<List<display.TodayMissionItem>> pumpScheduleRows(
  WidgetTester tester, {
  required double width,
  required double scale,
  required DateTime now,
  required List<ScheduledMission> missions,
  void Function(String id)? onOpen,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = Size(width + 32, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final items = display.groupMissionsForDisplay(missions, now: now).fixed;
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
        body: SingleChildScrollView(
          child: Center(
            child: Directionality(
              textDirection: direction,
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < items.length; index++)
                      ScheduleMissionRow(
                        key: ValueKey('schedule-test-row-${items[index].id}'),
                        item: items[index],
                        now: now,
                        isFirst: index == 0,
                        isLast: index == items.length - 1,
                        onTap: () => onOpen?.call(items[index].id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return items;
}

bool _hasKey(WidgetTester tester, Key key) =>
    find.byKey(key).evaluate().isNotEmpty;

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

void main() {
  setUpAll(tzdata.initializeTimeZones);
  testWidgets('日程在失去输入焦点但仍可见时跨越计划边界继续刷新', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    final start = DateTime.utc(2026, 10, 23, 8, 30);
    var now = start;
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository, clock: () => now));
    repository.requests.single.complete([
      example('失焦时仍可见', fixed: true, start: start, plannedDurationMinutes: 1),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('当前时段'), findsOneWidget);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('时段已过'), findsOneWidget);
    expect(repository.requests, hasLength(1));
  });

  testWidgets('零、一、多日程按窗口展示，单项不留占位行', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final start = DateTime.utc(2026, 10, 23, 8, 30);
    for (final count in [0, 1, 12]) {
      final repository = ControlledQueryRepository();
      await tester.pumpWidget(testApp(repository, clock: () => start));
      repository.requests.single.complete([
        for (var index = 0; index < count; index++)
          example(
            '日程$index',
            fixed: true,
            start: start.add(Duration(hours: index)),
          ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('共 $count 项'), findsOneWidget);
      expect(
        find.byType(ScheduleMissionRow),
        findsNWidgets(count > 4 ? 4 : count),
      );
      expect(
        find.byKey(const Key('schedule-more')),
        count > 4 ? findsOneWidget : findsNothing,
      );
      if (count == 0) expect(find.text('新建任务'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('重叠时段分别高亮，结束与回拨不产生完成状态或额外查询', (tester) async {
    final start = DateTime.utc(2026, 10, 23, 8, 30);
    var now = start;
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(testApp(repository, clock: () => now));
    repository.requests.single.complete([
      example('短任务', fixed: true, start: start, plannedDurationMinutes: 10),
      example('长任务', fixed: true, start: start, plannedDurationMinutes: 30),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('当前时段'), findsNWidgets(2));
    now = start.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('当前时段'), findsOneWidget);
    expect(find.text('时段已过'), findsOneWidget);
    expect(find.text('已完成'), findsNothing);
    now = start.subtract(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('待到时'), findsNWidgets(2));
    // 未来或已经过去的时段不绘制空/满进度条。
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('计划剩余'), findsNothing);
    expect(repository.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('查看全部沿用所选日期，返回重读，重复点击不叠页', (tester) async {
    final now = DateTime.utc(2026, 10, 23, 8);
    final repository = ControlledQueryRepository();
    final items = [
      for (var i = 0; i < 12; i++)
        example('日程$i', fixed: true, start: now.add(Duration(hours: i))),
    ];
    await tester.pumpWidget(testApp(repository, clock: () => now));
    repository.requests.single.complete(items);
    await tester.pumpAndSettle();
    final all = find.byKey(const Key('today-all-missions'));
    await tester.tap(all);
    await tester.tap(all);
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.requests, hasLength(2));
    expect(repository.dates.toSet(), {'2026-10-23'});
    repository.requests.last.complete(items);
    await tester.pumpAndSettle();
    expect(find.text('当日日程'), findsOneWidget);
    expect(find.byKey(const Key('day-schedule-timeline')), findsOneWidget);
    expect(find.byType(MissionTimetable), findsOneWidget);
    await tester.tap(find.byKey(const Key('day-schedule-list-mode')));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleMissionRow), findsNWidgets(12));
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(3));
    repository.requests.last.complete(items.take(1).toList());
    await tester.pumpAndSettle();
    expect(find.text('共 1 项'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('320宽双倍字体和减少动效下长标题及时区可正常布局', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 10, 23, 8);
    final repository = ControlledQueryRepository();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: testApp(repository, clock: () => now),
      ),
    );
    repository.requests.single.complete([
      example(
        '需要完整读屏并支持单行省略的很长很长的任务名称',
        fixed: true,
        start: now,
        timeZone: 'America/Argentina/Buenos_Aires',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('America/Argentina/Buenos_Aires'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 标题在上，开始/结束时刻和真实阶段在辅助行，空间不足自然换行。
  for (final (width, scale) in [(320.0, 2.0), (386.0, 1.0), (390.0, 1.3)]) {
    testWidgets('窄列表在 $width 宽、$scale 字号向下换行且整项可打开', (tester) async {
      final now = DateTime.utc(2026, 11, 2, 6, 29);
      final start = now.subtract(const Duration(minutes: 29));
      const title = 'Python程序设计基础与课堂实践';
      var opened = '';
      final items = await pumpScheduleRows(
        tester,
        width: width,
        scale: scale,
        now: now,
        onOpen: (id) => opened = id,
        missions: [
          example(
            title,
            fixed: true,
            start: start,
            plannedDurationMinutes: 100,
            phase: MissionPhase.running,
            events: [
              ExecutionEvent(
                id: 'start',
                missionId: title,
                sequence: 1,
                type: ExecutionEventType.start,
                occurredAt: now.subtract(const Duration(seconds: 81)),
                scheduleRevisionId: '$title-schedule',
              ),
            ],
          ),
        ],
      );
      final id = items.single.id;
      expect(
        _hasKey(tester, ValueKey('schedule-meta-$id')),
        isTrue,
        reason: '窄列表把开始/结束时刻放在辅助行',
      );
      expect(_hasKey(tester, ValueKey('schedule-time-$id')), isFalse);
      expect(find.text('执行中'), findsOneWidget);
      expect(find.textContaining('专注'), findsNothing);
      expect(find.textContaining('计划剩余 71 分钟'), findsOneWidget);
      expect(find.text('查看'), findsNothing);
      final row = _rect(tester, ValueKey('schedule-test-row-$id'));
      final titleRect = _rect(tester, ValueKey('schedule-title-$id'));
      final meta = _rect(tester, ValueKey('schedule-meta-$id'));
      final arrow = _rect(tester, ValueKey('schedule-open-$id'));
      // 标题在轨道右侧；辅助行再向内收 8dp，仍在同一内容槽内。
      expect(titleRect.left - row.left, closeTo(16, .5));
      expect(meta.left - row.left, closeTo(24, .5));
      expect(meta.top, greaterThan(titleRect.bottom));
      // 右箭头共线并固定占 20dp 槽。
      expect(arrow.width, closeTo(20, .5));
      expect(arrow.right, closeTo(row.right - 8, .5));
      expect(row.height, greaterThanOrEqualTo(48));
      expect(titleRect.width, greaterThan(width * .3));
      // 阶段在辅助行内换行，不被省略号吞掉。
      final status = _rect(tester, ValueKey('schedule-status-$id'));
      if ((status.top - meta.top).abs() < 1) {
        expect(status.left, greaterThanOrEqualTo(meta.right - 1));
      } else {
        expect(status.top, greaterThan(meta.bottom - 1));
      }
      await tester.tap(find.text(title));
      expect(opened, id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // 宽屏沿用两行层级；各行标题、时间区间、状态与箭头共用列线。
  for (final width in [480.0, 600.0, 768.0, 1024.0, 1280.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('日程在 $width 宽、$scale 字号信息分层且各行共线', (tester) async {
        final now = DateTime.utc(2026, 11, 2, 6, 29);
        final items = await pumpScheduleRows(
          tester,
          width: width,
          scale: scale,
          now: now,
          onOpen: (_) {},
          missions: [
            example(
              '品牌与营销管理实务',
              fixed: true,
              start: now.subtract(const Duration(minutes: 29)),
              plannedDurationMinutes: 100,
              phase: MissionPhase.running,
              events: [
                ExecutionEvent(
                  id: 'start',
                  missionId: '品牌与营销管理实务',
                  sequence: 1,
                  type: ExecutionEventType.start,
                  occurredAt: now.subtract(const Duration(minutes: 29)),
                  scheduleRevisionId: '品牌与营销管理实务-schedule',
                ),
              ],
            ),
            example(
              'Python程序设计基础',
              fixed: true,
              start: now.add(const Duration(hours: 1)),
              plannedDurationMinutes: 1440,
            ),
          ],
        );
        final first = items.first.id;
        final second = items.last.id;
        final rowA = _rect(tester, ValueKey('schedule-test-row-$first'));
        final titleA = _rect(tester, ValueKey('schedule-title-$first'));
        final metaA = _rect(tester, ValueKey('schedule-meta-$first'));
        final statusA = _rect(tester, ValueKey('schedule-status-$first'));
        final arrowA = _rect(tester, ValueKey('schedule-open-$first'));
        final titleB = _rect(tester, ValueKey('schedule-title-$second'));
        final metaB = _rect(tester, ValueKey('schedule-meta-$second'));
        final statusB = _rect(tester, ValueKey('schedule-status-$second'));
        final arrowB = _rect(tester, ValueKey('schedule-open-$second'));
        expect(titleB.left, closeTo(titleA.left, .5));
        expect(metaB.left, closeTo(metaA.left, .5));
        expect(statusB.right, closeTo(statusA.right, .5));
        expect(arrowB.right, closeTo(arrowA.right, .5));
        expect(titleA.left - rowA.left, closeTo(16, .5));
        expect(metaA.left - titleA.left, closeTo(8, .5));
        expect(metaA.top, greaterThan(titleA.bottom));
        expect(rowA.height, greaterThanOrEqualTo(48));
        expect(find.textContaining('专注'), findsNothing);
        if ((statusA.top - metaA.top).abs() < 1) {
          expect(statusA.left, greaterThanOrEqualTo(metaA.right));
        } else {
          expect(statusA.top, greaterThanOrEqualTo(metaA.bottom));
        }
        expect(
          find.byKey(ValueKey('schedule-plan-progress-$second')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('RTL 下宽窄任务行按方向镜像且不溢出', (tester) async {
    final now = DateTime.utc(2026, 11, 2, 6, 29);
    for (final width in [390.0, 768.0]) {
      final items = await pumpScheduleRows(
        tester,
        width: width,
        scale: 1,
        now: now,
        onOpen: (_) {},
        direction: TextDirection.rtl,
        missions: [
          example(
            '右到左任务',
            fixed: true,
            start: now.subtract(const Duration(minutes: 10)),
            plannedDurationMinutes: 100,
          ),
        ],
      );
      final id = items.single.id;
      final row = _rect(tester, ValueKey('schedule-test-row-$id'));
      final arrow = _rect(tester, ValueKey('schedule-open-$id'));
      // 方向相关的行内布局：RTL 时箭头落在起始边，时间栏移到末端。
      expect(arrow.left, closeTo(row.left + 8, .5));
      if (_hasKey(tester, ValueKey('schedule-time-$id'))) {
        final time = _rect(tester, ValueKey('schedule-time-$id'));
        expect(time.right, closeTo(row.right, .5));
      } else {
        final meta = _rect(tester, ValueKey('schedule-meta-$id'));
        // 辅助行沿起始方向内收轨道宽度再加 8dp，RTL 时镜像。
        final inset = row.right - meta.right;
        expect(inset, closeTo(24, .5));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('480 宽双倍字号保持两行层级且辅助信息不溢出', (tester) async {
    final now = DateTime.utc(2026, 11, 2, 6, 29);
    final items = await pumpScheduleRows(
      tester,
      width: 480,
      scale: 2,
      now: now,
      onOpen: (_) {},
      missions: [
        example(
          '品牌与营销管理实务',
          fixed: true,
          start: now,
          plannedDurationMinutes: 90,
        ),
      ],
    );
    final id = items.single.id;
    expect(_hasKey(tester, ValueKey('schedule-time-$id')), isFalse);
    expect(_hasKey(tester, ValueKey('schedule-meta-$id')), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('当前计划时段用浅强调面、轨道标记与仅当前时段的计划进度', (tester) async {
    final now = DateTime.utc(2026, 11, 2, 6, 29);
    final items = await pumpScheduleRows(
      tester,
      width: 768,
      scale: 1,
      now: now,
      onOpen: (_) {},
      missions: [
        example(
          '当前任务',
          fixed: true,
          start: now.subtract(const Duration(minutes: 29)),
          plannedDurationMinutes: 100,
        ),
        example(
          '稍后任务',
          fixed: true,
          start: now.add(const Duration(hours: 1)),
          plannedDurationMinutes: 60,
        ),
      ],
    );
    final current = items.first.id;
    final later = items.last.id;
    final currentSurface = tester.widget<AnimatedContainer>(
      find.byKey(ValueKey('schedule-surface-$current')),
    );
    final laterSurface = tester.widget<AnimatedContainer>(
      find.byKey(ValueKey('schedule-surface-$later')),
    );
    expect(
      (currentSurface.decoration! as BoxDecoration).color,
      AppColors.accentSoft,
    );
    expect(
      (laterSurface.decoration! as BoxDecoration).color,
      Colors.transparent,
    );
    final node = tester.widget<Container>(
      find.byKey(ValueKey('schedule-node-$current')),
    );
    expect(
      (node.decoration! as BoxDecoration).color,
      Theme.of(
        tester.element(find.byType(ScheduleMissionRow).first),
      ).colorScheme.primary,
    );
    expect(find.text('计划剩余 71 分钟'), findsOneWidget);
    final bar = _rect(tester, ValueKey('schedule-plan-progress-$current'));
    final remaining = _rect(
      tester,
      ValueKey('schedule-plan-remaining-$current'),
    );
    final status = _rect(tester, ValueKey('schedule-status-$current'));
    // 进度只保留在当前时段；足够宽时与剩余分钟同排。
    expect((bar.center.dy - remaining.center.dy).abs(), lessThan(1));
    expect(bar.right, lessThan(remaining.left));
    expect(remaining.top, greaterThan(status.bottom));
    expect(find.byKey(ValueKey('schedule-plan-progress-$later')), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(ValueKey('schedule-plan-progress-$current')),
          )
          .value,
      closeTo(29 / 100, .01),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('暂停、STOP 待确认与已结束显示真实阶段，不冒充仍在执行', (tester) async {
    final now = DateTime.utc(2026, 11, 2, 6, 29);
    final start = now.subtract(const Duration(minutes: 10));
    ExecutionEvent event(
      String id,
      int sequence,
      ExecutionEventType type,
      DateTime at,
    ) => ExecutionEvent(
      id: '$id-$sequence',
      missionId: id,
      sequence: sequence,
      type: type,
      occurredAt: at,
      scheduleRevisionId: '$id-schedule',
    );
    await pumpScheduleRows(
      tester,
      width: 768,
      scale: 1,
      now: now,
      onOpen: (_) {},
      missions: [
        example(
          '暂停任务',
          fixed: true,
          start: start,
          plannedDurationMinutes: 60,
          phase: MissionPhase.paused,
          events: [
            event('暂停任务', 1, ExecutionEventType.start, start),
            event('暂停任务', 2, ExecutionEventType.pause, now),
          ],
        ),
        example(
          '到点停止任务',
          fixed: true,
          start: start,
          plannedDurationMinutes: 20,
          phase: MissionPhase.reportPending,
          events: [
            event('到点停止任务', 1, ExecutionEventType.start, start),
            event('到点停止任务', 2, ExecutionEventType.stop, now),
          ],
        ),
        example(
          '已结束任务',
          fixed: true,
          start: start,
          plannedDurationMinutes: 20,
          phase: MissionPhase.closed,
          events: [
            event('已结束任务', 1, ExecutionEventType.start, start),
            event('已结束任务', 2, ExecutionEventType.end, now),
          ],
        ),
      ],
    );
    expect(find.text('已暂停'), findsOneWidget);
    expect(find.text('待确认'), findsOneWidget);
    expect(find.text('已结束'), findsOneWidget);
    expect(find.text('执行中'), findsNothing);
    expect(find.text('当前时段'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('加时的计划终点继续用于当前时段剩余分钟与进度', (tester) async {
    final now = DateTime.utc(2026, 11, 2, 6, 29);
    final start = now.subtract(const Duration(minutes: 10));
    final items = await pumpScheduleRows(
      tester,
      width: 768,
      scale: 1,
      now: now,
      onOpen: (_) {},
      missions: [
        example(
          '加时任务',
          fixed: true,
          start: start,
          plannedDurationMinutes: 20,
          events: [
            ExecutionEvent(
              id: 'extend',
              missionId: '加时任务',
              sequence: 1,
              type: ExecutionEventType.extend,
              occurredAt: start,
              scheduleRevisionId: '加时任务-schedule',
              grantedDurationMinutes: 10,
            ),
          ],
        ),
      ],
    );
    expect(find.text('当前时段'), findsOneWidget);
    // 原计划 20 分钟 + 加时 10 分钟 = 30 分钟窗口，已过 10 分钟。
    expect(find.text('计划剩余 20 分钟'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(ValueKey('schedule-plan-progress-${items.single.id}')),
          )
          .value,
      closeTo(10 / 30, .01),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('超长中英文标题在宽窄排版下都保留完整读屏名称', (tester) async {
    final semantics = tester.ensureSemantics();
    final now = DateTime.utc(2026, 11, 2, 6, 29);
    const longChinese = '这是一个需要完整读屏并允许两行显示的很长很长的任务名称';
    const longEnglish =
        'SupercalifragilisticexpialidociousWithoutAnySpaceToBreak';
    for (final (width, scale) in [(320.0, 2.0), (768.0, 2.0)]) {
      for (final title in [longChinese, longEnglish]) {
        await pumpScheduleRows(
          tester,
          width: width,
          scale: scale,
          now: now,
          onOpen: (_) {},
          missions: [
            example(title, fixed: true, start: now, plannedDurationMinutes: 90),
          ],
        );
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(title))),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    semantics.dispose();
  });

  testWidgets('当日完整日程保留分页，宽窄列表都能继续翻页', (tester) async {
    final now = DateTime.utc(2026, 11, 2, 6, 29);
    final items = display.groupMissionsForDisplay([
      for (var index = 0; index < 51; index++)
        example(
          '完整日程 $index',
          fixed: true,
          start: now.add(Duration(minutes: index * 30)),
        ),
    ], now: now).fixed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScheduleSection(
              items: items,
              selectedDate: DateUtils.dateOnly(now),
              clock: () => now,
              onOpenMission: (_) {},
              fullList: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleMissionRow), findsNWidgets(50));
    expect(find.text('每页 50 项，共 51 项'), findsOneWidget);
    expect(find.text('上一页日程'), findsOneWidget);
    expect(find.text('下一页日程'), findsOneWidget);
    await tester.ensureVisible(find.text('下一页日程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一页日程'));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleMissionRow), findsOneWidget);
    expect(find.text('完整日程 50'), findsOneWidget);
    await tester.ensureVisible(find.text('上一页日程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上一页日程'));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleMissionRow), findsNWidgets(50));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('首页 2–4 项由可见高度和实际字高决定，另有项合成底部短计数', (tester) async {
    final now = DateTime.utc(2026, 11, 2, 6, 29);
    final items = display.groupMissionsForDisplay([
      for (var index = 0; index < 8; index++)
        example(
          '日程任务 $index',
          fixed: true,
          start: now.add(Duration(minutes: index * 60)),
        ),
    ], now: now).fixed;
    Future<void> pump({
      required double visibleHeight,
      required double scale,
    }) async {
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
            body: SingleChildScrollView(
              child: ScheduleSection(
                items: items,
                selectedDate: DateUtils.dateOnly(now),
                clock: () => now,
                onOpenMission: (_) {},
                onOpenAll: () {},
                visibleHeight: visibleHeight,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(visibleHeight: 900, scale: 1);
    expect(find.byType(ScheduleMissionRow), findsNWidgets(4));
    expect(find.text('另有 4 项'), findsOneWidget);
    // 卡头只保留一个“查看全部”，底部短计数不重复同一文案。
    expect(find.text('查看全部 ›'), findsOneWidget);
    expect(find.textContaining('查看全部'), findsOneWidget);
    expect(find.byKey(const Key('schedule-more')), findsOneWidget);

    await pump(visibleHeight: 480, scale: 1);
    expect(find.byType(ScheduleMissionRow), findsNWidgets(2));
    expect(find.text('另有 6 项'), findsOneWidget);

    await pump(visibleHeight: 900, scale: 2);
    expect(find.byType(ScheduleMissionRow), findsNWidgets(3));
    expect(find.text('另有 5 项'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('窗口覆盖开始前、空档、全部结束和空列表', () {
    // MissionService in helper prepares timezone data.
    testApp(ControlledQueryRepository());
    final start = DateTime.utc(2026, 10, 23);
    final items = display.groupMissionsForDisplay([
      for (var i = 0; i < 12; i++)
        example('$i', fixed: true, start: start.add(Duration(hours: i))),
    ]).fixed;
    expect(display.schedulePreview([], start), isEmpty);
    expect(
      display
          .schedulePreview(items, start.subtract(const Duration(hours: 1)))
          .first
          .id,
      '0',
    );
    expect(
      display
          .schedulePreview(
            items,
            start.add(const Duration(hours: 5, minutes: 30)),
          )
          .first
          .id,
      '5',
    );
    expect(
      display
          .schedulePreview(items, start.add(const Duration(days: 1)))
          .last
          .id,
      '11',
    );
  });
}
