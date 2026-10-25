import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/presentation/today/schedule_section.dart';
import 'package:mission_book/presentation/today/today_display.dart' as display;

import 'today_page_test.dart' show ControlledQueryRepository, example, testApp;

void main() {
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
    expect(find.byType(LinearProgressIndicator), findsNothing);
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
