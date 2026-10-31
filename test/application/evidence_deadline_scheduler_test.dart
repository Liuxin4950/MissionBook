import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/evidence_deadline_scheduler.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';

class _Repository extends DriftMissionRepository {
  _Repository(super.database, {required super.clock});
  int checks = 0;
  bool fail = false;
  List<MissionDetail>? stalePending;
  Completer<void>? gate;

  @override
  Future<int> reconcileEvidenceDeadlines() async {
    checks++;
    await gate?.future;
    if (fail) throw StateError('测试数据库暂不可用');
    return super.reconcileEvidenceDeadlines();
  }

  @override
  Future<List<MissionDetail>> findPendingEvidence() async =>
      stalePending ?? await super.findPendingEvidence();
}

void main() {
  late AppDatabase db;
  late _Repository repository;
  late MissionService missions;
  late EvidenceDeadlineScheduler scheduler;
  late DateTime now;
  final deadline = DateTime.utc(2030, 1, 1, 3);
  late String id;
  final errors = <Object>[];

  setUp(() async {
    now = deadline.subtract(const Duration(minutes: 5));
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = _Repository(db, clock: () => now);
    missions = MissionService(repository, clock: () => now);
    await missions.create(
      title: '提交运行截图',
      scheduledDate: '2030-01-01',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 15,
      verificationPolicy: VerificationPolicy.requiredEvidence,
      verificationCriteria: '一张运行截图',
      evidenceDeadlineAt: deadline,
    );
    id = (await missions.findAllDetails()).single.mission.id;
    for (final type in [ExecutionEventType.start, ExecutionEventType.end]) {
      await missions.execute(
        missions.prepareExecution(
          detail: (await missions.findDetail(missionId: id))!,
          type: type,
          report: type == ExecutionEventType.end
              ? UserReportedResult.completed
              : null,
        ),
      );
    }
    errors.clear();
    scheduler = EvidenceDeadlineScheduler(
      missions: missions,
      now: () => now,
      onError: errors.add,
    );
  });

  tearDown(() async {
    await scheduler.dispose();
    await missions.dispose();
    await db.close();
  });

  Future<void> settleDatabase(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        if ((await missions.findDetail(missionId: id))!.phase ==
            MissionPhase.closed) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      fail('截止调度未保存超时事实');
    });
  }

  testWidgets('App 使用的真实调度器在到点后写入一次超时，不重复零延时调度', (tester) async {
    await scheduler.start();
    expect(
      (await missions.findDetail(missionId: id))!.phase,
      MissionPhase.evidencePending,
    );
    now = deadline;
    await tester.pump(const Duration(minutes: 5));
    await settleDatabase(tester);
    await tester.pump();
    final checks = repository.checks;
    await tester.pump(const Duration(minutes: 1));
    expect(repository.checks, checks);
    expect((await db.select(db.failureRecords).get()), hasLength(1));
    expect(errors, isEmpty);
  });

  testWidgets('后台不保持前台计时，回前台主动补算过期事实', (tester) async {
    await scheduler.start();
    scheduler.setForeground(false);
    final checks = repository.checks;
    now = deadline.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 6));
    expect(repository.checks, checks);
    expect(
      (await missions.findDetail(missionId: id))!.phase,
      MissionPhase.evidencePending,
    );
    scheduler.setForeground(true);
    await settleDatabase(tester);
    expect((await db.select(db.failureRecords).get()), hasLength(1));
  });

  testWidgets('持续过期的异常快照只立即复查一次，之后按30秒恢复间隔重试', (tester) async {
    repository.stalePending = [(await missions.findDetail(missionId: id))!];
    now = deadline;
    await scheduler.start();
    final checks = repository.checks;
    expect(checks, lessThanOrEqualTo(3));
    await tester.pump(const Duration(seconds: 29));
    expect(repository.checks, checks);
    repository.stalePending = null;
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    expect(repository.checks, greaterThan(checks));
  });

  test('数据库失败使用恢复间隔重试，不产生密集循环', () async {
    await scheduler.dispose();
    repository.fail = true;
    scheduler = EvidenceDeadlineScheduler(
      missions: missions,
      now: () => now,
      onError: errors.add,
      retryDelay: const Duration(milliseconds: 150),
    );
    await scheduler.start();
    expect(errors, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repository.checks, 1);
    for (var i = 0; i < 100 && repository.checks == 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(repository.checks, 2);
    expect(errors, hasLength(2));
    await scheduler.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 170));
    expect(repository.checks, 2);
  });

  test('关闭等待在途补算，迟到查询结束后不再安排计时器', () async {
    repository.gate = Completer<void>();
    final refreshing = scheduler.refreshSafely();
    var closed = false;
    final closing = scheduler.dispose().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    repository.gate!.complete();
    await Future.wait([refreshing, closing]);
    expect(closed, isTrue);
    final checks = repository.checks;
    scheduler.setForeground(true);
    await scheduler.refreshSafely();
    expect(repository.checks, checks);
  });
}
