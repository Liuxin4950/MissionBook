import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_schedule.dart';
import 'package:mission_book/application/assistant/assistant_tools.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';

/// 单项、批量与延长入口共用同一时长上限；Schema 与领域规则一致。
void main() {
  late AppDatabase db;
  late DriftMissionRepository repo;
  late MissionService service;
  late GoalService goals;
  late AssistantTools tools;
  final now = DateTime.utc(2026, 11, 10, 2);
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repo = DriftMissionRepository(db, clock: () => now);
    service = MissionService(repo, clock: () => now);
    goals = GoalService(DriftGoalRepository(db));
    tools = AssistantTools(
      unifiedReader: DriftUnifiedReader(db),
      missions: service,
      goals: goals,
      resolveCall: (callId) => throw StateError('本测试只校验参数'),
      clock: () => now,
    );
  });
  tearDown(() async {
    await service.dispose();
    await goals.dispose();
    await db.close();
  });

  test('创建与编辑统一执行 1440 分钟上限', () async {
    expect(
      () => service.prepareCreation(
        title: '超长任务',
        scheduledDate: '2026-11-10',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: maxPlannedDurationMinutes + 1,
      ),
      throwsArgumentError,
    );
    final creation = service.prepareCreation(
      title: '边界任务',
      scheduledDate: '2026-11-10',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: maxPlannedDurationMinutes,
    );
    await service.createPrepared(creation);
    final detail = (await repo.findDetail(creation.mission.id))!;
    await expectLater(
      service.edit(
        original: detail,
        title: detail.mission.title,
        objective: detail.executionPlan.objective,
        scheduledDate: '2026-11-10',
        plannedDurationMinutes: maxPlannedDurationMinutes + 1,
        timePolicy: TimePolicy.flexible,
      ),
      throwsArgumentError,
    );
    expect(
      (await repo.findDetail(creation.mission.id))!
          .schedule
          .plannedDurationMinutes,
      maxPlannedDurationMinutes,
    );
  });

  test('既有超限排期仍可读取并保留；新改大值仍拒绝', () async {
    final creation = service.prepareCreation(
      title: '既有超长排期',
      scheduledDate: '2026-11-10',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 60,
    );
    await service.createPrepared(creation);
    await (db.update(db.missionScheduleRevisions)
          ..where((row) => row.id.equals(creation.schedule.id)))
        .write(
          const MissionScheduleRevisionsCompanion(
            plannedDurationMinutes: Value(maxPlannedDurationMinutes + 1),
          ),
        );

    final legacy = (await repo.findDetail(creation.mission.id))!;
    expect(legacy.schedule.plannedDurationMinutes, maxPlannedDurationMinutes + 1);
    await service.edit(
      original: legacy,
      title: '既有排期可编辑其他字段',
      objective: legacy.executionPlan.objective,
      scheduledDate: legacy.schedule.scheduledDate,
      plannedDurationMinutes: legacy.schedule.plannedDurationMinutes,
      timePolicy: legacy.schedule.timePolicy,
      fixedStartAt: legacy.schedule.fixedStartAt,
    );
    final afterEdit = (await repo.findDetail(creation.mission.id))!;
    expect(afterEdit.mission.title, '既有排期可编辑其他字段');
    expect(afterEdit.schedule.plannedDurationMinutes, maxPlannedDurationMinutes + 1);

    await expectLater(
      service.edit(
        original: afterEdit,
        title: afterEdit.mission.title,
        objective: afterEdit.executionPlan.objective,
        scheduledDate: afterEdit.schedule.scheduledDate,
        plannedDurationMinutes: maxPlannedDurationMinutes + 2,
        timePolicy: afterEdit.schedule.timePolicy,
        fixedStartAt: afterEdit.schedule.fixedStartAt,
      ),
      throwsArgumentError,
    );
  });

  test('既有超限EXTEND仍可读取；新EXTEND在事务内拒绝', () async {
    final creation = service.prepareCreation(
      title: '既有超长延长',
      scheduledDate: '2026-11-10',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    await service.createPrepared(creation);
    var detail = (await repo.findDetail(creation.mission.id))!;
    await service.execute(
      service.prepareExecution(
        detail: detail,
        type: ExecutionEventType.start,
        commandId: 'legacy-start',
      ),
    );
    await db.into(db.executionEvents).insert(
      ExecutionEventsCompanion.insert(
        id: 'legacy-extend',
        missionId: creation.mission.id,
        sequence: 2,
        type: 'EXTEND',
        occurredAt: now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
        grantedDurationMinutes: const Value(maxPlannedDurationMinutes + 1),
      ),
    );

    detail = (await repo.findDetail(creation.mission.id))!;
    expect(detail.events.last.grantedDurationMinutes, maxPlannedDurationMinutes + 1);
    await expectLater(
      service.execute(
        service.prepareExecution(
          detail: detail,
          type: ExecutionEventType.extend,
          minutes: maxPlannedDurationMinutes + 1,
          commandId: 'new-extend-over-limit',
        ),
      ),
      throwsArgumentError,
    );
    expect((await repo.findDetail(creation.mission.id))!.events, hasLength(2));
  });

  test('助手批量改期省略时长时保留既有超限排期', () async {
    final creation = service.prepareCreation(
      title: '批量保留旧时长',
      scheduledDate: '2026-11-10',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 60,
    );
    await service.createPrepared(creation);
    await (db.update(db.missionScheduleRevisions)
          ..where((row) => row.id.equals(creation.schedule.id)))
        .write(
          const MissionScheduleRevisionsCompanion(
            plannedDurationMinutes: Value(maxPlannedDurationMinutes + 1),
          ),
        );

    final scheduler = AssistantScheduleService(
      missions: service,
      clock: () => now,
      timeZone: 'Asia/Shanghai',
    );
    final draft = await scheduler.prepare({
      'title': '只调整日期',
      'items': [
        {
          'itemId': 'legacy-reschedule',
          'kind': 'RESCHEDULE',
          'missionId': creation.mission.id,
          'scheduledDate': '2026-11-11',
        },
      ],
    });
    final proposal = scheduler.build(draft.input, draft.originals, 'legacy-plan');
    expect(
      proposal.items.single.schedule.plannedDurationMinutes,
      maxPlannedDurationMinutes + 1,
    );
    await service.applyPlan(proposal);
    final saved = (await repo.findDetail(creation.mission.id))!;
    expect(saved.schedule.scheduledDate, '2026-11-11');
    expect(saved.schedule.plannedDurationMinutes, maxPlannedDurationMinutes + 1);
  });

  test('EXTEND 超限在事务内拒绝，不产生事件', () async {
    final creation = service.prepareCreation(
      title: '延长任务',
      scheduledDate: '2026-11-10',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    await service.createPrepared(creation);
    var detail = (await repo.findDetail(creation.mission.id))!;
    await service.execute(
      service.prepareExecution(
        detail: detail,
        type: ExecutionEventType.start,
        commandId: 'limit-start',
      ),
    );
    detail = (await repo.findDetail(creation.mission.id))!;
    await expectLater(
      service.execute(
        service.prepareExecution(
          detail: detail,
          type: ExecutionEventType.extend,
          minutes: maxPlannedDurationMinutes + 1,
          commandId: 'limit-extend',
        ),
      ),
      throwsArgumentError,
    );
    expect((await repo.findDetail(creation.mission.id))!.events, hasLength(1));
  });

  test('工具 Schema 与批量计划使用同一上限常量', () {
    expect(
      tools.validate('createMission', {
        'title': '超长任务',
        'scheduledDate': '2026-11-10',
        'plannedMinutes': maxPlannedDurationMinutes + 1,
      }),
      isNotNull,
    );
    expect(
      tools.validate('executeMission', {
        'missionId': 'any',
        'type': 'EXTEND',
        'minutes': maxPlannedDurationMinutes + 1,
      }),
      isNotNull,
    );
    final items =
        (AssistantScheduleService.schema['properties'] as Map)['items'] as Map;
    final itemSchema = (items['items'] as Map)['properties'] as Map;
    expect(
      (itemSchema['plannedMinutes'] as Map)['maximum'],
      maxPlannedDurationMinutes,
    );
  });
}