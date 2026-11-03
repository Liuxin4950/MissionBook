import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/record_draft.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/domain/entities/mission_maintenance.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/execution_command.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/user_execution_report.dart';

void main() {
  late AppDatabase db;
  late DriftMissionRepository repo;
  late MissionService service;
  final now = DateTime.utc(2026, 11, 3, 4);
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = DriftMissionRepository(db, clock: () => now);
    service = MissionService(repo, clock: () => now);
  });
  tearDown(() async {
    await service.dispose();
    await db.close();
  });
  Future<String> seed(String title, {String date = '2026-11-02'}) async {
    final c = service.prepareCreation(
      title: title,
      scheduledDate: date,
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
    );
    await service.createPrepared(c);
    return c.mission.id;
  }

  Future<void> complete(String id) async {
    final d = (await repo.findDetail(id))!;
    await repo.reportExecution(
      UserExecutionReport(
        id: 'report-$id',
        missionId: id,
        occurrenceDate: '2026-11-02',
        timeZoneId: 'Asia/Shanghai',
        basis: '昨天已做完',
      ),
      expectedSequence: d.lastSequence,
      scheduleId: d.schedule.id,
      result: UserReportedResult.completed,
    );
  }

  test('物理删除整个历史范围，保留今天任务，重复提交返回同一回执', () async {
    final a = await seed('历史一');
    final b = await seed('历史二');
    final today = await seed('今天', date: '2026-11-03');
    await complete(a);
    final p = await service.prepareMaintenance(
      action: MissionMaintenanceAction.delete,
      beforeDate: '2026-11-03',
    );
    final result = await service.applyMaintenance(
      p,
      operationId: 'delete-past',
    );
    expect(result['count'], 2);
    expect(await repo.findDetail(a), isNull);
    expect(await repo.findDetail(b), isNull);
    expect(await repo.findDetail(today), isNotNull);
    expect(
      await service.applyMaintenance(p, operationId: 'delete-past'),
      result,
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test('撤销归档材料仍可读取，物理删除清除归档并保留独立来源记录', () async {
    final id = await seed('材料任务');
    final records = RecordService(
      DriftRecordRepository(db, clock: () => now),
      service,
      service.attachments,
    );
    await records.save(
      const RecordDraft(
        id: 'source',
        type: ContentType.text,
        source: ContentSource.user,
        content: '原始独立记录',
      ),
      missionId: id,
    );
    await complete(id);
    final before = (await repo.findDetail(id))!;
    final materialId = before.evidence.single.id;
    final reset = await service.prepareMaintenance(
      action: MissionMaintenanceAction.reset,
      ids: [id],
    );
    await service.applyMaintenance(reset, operationId: 'with-material');
    final reader = DriftUnifiedReader(db);
    final material = await reader.evidenceContent(materialId);
    expect(material['text'], '原始独立记录');
    expect(material['revoked'], isTrue);
    final history = await reader.records(id, 'revoked');
    expect(history['total'], 3);
    await expectLater(
      repo.submitEvidence(
        EvidenceSubmission(
          id: before.evidence.single.submissionId,
          missionId: id,
          items: before.evidence,
        ),
      ),
      throwsA(isA<EvidenceConflict>()),
    );
    await records.useAsMaterial('source', id);
    final resubmitted = (await repo.findDetail(id))!.evidence.single;
    expect(resubmitted.id, isNot(materialId));
    expect(resubmitted.content, '原始独立记录');
    expect((await reader.evidenceContent(materialId))['revoked'], isTrue);
    final deletion = await service.prepareMaintenance(
      action: MissionMaintenanceAction.delete,
      ids: [id],
    );
    await service.applyMaintenance(deletion);
    expect(await service.executionArchives(id), isEmpty);
    expect((await db.select(db.records).get()).single.content, '原始独立记录');
    expect((await reader.evidenceContent(materialId))['ok'], isFalse);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('预览后范围新增任务时整批零写入', () async {
    final a = await seed('原任务');
    final p = await service.prepareMaintenance(
      action: MissionMaintenanceAction.delete,
      beforeDate: '2026-11-03',
    );
    await seed('新增任务');
    await expectLater(
      service.applyMaintenance(p, operationId: 'changed-scope'),
      throwsA(isA<MissionEditConflict>()),
    );
    expect(await repo.findDetail(a), isNotNull);
    expect(await repo.findOperationReceipt('changed-scope'), isNull);
  });
  test('批量取消只取消未开始任务，跳过结束任务', () async {
    final a = await seed('待取消');
    final b = await seed('已完成');
    await complete(b);
    final p = await service.prepareMaintenance(
      action: MissionMaintenanceAction.cancel,
      ids: [a, b],
    );
    final r = await service.applyMaintenance(p);
    expect(r['count'], 1);
    expect(r['skippedIds'], [b]);
    expect((await repo.findDetail(a))!.phase, MissionPhase.cancelled);
    expect((await repo.findDetail(b))!.endReportedCompleted, isTrue);
  });
  test('撤销后原报告归档，完整阶段回到未开始，原指令不能重放', () async {
    final id = await seed('误标任务');
    await complete(id);
    final old = (await repo.findDetail(id))!;
    final p = await service.prepareMaintenance(
      action: MissionMaintenanceAction.reset,
      ids: [id],
    );
    await service.applyMaintenance(p, operationId: 'reset');
    final d = (await repo.findDetail(id))!;
    expect(d.phase, MissionPhase.notStarted);
    expect(d.events, isEmpty);
    expect(d.userReports, isEmpty);
    expect(d.schedule.revisionNumber, old.schedule.revisionNumber + 1);
    final archives = await service.executionArchives(id);
    expect(archives, hasLength(1));
    expect(archives.single['execution_events'], hasLength(1));
    expect(archives.single['user_execution_reports'], hasLength(1));
    await service.edit(
      original: d,
      title: d.mission.title,
      objective: d.executionPlan.objective,
      scheduledDate: '2026-11-05',
      plannedDurationMinutes: 25,
      timePolicy: TimePolicy.flexible,
    );
    final edited = (await repo.findDetail(id))!;
    expect(edited.schedule.scheduledDate, '2026-11-05');
    expect(edited.phase, MissionPhase.notStarted);
    expect(await service.executionArchives(id), hasLength(1));
    await expectLater(
      repo.execute(
        ExecutionCommand(
          id: old.events.single.id,
          missionId: id,
          expectedSequence: 0,
          type: ExecutionEventType.end,
          userReportedResult: UserReportedResult.completed,
        ),
      ),
      throwsA(isA<ExecutionConflict>()),
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test('全范围摘要给出精确数量和完整阶段计数，不需要读完每页', () async {
    for (var i = 0; i < 23; i++) {
      await seed('历史$i');
    }
    await seed('今天', date: '2026-11-03');
    final reader = DriftUnifiedReader(db);
    final summary = await reader.getMission(
      beforeDate: '2026-11-03',
      summaryOnly: true,
    );
    expect(summary['total'], 23);
    expect(summary['countsByPhase'], {'notStarted': 23});
    expect(summary['summaryComplete'], isTrue);
    expect(summary['items'], isEmpty);
    final page = await reader.getMission(
      beforeDate: '2026-11-03',
      phase: 'notStarted',
    );
    expect(page['items'] as List, hasLength(20));
    expect(page['nextOffset'], 20);
  });
}
