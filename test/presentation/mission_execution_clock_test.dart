import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/presentation/missions/execution/execution_widgets.dart';
import 'package:mission_book/presentation/missions/execution/mission_execution_page.dart';
import 'package:mission_book/presentation/missions/shared/mission_live_status.dart';

import '../data/repositories/mission_cancellation_test.dart' show seedMission;

class _ReadCountingRepository extends DriftMissionRepository {
  _ReadCountingRepository(super.database, {required super.clock});
  int detailReads = 0;

  @override
  Future<MissionDetail?> findDetail(String missionId) {
    detailReads++;
    return super.findDetail(missionId);
  }
}

void main() {
  late AppDatabase database;
  late _ReadCountingRepository repository;
  late MissionService service;
  late DateTime now;
  late MissionDetail detail;
  var clockReads = 0;

  setUp(() async {
    now = DateTime.utc(2026, 10, 23, 6);
    clockReads = 0;
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = _ReadCountingRepository(database, clock: () => now);
    service = MissionService(repository);
    await seedMission(repository, 'clock');
    final initial = (await repository.findDetail('clock'))!;
    await service.execute(
      service.prepareExecution(detail: initial, type: ExecutionEventType.start),
    );
    detail = (await repository.findDetail('clock'))!;
  });

  tearDown(() async {
    await service.dispose();
    await database.close();
  });

  DateTime clock() {
    clockReads++;
    return now;
  }

  Future<void> open(WidgetTester tester, {Widget? home}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home:
            home ??
            MissionExecutionPage(
              detail: detail,
              service: service,
              clock: clock,
            ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectFocus(WidgetTester tester, Duration focus) {
    expect(
      tester.widget<ExecutionFocusRing>(find.byType(ExecutionFocusRing)).focus,
      focus,
    );
  }

  testWidgets('执行页失去焦点但仍可见时，圆环和数字持续更新', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    now = now.add(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 12));
    expectFocus(tester, const Duration(seconds: 12));
    expect(find.text('00:12'), findsOneWidget);
  });

  testWidgets('在无焦点状态进入执行页也能自动计时', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await open(tester);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expectFocus(tester, const Duration(seconds: 3));
  });

  testWidgets('频繁主题依赖更新不会不断重启执行页的一秒刷新', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    late StateSetter update;
    var revision = 0;
    await open(
      tester,
      home: StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return Theme(
            data: AppTheme.light.copyWith(
              visualDensity: VisualDensity(horizontal: revision.isEven ? 0 : 1),
            ),
            child: MissionExecutionPage(
              detail: detail,
              service: service,
              clock: clock,
            ),
          );
        },
      ),
    );
    for (var i = 0; i < 19; i++) {
      now = now.add(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      update(() => revision++);
      await tester.pump();
    }
    // 最后一次外部重建后不足一秒，旧实现从此刻重新等一秒而停止更新。
    now = now.add(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expectFocus(tester, const Duration(milliseconds: 4200));
  });

  testWidgets('持续三分钟不点击仍更新，且不逐秒查库或追加事件', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await open(tester);
    final reads = repository.detailReads;
    for (var second = 1; second <= 180; second++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expectFocus(tester, Duration(seconds: second));
    }
    expect(repository.detailReads, reads);
    expect((await repository.findDetail('clock'))!.events, hasLength(1));
  });

  testWidgets('反复隐藏及后台恢复后追上真实时钟，恢复后继续自动刷新', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await open(tester);
    for (var round = 0; round < 3; round++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      final reads = clockReads;
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 2));
      expect(clockReads, reads);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expectFocus(tester, Duration(seconds: (round + 1) * 121 - 1));
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expectFocus(tester, Duration(seconds: (round + 1) * 121));
    }
    expect((await repository.findDetail('clock'))!.events, hasLength(1));
  });

  testWidgets('列表实时标签在可见但无焦点以及频繁重建时不停止', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    late StateSetter update;
    await open(
      tester,
      home: StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return Scaffold(
            body: MissionLiveStatus(
              phase: MissionPhase.running,
              events: detail.events,
              clock: clock,
            ),
          );
        },
      ),
    );
    for (var i = 0; i < 19; i++) {
      now = now.add(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      update(() {});
      await tester.pump();
    }
    now = now.add(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('执行中 · 专注 00:04'), findsOneWidget);
  });

  testWidgets('执行路由反复遮挡后立即追上时钟并继续刷新', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    late StateSetter update;
    var visible = true;
    await open(
      tester,
      home: StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return TickerMode(
            enabled: visible,
            child: MissionExecutionPage(
              detail: detail,
              service: service,
              clock: clock,
            ),
          );
        },
      ),
    );
    for (var round = 0; round < 3; round++) {
      update(() => visible = false);
      await tester.pump();
      final reads = clockReads;
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(clockReads, reads);
      update(() => visible = true);
      await tester.pump();
      expectFocus(tester, Duration(seconds: (round + 1) * 61 - 1));
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expectFocus(tester, Duration(seconds: (round + 1) * 61));
    }
  });

  testWidgets('暂停弹窗可取消、留空或填原因；确认后冻结，继续后自动刷新', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await open(tester);
    expect(find.text('暂停说明（选填）'), findsNothing);
    await tester.tap(find.byKey(const Key('execution-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(ExecutionPauseDialog), findsOneWidget);
    // 打开弹窗不是已经暂停；取消不写事实。
    expect((await repository.findDetail('clock'))!.events, hasLength(1));
    await tester.tap(find.byKey(const Key('pause-cancel')));
    await tester.pumpAndSettle();
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expectFocus(tester, const Duration(seconds: 5));
    await tester.tap(find.byKey(const Key('execution-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pause-confirm')));
    await tester.pumpAndSettle();
    var latest = (await repository.findDetail('clock'))!;
    expect(latest.events, hasLength(2));
    expect(latest.events.last.reason, isNull);
    final frozenReads = clockReads;
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expectFocus(tester, const Duration(seconds: 5));
    expect(clockReads, frozenReads);
    await tester.tap(find.byKey(const Key('execution-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(ExecutionPauseDialog), findsNothing);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expectFocus(tester, const Duration(seconds: 8));
    await tester.tap(find.byKey(const Key('execution-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pause-reason')), '  接个电话  ');
    await tester.tap(find.byKey(const Key('pause-confirm')));
    await tester.pumpAndSettle();
    latest = (await repository.findDetail('clock'))!;
    expect(latest.events, hasLength(4));
    expect(latest.events.last.reason, '接个电话');
    expect(latest.phase, MissionPhase.paused);
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧暂停弹窗不会覆盖其它入口已暂停和恢复的新事实', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await open(tester);
    await tester.tap(find.byKey(const Key('execution-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pause-reason')), '旧弹窗原因');
    for (final type in [ExecutionEventType.pause, ExecutionEventType.resume]) {
      final latest = (await repository.findDetail('clock'))!;
      await service.execute(
        service.prepareExecution(detail: latest, type: type),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('pause-confirm')));
    await tester.pumpAndSettle();
    final latest = (await repository.findDetail('clock'))!;
    expect(latest.events, hasLength(3));
    expect(latest.phase, MissionPhase.running);
    expect(find.textContaining('执行记录已变化'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏双倍字体与键盘下暂停弹窗可滚动确认', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await open(
      tester,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: MissionExecutionPage(
          detail: detail,
          service: service,
          clock: clock,
        ),
      ),
    );
    tester.view.physicalSize = const Size(320, 640);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('execution-toggle')));
    await tester.tap(find.byKey(const Key('execution-toggle')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pause-reason')), '稍后回来');
    await tester.ensureVisible(find.byKey(const Key('pause-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pause-confirm')));
    await tester.pumpAndSettle();
    expect((await repository.findDetail('clock'))!.events.last.reason, '稍后回来');
    expect(tester.takeException(), isNull);
  });
}
