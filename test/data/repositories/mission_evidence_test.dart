import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'package:mission_book/domain/entities/execution_command.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/rules/execution_time_rules.dart';

void main() {
  late AppDatabase database;
  late DriftMissionRepository repository;
  late MissionService service;
  late DateTime now;
  late DateTime deadline;
  setUp(() {
    now = DateTime.utc(2026, 10, 24);
    deadline = now.add(const Duration(hours: 1));
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftMissionRepository(database, clock: () => now);
    service = MissionService(repository);
  });
  tearDown(() async {
    await service.dispose();
    await database.close();
  });

  Future<void> seed(String id, VerificationPolicy policy) => repository.create(
    mission: Mission(
      id: id,
      title: '材料任务 $id',
      verificationPolicy: policy,
      createdAt: now,
      updatedAt: now,
    ),
    initialSchedule: MissionScheduleRevision(
      id: '$id-schedule',
      missionId: id,
      revisionNumber: 1,
      scheduledDate: '2026-10-24',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
      evidenceDeadlineAt: policy == VerificationPolicy.requiredEvidence
          ? deadline
          : null,
      changedAt: now,
    ),
    executionPlan: ExecutionPlan(
      id: '$id-plan',
      missionId: id,
      objective: '理解事务并给出运行结果',
      verificationCriteria: policy == VerificationPolicy.requiredEvidence
          ? '提交运行截图或文本解释'
          : null,
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<MissionDetail> detail(String id) async =>
      (await repository.findDetail(id))!;

  Future<ExecutionEvent> act(
    String id,
    ExecutionEventType type, {
    UserReportedResult? report,
    bool? submitOptionalEvidence,
  }) async {
    final current = await detail(id);
    return service.execute(
      service.prepareExecution(
        detail: current,
        type: type,
        report: report,
        submitOptionalEvidence: submitOptionalEvidence,
      ),
    );
  }

  Future<void> finish(
    String id, {
    UserReportedResult report = UserReportedResult.completed,
    bool? submitOptionalEvidence,
  }) async {
    await act(id, ExecutionEventType.start);
    now = now.add(const Duration(minutes: 10));
    await act(id, ExecutionEventType.pause);
    now = now.add(const Duration(minutes: 1));
    await act(
      id,
      ExecutionEventType.end,
      report: report,
      submitOptionalEvidence: submitOptionalEvidence,
    );
  }

  EvidenceDraft text(String id, [String content = '第二次写入失败，两次写入一起回滚。']) =>
      EvidenceDraft(
        id: id,
        type: EvidenceType.text,
        source: EvidenceSource.user,
        content: content,
      );

  EvidenceSubmission batch(
    String missionId, {
    String id = 'batch-a',
    List<EvidenceDraft>? items,
  }) => EvidenceSubmission(
    id: id,
    missionId: missionId,
    items: items ?? [text('text-a')],
  );

  test('可选材料直接结束不欠交，关闭后不能追加首批材料', () async {
    await seed('optional', VerificationPolicy.optionalEvidence);
    await finish('optional', submitOptionalEvidence: false);
    final saved = await detail('optional');
    expect(saved.phase, MissionPhase.closed);
    expect(saved.evidence, isEmpty);
    expect(saved.mission.evidenceWaivedAt, isNull);
    expect(saved.events.last.submitOptionalEvidence, isFalse);
    expect(await repository.findPendingEvidence(), isEmpty);
    await expectLater(
      repository.submitEvidence(batch('optional')),
      throwsA(isA<EvidenceConflict>()),
    );
  });

  test('选择稍后提交才待补；放弃成功重试保留首次时刻，不改END', () async {
    await seed('optional', VerificationPolicy.optionalEvidence);
    await finish('optional', submitOptionalEvidence: true);
    final before = await detail('optional');
    expect(before.phase, MissionPhase.evidencePending);
    expect(
      (await repository.findPendingEvidence()).single.mission.id,
      'optional',
    );
    now = now.add(const Duration(minutes: 5));
    await repository.skipOptionalEvidence('optional');
    final waived = (await detail('optional')).mission.evidenceWaivedAt;
    now = now.add(const Duration(days: 3));
    await repository.skipOptionalEvidence('optional');
    final after = await detail('optional');
    expect(after.phase, MissionPhase.closed);
    expect(after.mission.evidenceWaivedAt, waived);
    expect(
      after.events.map((event) => event.id),
      before.events.map((event) => event.id),
    );
    expect(after.events.last.occurredAt, before.events.last.occurredAt);
    expect(after.evidence, isEmpty);
  });

  test('文本与图片引用同批原子保存，图片说明可空，END和Focus保持冻结', () async {
    await seed('optional', VerificationPolicy.optionalEvidence);
    await finish('optional', submitOptionalEvidence: true);
    final before = await detail('optional');
    final oldTimes = calculateExecutionTimes(before.events, now);
    now = now.add(const Duration(days: 2));
    final submission = batch(
      'optional',
      items: [
        text('explanation'),
        const EvidenceDraft(
          id: 'screenshot',
          type: EvidenceType.image,
          source: EvidenceSource.fileSystem,
          attachmentStorageKey: 'attachments/optional/screenshot.png',
          attachmentFileName: '事务运行结果.png',
          attachmentMimeType: 'image/png',
        ),
      ],
    );
    expect(
      await repository.submitEvidence(submission),
      EvidenceSubmissionResult.submitted,
    );
    final after = await detail('optional');
    expect(after.phase, MissionPhase.closed);
    expect(after.evidence, hasLength(2));
    expect(after.evidence.map((item) => item.submissionId).toSet(), {
      'batch-a',
    });
    expect(after.evidence.map((item) => item.submittedAt).toSet(), {now});
    expect(
      after.evidence
          .singleWhere((item) => item.type == EvidenceType.image)
          .content,
      isNull,
    );
    expect(await repository.referencedAttachmentKeys(), {
      'attachments/optional/screenshot.png',
    });
    expect(
      after.events.map((event) => event.id),
      before.events.map((event) => event.id),
    );
    expect(after.events.last.occurredAt, before.events.last.occurredAt);
    final times = calculateExecutionTimes(after.events, now);
    expect(times.focus, oldTimes.focus);
    expect(times.elapsed, oldTimes.elapsed);
  });

  test('第二条写入失败时首条也回滚，原稳定批次可重试', () async {
    await seed('optional', VerificationPolicy.optionalEvidence);
    await finish('optional', submitOptionalEvidence: true);
    final submission = batch(
      'optional',
      items: [text('first'), text('second')],
    );
    await database.customStatement(
      "CREATE TRIGGER fail_second_evidence BEFORE INSERT ON evidence_records WHEN NEW.id = 'second' BEGIN SELECT RAISE(ABORT, '模拟第二条保存失败'); END",
    );
    await expectLater(
      repository.submitEvidence(submission),
      throwsA(isA<SqliteException>()),
    );
    expect((await detail('optional')).phase, MissionPhase.evidencePending);
    expect(await database.select(database.evidenceRecords).get(), isEmpty);
    await database.customStatement('DROP TRIGGER fail_second_evidence');
    expect(
      await repository.submitEvidence(submission),
      EvidenceSubmissionResult.submitted,
    );
    expect((await detail('optional')).evidence, hasLength(2));
  });

  test('成功响应丢失后的重试不重复、不改时刻；同编号换内容拒绝', () async {
    await seed('optional', VerificationPolicy.optionalEvidence);
    await finish('optional', submitOptionalEvidence: true);
    final submission = batch('optional');
    await repository.submitEvidence(submission);
    final submittedAt = (await detail('optional')).evidence.single.submittedAt;
    now = now.add(const Duration(days: 10));
    expect(
      await repository.submitEvidence(submission),
      EvidenceSubmissionResult.submitted,
    );
    final saved = (await detail('optional')).evidence;
    expect(saved, hasLength(1));
    expect(saved.single.submittedAt, submittedAt);
    await expectLater(
      repository.submitEvidence(
        batch('optional', items: [text('text-a', '同编号不同内容')]),
      ),
      throwsA(isA<EvidenceConflict>()),
    );
    expect(
      (await detail('optional')).evidence.single.content,
      submission.items.single.content,
    );
  });

  test('同一批次编号不能挪到另一任务', () async {
    await seed('a', VerificationPolicy.optionalEvidence);
    await finish('a', submitOptionalEvidence: true);
    await seed('b', VerificationPolicy.optionalEvidence);
    await finish('b', submitOptionalEvidence: true);
    await repository.submitEvidence(batch('a'));
    await expectLater(
      repository.submitEvidence(batch('b', items: [text('text-b')])),
      throwsA(isA<EvidenceConflict>()),
    );
    expect((await detail('b')).phase, MissionPhase.evidencePending);
    expect((await detail('b')).evidence, isEmpty);
  });

  test('提交与放弃并发只有一方成功，不能同时有材料和放弃事实', () async {
    for (final submitFirst in [true, false]) {
      final id = submitFirst ? 'submit-first' : 'skip-first';
      await seed(id, VerificationPolicy.optionalEvidence);
      await finish(id, submitOptionalEvidence: true);
      final actions = <Future<void> Function()>[
        () async {
          await repository.submitEvidence(
            batch(id, id: 'batch-$id', items: [text('text-$id')]),
          );
        },
        () => repository.skipOptionalEvidence(id),
      ];
      final outcomes = await Future.wait([
        for (final action in submitFirst ? actions : actions.reversed)
          action().then(
            (_) => true,
            onError: (Object error) {
              expect(error, isA<EvidenceConflict>());
              return false;
            },
          ),
      ]);
      expect(outcomes.where((success) => success), hasLength(1));
      final saved = await detail(id);
      expect(saved.phase, MissionPhase.closed);
      expect(saved.evidence.isNotEmpty, saved.mission.evidenceWaivedAt == null);
    }
  });

  test('两个独立SQLite连接竞争提交和放弃，数据库边界仍只保留一种结果', () async {
    await seed('race', VerificationPolicy.optionalEvidence);
    final source = await detail('race');
    final directory = await Directory.systemTemp.createTemp(
      'mission_evidence_race_',
    );
    final file = File('${directory.path}/race.sqlite');
    final first = AppDatabase(
      executor: NativeDatabase.createInBackground(file),
    );
    final second = AppDatabase(
      executor: NativeDatabase.createInBackground(file),
    );
    final firstRepository = DriftMissionRepository(first, clock: () => now);
    final secondRepository = DriftMissionRepository(second, clock: () => now);
    try {
      await firstRepository.create(
        mission: source.mission,
        initialSchedule: source.schedule,
        executionPlan: source.executionPlan,
      );
      await first.customStatement('PRAGMA busy_timeout = 5000');
      await second.customStatement('PRAGMA busy_timeout = 5000');
      Future<void> localAct(
        ExecutionEventType type, {
        UserReportedResult? report,
        bool? evidence,
      }) async {
        final current = (await firstRepository.findDetail('race'))!;
        await firstRepository.execute(
          service.prepareExecution(
            detail: current,
            type: type,
            report: report,
            submitOptionalEvidence: evidence,
          ),
        );
      }

      await localAct(ExecutionEventType.start);
      await localAct(
        ExecutionEventType.end,
        report: UserReportedResult.completed,
        evidence: true,
      );
      Future<bool> result(Future<Object?> operation) async {
        try {
          await operation;
          return true;
        } on EvidenceConflict {
          return false;
        }
      }

      final outcomes = await Future.wait([
        result(firstRepository.submitEvidence(batch('race'))),
        result(secondRepository.skipOptionalEvidence('race')),
      ]);
      expect(outcomes.where((success) => success), hasLength(1));
      final saved = (await firstRepository.findDetail('race'))!;
      expect(saved.phase, MissionPhase.closed);
      expect(saved.evidence.isNotEmpty, saved.mission.evidenceWaivedAt == null);
    } finally {
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    }
  });

  test('强制材料截止前可提交，之后补算不再产生超时', () async {
    await seed('required', VerificationPolicy.requiredEvidence);
    await finish('required');
    now = deadline.subtract(const Duration(milliseconds: 1));
    expect(
      await repository.submitEvidence(batch('required')),
      EvidenceSubmissionResult.submitted,
    );
    now = deadline.add(const Duration(days: 1));
    expect(await repository.reconcileEvidenceDeadlines(), 0);
    final saved = await detail('required');
    expect(saved.phase, MissionPhase.closed);
    expect(saved.failures, isEmpty);
    expect(
      saved.evidence.single.submittedAt,
      deadline.subtract(const Duration(milliseconds: 1)),
    );
  });

  test('恰等于截止时拒绝材料但提交超时事实，重复提交和补算不重复', () async {
    await seed('required', VerificationPolicy.requiredEvidence);
    await finish('required');
    now = deadline;
    expect(
      await repository.submitEvidence(batch('required')),
      EvidenceSubmissionResult.deadlineMissed,
    );
    final first = await detail('required');
    expect(first.phase, MissionPhase.closed);
    expect(first.evidence, isEmpty);
    expect(first.events.last.userReportedResult, UserReportedResult.completed);
    expect(first.failures.single.trigger, 'EVIDENCE_DEADLINE_MISSED');
    expect(first.failures.single.occurredAt, deadline);
    expect(first.failures.single.createdAt, deadline);
    now = now.add(const Duration(days: 1));
    expect(
      await repository.submitEvidence(batch('required')),
      EvidenceSubmissionResult.deadlineMissed,
    );
    expect(await repository.reconcileEvidenceDeadlines(), 0);
    expect((await detail('required')).failures.single.createdAt, deadline);
  });

  test('晚于截止的END与超时同事务，失败整体回滚，原结束命令能重试', () async {
    await seed('required', VerificationPolicy.requiredEvidence);
    await act('required', ExecutionEventType.start);
    await act('required', ExecutionEventType.pause);
    now = deadline.add(const Duration(minutes: 5));
    final command = service.prepareExecution(
      detail: await detail('required'),
      type: ExecutionEventType.end,
      report: UserReportedResult.completed,
    );
    await database.customStatement(
      "CREATE TRIGGER fail_deadline BEFORE INSERT ON failure_records WHEN NEW.\"trigger\" = 'EVIDENCE_DEADLINE_MISSED' BEGIN SELECT RAISE(ABORT, '模拟超时记录写入失败'); END",
    );
    await expectLater(
      repository.execute(command),
      throwsA(isA<SqliteException>()),
    );
    expect((await detail('required')).phase, MissionPhase.paused);
    expect((await detail('required')).events, hasLength(2));
    expect(await database.select(database.failureRecords).get(), isEmpty);
    await database.customStatement('DROP TRIGGER fail_deadline');
    final end = await repository.execute(command);
    final saved = await detail('required');
    expect(saved.phase, MissionPhase.closed);
    expect(saved.events.last.userReportedResult, UserReportedResult.completed);
    expect(saved.failures.single.occurredAt, end.occurredAt);
    expect(saved.failures.single.createdAt, now);
  });

  test('补算只处理已完成且待补的强制任务，不碰未开始/暂停/未完成', () async {
    await seed('not-started', VerificationPolicy.requiredEvidence);
    await seed('paused', VerificationPolicy.requiredEvidence);
    await act('paused', ExecutionEventType.start);
    await act('paused', ExecutionEventType.pause);
    await seed('not-completed', VerificationPolicy.requiredEvidence);
    await finish('not-completed', report: UserReportedResult.notCompleted);
    await seed('pending', VerificationPolicy.requiredEvidence);
    await finish('pending');
    await seed('running', VerificationPolicy.requiredEvidence);
    await act('running', ExecutionEventType.start);
    now = deadline.add(const Duration(hours: 2));
    expect(await repository.reconcileEvidenceDeadlines(), 1);
    expect(await repository.reconcileEvidenceDeadlines(), 0);
    expect((await detail('not-started')).phase, MissionPhase.notStarted);
    expect((await detail('not-started')).failures, isEmpty);
    expect((await detail('paused')).phase, MissionPhase.paused);
    expect((await detail('paused')).failures, isEmpty);
    expect((await detail('running')).phase, MissionPhase.running);
    expect((await detail('running')).failures, isEmpty);
    expect(
      (await detail('not-completed')).failures.single.trigger,
      'USER_MARKED_NOT_COMPLETED',
    );
    final timedOut = await detail('pending');
    expect(timedOut.failures.single.occurredAt, deadline);
    expect(timedOut.failures.single.createdAt, now);
    expect(timedOut.phase, MissionPhase.closed);
  });

  test('强制材料不提供跳过；任意策略未完成均保留失败且不收首批材料', () async {
    for (final policy in VerificationPolicy.values) {
      final id = policy.name;
      await seed(id, policy);
      await finish(id, report: UserReportedResult.notCompleted);
      final saved = await detail(id);
      expect(saved.phase, MissionPhase.closed);
      expect(saved.failures.single.trigger, 'USER_MARKED_NOT_COMPLETED');
      expect(saved.events.last.submitOptionalEvidence, isNull);
      await expectLater(
        repository.submitEvidence(
          batch(id, id: 'batch-$id', items: [text('text-$id')]),
        ),
        throwsA(isA<EvidenceConflict>()),
      );
      await expectLater(
        repository.skipOptionalEvidence(id),
        throwsA(isA<EvidenceConflict>()),
      );
    }
  });

  test('可选材料的END重试保留选择，同编号更改选择冲突', () async {
    await seed('optional', VerificationPolicy.optionalEvidence);
    await act('optional', ExecutionEventType.start);
    final current = await detail('optional');
    final command = service.prepareExecution(
      detail: current,
      type: ExecutionEventType.end,
      report: UserReportedResult.completed,
      submitOptionalEvidence: true,
    );
    final first = await repository.execute(command);
    now = now.add(const Duration(hours: 2));
    expect((await repository.execute(command)).occurredAt, first.occurredAt);
    expect((await detail('optional')).phase, MissionPhase.evidencePending);
    await expectLater(
      repository.execute(
        ExecutionCommand(
          id: command.id,
          missionId: command.missionId,
          expectedSequence: command.expectedSequence,
          type: command.type,
          userReportedResult: command.userReportedResult,
          submitOptionalEvidence: false,
        ),
      ),
      throwsA(isA<ExecutionConflict>()),
    );
  });
}
