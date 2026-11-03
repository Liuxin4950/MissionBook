import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/assistant/assistant_schedule.dart';
import 'package:mission_book/application/assistant/assistant_operation_result.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_creation.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/schedule_proposal.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';

import '../../support/assistant_fakes.dart';

void main() {
  late AppDatabase database;
  late MissionService missions;
  late GoalService goals;
  late AssistantScheduleService plans;
  AssistantController? controller;
  final now = DateTime.utc(2026, 10, 29, 0);

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(database, clock: () => now),
      clock: () => now,
    );
    goals = GoalService(DriftGoalRepository(database));
    plans = AssistantScheduleService(
      missions: missions,
      clock: () => now,
      timeZone: 'Asia/Shanghai',
    );
    controller = null;
  });
  tearDown(() async {
    await controller?.close();
    await missions.dispose();
    await goals.dispose();
    await database.close();
  });

  Map<String, Object?> createRow(
    String id, {
    String? start,
    String date = '2026-10-29',
  }) => {
    'itemId': id,
    'kind': 'CREATE',
    'title': '任务 $id',
    'scheduledDate': date,
    'plannedMinutes': 50,
    'fixedStartLocal': ?start,
  };
  Future<MissionCreation> seed(String title, {String? start}) async {
    final time = start?.split(':').map(int.parse).toList();
    final request = missions.prepareCreation(
      title: title,
      scheduledDate: '2026-10-29',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 50,
      timePolicy: start == null ? TimePolicy.flexible : TimePolicy.fixed,
      fixedStartAt: time == null
          ? null
          : DateTime.utc(2026, 10, 29, time[0] - 8, time[1]),
    );
    await missions.createPrepared(request);
    return request;
  }

  Future<ScheduleProposal> build(
    List<Map<String, Object?>> items, {
    String id = 'plan-request',
  }) async {
    final draft = await plans.prepare({'title': '今天的安排', 'items': items});
    return plans.build(draft.input, draft.originals, id);
  }

  Future<void> waitFor(bool Function() predicate) async {
    for (var i = 0; i < 200; i++) {
      if (predicate()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('等待计划预览超时');
  }

  test('新建与改期整批保存，固定回执使重复提交不新增任务或版本', () async {
    final original = await seed('原有任务');
    final plan = await build([
      createRow('new', start: '09:00'),
      {
        'itemId': 'move',
        'kind': 'RESCHEDULE',
        'missionId': original.mission.id,
        'scheduledDate': '2026-10-30',
        'plannedMinutes': 40,
      },
    ]);
    expect(await missions.checkPlan(plan), isEmpty);
    final receipt = await missions.applyPlan(plan);
    expect(jsonDecode(receipt.resultJson)['savedCount'], 2);
    final moved = (await missions.findDetail(missionId: original.mission.id))!;
    expect(moved.schedule.scheduledDate, '2026-10-30');
    expect(moved.executionPlan.id, original.plan.id);
    expect((await missions.applyPlan(plan)).resultJson, receipt.resultJson);
    expect(await database.select(database.missions).get(), hasLength(2));
    expect(
      await database.select(database.missionScheduleRevisions).get(),
      hasLength(3),
    );
  });

  test('计划内与跨日已有安排重叠都阻止整批保存，相邻时段允许', () async {
    await seed('跨日任务', start: '23:30');
    final crossing = await build([
      createRow('next-day', date: '2026-10-30', start: '00:00'),
    ], id: 'crossing');
    expect(await missions.checkPlan(crossing), isNotEmpty);
    expect(
      (jsonDecode((await missions.applyPlan(crossing)).resultJson)
          as Map)['status'],
      'blocked',
    );
    final internal = await build([
      createRow('one', start: '09:00'),
      createRow('two', start: '09:30'),
    ], id: 'internal');
    expect(await missions.checkPlan(internal), hasLength(2));
    expect(
      (jsonDecode((await missions.applyPlan(internal)).resultJson)
          as Map)['status'],
      'blocked',
    );
    expect(await database.select(database.missions).get(), hasLength(1));
    final adjacent = await build([
      createRow('one', start: '09:00'),
      createRow('two', start: '09:50'),
    ], id: 'adjacent');
    expect(await missions.checkPlan(adjacent), isEmpty);
    await missions.applyPlan(adjacent);
  });

  test('100项计划完整检测所有已有冲突并整批回滚', () async {
    for (var i = 0; i < 25; i++) {
      await seed('已有安排$i', start: '09:00');
    }
    final plan = await build([
      createRow('fixed', start: '09:00'),
      for (var i = 1; i < 100; i++) createRow('item-$i'),
    ]);
    final conflicts = await missions.checkPlan(plan);
    expect(conflicts.where((item) => item.itemId == 'fixed'), hasLength(25));
    final blocked = await missions.applyPlan(plan);
    expect((jsonDecode(blocked.resultJson) as Map)['status'], 'blocked');
    final full = Map<String, Object?>.from(
      jsonDecode(blocked.resultJson) as Map,
    );
    expect(full['issues'], hasLength(25));
    expect(planOperationPage(full, 0)['issues'], hasLength(20));
    expect(planOperationPage(full, 20)['issues'], hasLength(5));
    expect(planOperationPage(full, 0)['status'], 'blocked');
    expect(await database.select(database.missions).get(), hasLength(25));
    expect(
      (await missions.findOperationReceipt(plan.id))?.resultJson,
      blocked.resultJson,
    );

    final valid = await build([
      for (var i = 0; i < 100; i++) createRow('flex-$i'),
    ], id: 'hundred-valid');
    final receipt = await missions.applyPlan(valid);
    expect((jsonDecode(receipt.resultJson) as Map)['savedCount'], 100);
    expect((await missions.applyPlan(valid)).resultJson, receipt.resultJson);
    expect(await database.select(database.missions).get(), hasLength(125));
    final moved = await build([
      for (final item in valid.items)
        {
          'itemId': 'move-${item.id}',
          'kind': 'RESCHEDULE',
          'missionId': item.missionId,
          'scheduledDate': '2026-10-30',
        },
    ], id: 'hundred-move');
    expect(moved.items, hasLength(100));
    final movedReceipt = await missions.applyPlan(moved);
    expect((jsonDecode(movedReceipt.resultJson) as Map)['savedCount'], 100);
    final reloaded = await missions.findDetailsByIds(
      valid.items.map((item) => item.missionId).toList(),
    );
    expect(reloaded, hasLength(100));
    expect(
      reloaded.every((detail) => detail.schedule.scheduledDate == '2026-10-30'),
      isTrue,
    );
  });

  test('预览后出现新安排，提交时复查冲突并记录零写入回执', () async {
    final plan = await build([
      createRow('one', start: '09:00'),
      createRow('two'),
    ]);
    expect(await missions.checkPlan(plan), isEmpty);
    await seed('后来新增的安排', start: '09:20');
    final blocked = await missions.applyPlan(plan);
    expect((jsonDecode(blocked.resultJson) as Map)['status'], 'blocked');
    expect(await database.select(database.missions).get(), hasLength(1));
    expect(
      (await missions.findOperationReceipt(plan.id))?.resultJson,
      blocked.resultJson,
    );
  });

  test('后一项任务已开始时回滚前一项创建，保留原执行事实', () async {
    final existing = await seed('准备改期的任务');
    final plan = await build([
      createRow('new'),
      {
        'itemId': 'move',
        'kind': 'RESCHEDULE',
        'missionId': existing.mission.id,
        'scheduledDate': '2026-10-30',
      },
    ]);
    final detail = (await missions.findDetail(missionId: existing.mission.id))!;
    await missions.execute(
      missions.prepareExecution(detail: detail, type: ExecutionEventType.start),
    );
    await expectLater(
      missions.applyPlan(plan),
      throwsA(isA<MissionEditConflict>()),
    );
    expect(await database.select(database.missions).get(), hasLength(1));
    final saved = (await missions.findDetail(missionId: existing.mission.id))!;
    expect(saved.schedule.id, existing.schedule.id);
    expect(saved.events, hasLength(1));
    expect(await missions.findOperationReceipt(plan.id), isNull);
  });

  test('两项任务互换时段按最终计划检查，不能重复使用保存身份改变内容', () async {
    final a = await seed('任务A', start: '09:00');
    final b = await seed('任务B', start: '10:00');
    final plan = await build([
      {
        'itemId': 'a',
        'kind': 'RESCHEDULE',
        'missionId': a.mission.id,
        'scheduledDate': '2026-10-29',
        'fixedStartLocal': '10:00',
      },
      {
        'itemId': 'b',
        'kind': 'RESCHEDULE',
        'missionId': b.mission.id,
        'scheduledDate': '2026-10-29',
        'fixedStartLocal': '09:00',
      },
    ]);
    expect(await missions.checkPlan(plan), isEmpty);
    await missions.applyPlan(plan);
    final altered = await build([createRow('other')]);
    await expectLater(missions.applyPlan(altered), throwsStateError);
    expect(await database.select(database.missions).get(), hasLength(2));
  });

  test('计划卡确认前零写入，编辑移除后只保存最终内容并可重开恢复', () async {
    final model = ScriptedModel([
      (_) => toolResponse('batch', 'planMissions', {
        'title': '今天的学习安排',
        'items': [createRow('one'), createRow('two'), createRow('remove')],
      }),
      (_) => textResponse('两项安排已保存。'),
    ]);
    final settings = MemoryAssistantSettingsStore();
    controller = AssistantController(
      unifiedReader: DriftUnifiedReader(database),
      sessionStore: DriftSessionStore(database),
      settingsStore: settings,
      missions: missions,
      goals: goals,
      clock: () => now,
      modelOverrides: {'deepseek-chat': model, 'deepseek': model},
    );
    final assistant = controller!;
    await assistant.initialize();
    final sending = assistant.send('安排今天');
    await waitFor(
      () => assistant.operations.any(
        (item) => item.status == AssistantOperationStatus.waitingConfirmation,
      ),
    );
    final operation = assistant.operations.single;
    expect(await database.select(database.missions).get(), isEmpty);
    final items = AssistantScheduleService.rows(operation.input)..removeLast();
    items.first['title'] = '用户改过的名称';
    expect(
      assistant.updateProposal('batch', {...operation.input, 'items': items}),
      isNull,
    );
    expect(assistant.confirmProposal('batch'), isNotNull);
    expect(await assistant.refreshPlanPreview('batch'), isNull);
    expect(assistant.confirmProposal('batch'), isNull);
    await sending;
    expect(await database.select(database.missions).get(), hasLength(2));
    expect(
      (await database.select(database.missions).get()).map(
        (item) => item.title,
      ),
      contains('用户改过的名称'),
    );
    final id = assistant.currentSessionId!;
    await assistant.startNewSession();
    await assistant.openConversation(id);
    expect(
      assistant.operations.single.status,
      AssistantOperationStatus.succeeded,
    );
    expect(
      AssistantScheduleService.rows(assistant.operations.single.input),
      hasLength(2),
    );
    expect(
      jsonDecode(assistant.operations.single.output!)['counts']['changed'],
      2,
    );
  });

  test('完整权限遇到排期冲突返回阻塞回执并显示未保存', () async {
    await seed('已有任务', start: '09:00');
    final model = ScriptedModel([
      (_) => toolResponse('conflict-plan', 'planMissions', {
        'title': '测试冲突',
        'items': [createRow('new', start: '09:00')],
      }),
      (_) => textResponse('该安排存在冲突。'),
    ]);
    controller = AssistantController(
      unifiedReader: DriftUnifiedReader(database),
      sessionStore: DriftSessionStore(database),
      settingsStore: MemoryAssistantSettingsStore()
        ..permissionMode = AssistantPermissionMode.full,
      missions: missions,
      goals: goals,
      clock: () => now,
      modelOverrides: {'deepseek-chat': model, 'deepseek': model},
    );
    final assistant = controller!;
    await assistant.initialize();
    await assistant.send('安排一个九点任务');
    final operation = assistant.operations.single;
    expect(operation.status, AssistantOperationStatus.failed);
    final result = jsonDecode(operation.output!) as Map;
    expect(result['status'], 'blocked');
    expect((result['counts'] as Map)['changed'], 0);
    expect((result['issues'] as List).single['code'], 'existing_overlap');
    expect(await database.select(database.missions).get(), hasLength(1));
  });
  test('计划回执的固定开始时刻使用排期时区偏移', () async {
    final model = ScriptedModel([
      (_) => toolResponse('fixed-plan', 'planMissions', {
        'title': '固定安排',
        'items': [createRow('fixed', start: '09:00')],
      }),
      (_) => textResponse('固定安排已保存。'),
    ]);
    controller = AssistantController(
      unifiedReader: DriftUnifiedReader(database),
      sessionStore: DriftSessionStore(database),
      settingsStore: MemoryAssistantSettingsStore(),
      missions: missions,
      goals: goals,
      clock: () => now,
      modelOverrides: {'deepseek-chat': model, 'deepseek': model},
    );
    final assistant = controller!;
    await assistant.initialize();
    final sending = assistant.send('安排今天九点的固定任务');
    await waitFor(
      () => assistant.operations.any(
        (item) => item.status == AssistantOperationStatus.waitingConfirmation,
      ),
    );
    expect(assistant.confirmProposal('fixed-plan'), isNull);
    await sending;
    final output = jsonDecode(assistant.operations.single.output!) as Map;
    expect(
      (output['items'] as List).single['fixedStartAt'],
      '2026-10-29T09:00:00.000+08:00',
    );
  });
}
