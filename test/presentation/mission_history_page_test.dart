import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/presentation/missions/history/mission_history_page.dart';
import 'package:timezone/timezone.dart' as tz;

/// 只模拟读取失败，创建与执行仍走真实仓储和事务。
class _HistoryRepository extends DriftMissionRepository {
  _HistoryRepository(super.database, {required super.clock});
  bool failReads = false;

  @override
  Future<List<MissionDetail>> findFinished() {
    if (failReads) return Future.error(StateError('模拟历史读取失败'));
    return super.findFinished();
  }

  @override
  Future<List<MissionDetail>> findCancelled() {
    if (failReads) return Future.error(StateError('模拟取消记录读取失败'));
    return super.findCancelled();
  }
}

void main() {
  late AppDatabase database;
  late _HistoryRepository repository;
  late MissionService service;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 10, 25, 12);
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = _HistoryRepository(database, clock: () => now);
    service = MissionService(repository, clock: () => now);
  });

  tearDown(() async {
    await service.dispose();
    await database.close();
  });

  Future<String> create(String title, {String zone = 'Asia/Shanghai'}) async {
    final local = tz.TZDateTime.from(now, tz.getLocation(zone));
    String two(int value) => value.toString().padLeft(2, '0');
    final day = '${local.year}-${two(local.month)}-${two(local.day)}';
    await service.create(
      title: title,
      scheduledDate: day,
      timeZone: zone,
      plannedDurationMinutes: 20,
      verificationPolicy: VerificationPolicy.selfReport,
    );
    final scheduled = await service.findScheduledOn(scheduledDate: day);
    return scheduled
        .singleWhere((item) => item.mission.title == title)
        .mission
        .id;
  }

  Future<void> finish(String id) async {
    for (final type in [
      ExecutionEventType.start,
      ExecutionEventType.pause,
      ExecutionEventType.end,
    ]) {
      final detail = (await service.findDetail(missionId: id))!;
      await service.execute(
        service.prepareExecution(
          detail: detail,
          type: type,
          report: type == ExecutionEventType.end
              ? UserReportedResult.completed
              : null,
        ),
      );
      now = now.add(const Duration(minutes: 1));
    }
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MissionHistoryPage(service: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('执行与取消记录按设备日期和时间显示，不沿用各自排期时区', (tester) async {
    // 固定同一 UTC 时刻，选一个与设备日期不同的排期时区；不依赖运行当天。
    final zone = now.toLocal().day == 26
        ? 'Pacific/Honolulu'
        : 'Pacific/Kiritimati';
    final doneId = await create('跨时区完成', zone: zone);
    await finish(doneId);
    final end = now.subtract(const Duration(minutes: 1));
    final cancelledId = await create('跨时区取消', zone: zone);
    await service.cancel(missionId: cancelledId);

    String day(DateTime instant) {
      final local = instant.toLocal();
      return '${local.year}年${local.month}月${local.day}日';
    }

    String clock(DateTime instant) {
      final local = instant.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    expect(
      tz.TZDateTime.from(end, tz.getLocation(zone)).day,
      isNot(end.toLocal().day),
    );
    await open(tester);
    expect(find.text(day(end)), findsOneWidget);
    expect(find.text(clock(end)), findsOneWidget);
    expect(find.byKey(ValueKey('history-record-$doneId')), findsOneWidget);
    await tester.tap(find.text('已取消'));
    await tester.pumpAndSettle();
    expect(find.text(day(now)), findsOneWidget);
    expect(find.text(clock(now)), findsOneWidget);
    expect(find.byKey(ValueKey('history-record-$cancelledId')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首次读取失败显示重试，恢复后读回真实记录', (tester) async {
    final id = await create('首次失败后恢复');
    await finish(id);
    repository.failReads = true;
    await open(tester);
    expect(find.text('还没有执行结束的记录'), findsNothing);
    repository.failReads = false;
    await tester.tap(find.text('记录读取失败，点击重试'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('history-record-$id')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final cancelled in [false, true]) {
    testWidgets('${cancelled ? '取消' : '执行'}记录刷新失败保留快照并提示，重试成功清除提示', (
      tester,
    ) async {
      final id = await create('保留可读历史');
      if (cancelled) {
        await service.cancel(missionId: id);
      } else {
        await finish(id);
      }
      await open(tester);
      if (cancelled) {
        await tester.tap(find.text('已取消'));
        await tester.pumpAndSettle();
      }
      repository.failReads = true;
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;
      expect(find.byKey(ValueKey('history-record-$id')), findsOneWidget);
      expect(find.text('刷新失败，当前保留上次读取的记录，点击重试'), findsOneWidget);
      expect(tester.takeException(), isNull);

      repository.failReads = false;
      await tester.tap(find.text('刷新失败，当前保留上次读取的记录，点击重试'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('history-record-$id')), findsOneWidget);
      expect(find.text('刷新失败，当前保留上次读取的记录，点击重试'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('切换取消筛选后读取失败，不拿执行记录或旧空态冒充取消结果', (tester) async {
    final id = await create('只属于执行历史');
    await finish(id);
    await open(tester);
    repository.failReads = true;
    await tester.tap(find.text('已取消'));
    await tester.pumpAndSettle();
    expect(find.text('记录读取失败，点击重试'), findsOneWidget);
    expect(find.byKey(ValueKey('history-record-$id')), findsNothing);
    expect(find.text('还没有取消的任务'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
