import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'dart:convert';
import 'package:mission_book/domain/entities/historical_completion.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/domain/rules/execution_time_rules.dart';
import 'package:drift/native.dart';
import 'package:agent_core/agent_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/assistant/assistant_goal_outline.dart';
import 'package:mission_book/application/assistant/assistant_operation_result.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';

import '../../support/assistant_fakes.dart';

const outline = <String, Object?>{
  'title': '学会 Flutter',
  'nodes': [
    {'key': 'base', 'title': '基础'},
    {
      'key': 'layout',
      'parentKey': 'base',
      'title': '布局',
      'description': '实现自适应页面',
    },
    {'key': 'project', 'title': '独立项目'},
  ],
};

void main() {
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  AssistantController? assistant;
  final now = DateTime.utc(2026, 10, 29, 4);
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(db, clock: () => now),
      clock: () => now,
    );
    goals = GoalService(DriftGoalRepository(db));
    assistant = null;
  });
  tearDown(() async {
    await assistant?.close();
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });
  Future<AssistantController> controller(
    String tool,
    Map<String, Object?> input, {
    bool full = false,
  }) async {
    final model = ScriptedModel([
      (_) => toolResponse('action', tool, input),
      (_) => textResponse('操作结果已返回。'),
    ]);
    final result = AssistantController(
      unifiedReader: DriftUnifiedReader(db),
      sessionStore: DriftSessionStore(db),
      settingsStore: MemoryAssistantSettingsStore()
        ..permissionMode = full
            ? AssistantPermissionMode.full
            : AssistantPermissionMode.standard,
      missions: missions,
      goals: goals,
      modelOverrides: {'deepseek-chat': model},
      clock: () => now,
    );
    assistant = result;
    await result.initialize();
    await result.startNewSession();
    return result;
  }

  Future<void> waiting(AssistantController controller) async {
    for (var i = 0; i < 200; i++) {
      if (controller.operations.any(
        (op) => op.status == AssistantOperationStatus.waitingConfirmation,
      )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('没有出现待确认的写入卡片：${controller.errorMessage}');
  }

  Future<String> seedHistory() async {
    final goal = goals.prepareCreation(title: '秋季课表');
    await goals.create(goal);
    for (final date in [
      '2026-10-20',
      '2026-10-21',
      '2026-10-29',
      '2026-11-01',
    ]) {
      await missions.create(
        title: '课程 $date',
        scheduledDate: date,
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 45,
        ownership: MissionOwnership(goalId: goal.id),
      );
    }
    return goal.id;
  }

  test('AI按日期整批删除先确认，提交后返回真实数量和分页回执', () async {
    final goalId = await seedHistory();
    final ai = await controller('manageMissions', {
      'action': 'delete',
      'goalId': goalId,
      'beforeDate': '2026-10-29',
    });
    final sending = ai.send('把今天以前的任务全部永久删除');
    await waiting(ai);
    expect(await missions.findForGoal(goalId), hasLength(4));
    expect(ai.operations.single.targetTitle, contains('2 项任务'));
    expect(ai.confirmProposal('action'), isNull);
    await sending;
    expect(await missions.findForGoal(goalId), hasLength(2));
    final output = ai.transcript.whereType<ToolResultMessage>().single;
    expect(output.isError, isFalse);
    final result = jsonDecode(output.text) as Map;
    expect(result['counts']['changed'], 2);
    final receipt = await missions.findOperationReceipt(
      result['operationId'] as String,
    );
    expect(receipt!.kind, 'missions_delete');
  });

  test('AI没有明确维护范围时拒绝整库操作', () async {
    final goalId = await seedHistory();
    final ai = await controller('manageMissions', {
      'action': 'delete',
    }, full: true);
    await ai.send('删除任务');
    expect(await missions.findForGoal(goalId), hasLength(4));
    expect(ai.transcript.whereType<ToolResultMessage>().single.isError, isTrue);
  });

  test('AI 整批补记历史课表，确认前零写入；保留今天和未来，补记不产生虚构时长', () async {
    final goalId = await seedHistory();
    final ai = await controller('completeHistory', {
      'goalId': goalId,
      'beforeDate': '2026-10-29',
      'statement': '把今天以前的课程补记为已完成',
    });
    final sending = ai.send('把今天以前的课程补记为已完成');
    await waiting(ai);
    expect(ai.operations.single.historyMissions, hasLength(2));
    expect(await db.select(db.executionEvents).get(), isEmpty);
    expect(ai.confirmProposal('action'), isNull);
    await sending;
    expect(ai.operations.single.status, AssistantOperationStatus.succeeded);
    final finished = await missions.findFinished();
    expect(finished, hasLength(2));
    for (final detail in finished) {
      expect(detail.endReportedCompleted, isTrue);
      expect(detail.events.single.isRetrospective, isTrue);
      expect(detail.events.single.occurredAt, now);
      expect(calculateExecutionTimes(detail.events, now).focus, Duration.zero);
    }
    expect(
      (await missions.findForGoal(goalId)).where((d) => d.events.isEmpty),
      hasLength(2),
    );
  });

  test('模型编造历史完成依据时，即使完整权限也不能写入', () async {
    final goalId = await seedHistory();
    final ai = await controller('completeHistory', {
      'goalId': goalId,
      'beforeDate': '2026-10-29',
      'statement': '这些课程我都已完成',
    }, full: true);
    await ai.send('你好');
    expect(await db.select(db.executionEvents).get(), isEmpty);
    final output = ai.transcript.whereType<ToolResultMessage>().single;
    expect(output.isError, isTrue);
  });

  test('历史补记回执解释跳过原因，零候选仍保存完整范围结果', () async {
    final goalId = await seedHistory();
    final old = (await missions.findForGoal(goalId))
        .where((d) => d.schedule.scheduledDate.compareTo('2026-10-29') < 0)
        .toList();
    await missions.cancel(missionId: old.first.mission.id);
    await missions.create(
      title: '需要材料',
      scheduledDate: '2026-10-22',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
      verificationPolicy: VerificationPolicy.requiredEvidence,
      verificationCriteria: '提交笔记',
      evidenceDeadlineAt: now.add(const Duration(days: 1)),
      ownership: MissionOwnership(goalId: goalId),
    );
    final ai = await controller('completeHistory', {
      'goalId': goalId,
      'beforeDate': '2026-10-29',
      'statement': '这些课程我都完成了',
    }, full: true);
    await ai.send('这些课程我都完成了');
    final output = ai.transcript.whereType<ToolResultMessage>().single;
    expect(output.isError, isFalse);
    final result = jsonDecode(output.text) as Map<String, dynamic>;
    expect(result['counts'], {
      'matched': 3,
      'eligible': 1,
      'changed': 1,
      'skipped': 2,
    });
    expect((result['issues'] as List).map((issue) => issue['code']).toSet(), {
      'cancelled',
      'required_evidence',
    });
    expect(result['page']['complete'], isTrue);
    final past = (await missions.findForGoal(goalId))
        .where((d) => d.schedule.scheduledDate.compareTo('2026-10-29') < 0)
        .toList();
    final zero = await missions.completeHistory(
      HistoricalCompletion(
        id: 'zero',
        goalId: goalId,
        beforeDate: '2026-10-29',
        statement: '这些课程我都完成了',
        originals: const [],
        excluded: past,
      ),
    );
    final summary = jsonDecode(zero.resultJson) as Map<String, dynamic>;
    expect(summary['counts'], {
      'matched': 3,
      'eligible': 0,
      'changed': 0,
      'skipped': 3,
    });
    expect((summary['issues'] as List).map((issue) => issue['code']).toSet(), {
      'cancelled',
      'required_evidence',
      'already_ended',
    });
  });

  test('历史补记预览后范围新增任务，整批不写入', () async {
    final goalId = await seedHistory();
    final originals = (await missions.findForGoal(goalId))
        .where((d) => d.schedule.scheduledDate.compareTo('2026-10-29') < 0)
        .toList();
    final proposal = HistoricalCompletion(
      id: 'stale-scope',
      goalId: goalId,
      beforeDate: '2026-10-29',
      statement: '已完成',
      originals: originals,
      excluded: const [],
    );
    await missions.create(
      title: '后来新增',
      scheduledDate: '2026-10-23',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 10,
      ownership: MissionOwnership(goalId: goalId),
    );
    await expectLater(missions.completeHistory(proposal), throwsA(anything));
    expect(await db.select(db.executionEvents).get(), isEmpty);
  });
  test('历史补记预览后任务名称变化即使时间戳不变也拒绝', () async {
    final goalId = await seedHistory();
    final originals = (await missions.findForGoal(goalId))
        .where((d) => d.schedule.scheduledDate.compareTo('2026-10-29') < 0)
        .toList();
    final proposal = HistoricalCompletion(
      id: 'stale-title',
      goalId: goalId,
      beforeDate: '2026-10-29',
      statement: '已完成',
      originals: originals,
      excluded: const [],
    );
    await db.customStatement('UPDATE missions SET title=? WHERE id=?', [
      '已修改名称',
      originals.first.mission.id,
    ]);
    await expectLater(missions.completeHistory(proposal), throwsA(anything));
    expect(await db.select(db.executionEvents).get(), isEmpty);
  });

  test('历史范围按最新排期筛选，并在超过10000项时先拒绝', () async {
    final goalId = await seedHistory();
    final initial = await missions.findHistoryScope(goalId, '2026-10-29');
    expect(initial, hasLength(2));
    final moved = initial.first;
    await db
        .into(db.missionScheduleRevisions)
        .insert(
          MissionScheduleRevisionsCompanion.insert(
            id: 'changed-schedule',
            missionId: moved.mission.id,
            revisionNumber: moved.schedule.revisionNumber + 1,
            scheduledDate: '2026-11-02',
            timeZone: 'Asia/Shanghai',
            plannedDurationMinutes: 45,
            changedAt: now.millisecondsSinceEpoch,
          ),
        );
    final scope = await missions.findHistoryScope(goalId, '2026-10-29');
    expect(scope, hasLength(1));
    expect(scope.single.mission.id, isNot(moved.mission.id));

    await db.customStatement(
      '''WITH RECURSIVE n(i) AS (
      SELECT 0 UNION ALL SELECT i+1 FROM n WHERE i<9999
    ) INSERT INTO missions (id,title,goal_id,created_at,updated_at)
      SELECT 'overflow-' || i,'测试',?,0,0 FROM n''',
      [goalId],
    );
    await expectLater(
      missions.findHistoryScope(goalId, '2026-10-29'),
      throwsArgumentError,
    );
  });

  test('历史补记跳过明细超过20条时完整保存并分页', () async {
    final goal = goals.prepareCreation(title: '历史范围');
    await goals.create(goal);
    for (var i = 0; i < 25; i++) {
      final task = missions.prepareCreation(
        title: '已取消$i',
        scheduledDate: '2026-10-20',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 10,
        ownership: MissionOwnership(goalId: goal.id),
      );
      await missions.createPrepared(task);
      await missions.cancel(missionId: task.mission.id);
    }
    final ai = await controller('completeHistory', {
      'goalId': goal.id,
      'beforeDate': '2026-10-29',
      'statement': '历史任务已完成',
    }, full: true);
    await ai.send('历史任务已完成');
    final output = ai.transcript.whereType<ToolResultMessage>().single;
    expect(output.isError, isFalse);
    final first = Map<String, Object?>.from(jsonDecode(output.text) as Map);
    expect((first['issues'] as List), hasLength(20));
    expect(first['page'], {'offset': 0, 'complete': false, 'nextOffset': 20});
    final receipt = (await missions.findOperationReceipt(
      first['operationId'] as String,
    ))!;
    final full = Map<String, Object?>.from(
      jsonDecode(receipt.resultJson) as Map,
    );
    expect((full['issues'] as List), hasLength(25));
    final last = historyOperationPage(full, 20);
    expect(last['issues'], hasLength(5));
    expect(last['page'], {'offset': 20, 'complete': true});
    expect(await db.select(db.executionEvents).get(), isEmpty);
  });

  test('补记整批回滚；固定请求重试不重复写入', () async {
    final goalId = await seedHistory();
    final originals = (await missions.findForGoal(goalId))
        .where((d) => d.schedule.scheduledDate.compareTo('2026-10-29') < 0)
        .toList();
    final request = HistoricalCompletion(
      id: 'batch',
      goalId: goalId,
      beforeDate: '2026-10-29',
      statement: '用户补报已完成',
      originals: originals,
      excluded: const [],
    );
    await db.customStatement(
      "CREATE TRIGGER reject_history BEFORE INSERT ON execution_events WHEN NEW.mission_id = '${originals.last.mission.id}' BEGIN SELECT RAISE(ABORT, 'rollback'); END",
    );
    await expectLater(missions.completeHistory(request), throwsA(anything));
    expect(await db.select(db.executionEvents).get(), isEmpty);
    expect(await missions.findOperationReceipt('batch'), isNull);
    await db.customStatement('DROP TRIGGER reject_history');
    await missions.completeHistory(request);
    await missions.completeHistory(request);
    expect(await db.select(db.executionEvents).get(), hasLength(2));
    expect(await missions.findOperationReceipt('batch'), isNotNull);
  });

  test('历史任务已开始后正常结束；旧预览遇到新执行事实时整批拒绝', () async {
    final goalId = await seedHistory();
    var originals = (await missions.findForGoal(goalId))
        .where((d) => d.schedule.scheduledDate.compareTo('2026-10-29') < 0)
        .toList();
    final stale = HistoricalCompletion(
      id: 'stale',
      goalId: goalId,
      beforeDate: '2026-10-29',
      statement: '已完成',
      originals: originals,
      excluded: const [],
    );
    await missions.execute(
      missions.prepareExecution(
        detail: originals.last,
        type: ExecutionEventType.start,
      ),
    );
    await expectLater(missions.completeHistory(stale), throwsA(anything));
    expect(await db.select(db.executionEvents).get(), hasLength(1));
    originals = (await missions.findForGoal(goalId))
        .where((d) => d.schedule.scheduledDate.compareTo('2026-10-29') < 0)
        .toList();
    await missions.completeHistory(
      HistoricalCompletion(
        id: 'fresh',
        goalId: goalId,
        beforeDate: '2026-10-29',
        statement: '已完成',
        originals: originals,
        excluded: const [],
      ),
    );
    final finished = await missions.findFinished();
    expect(finished, hasLength(2));
    expect(
      finished
          .singleWhere((d) => d.events.length == 2)
          .events
          .last
          .isRetrospective,
      isFalse,
    );
  });

  test('整份大纲可修改后一次确认，保存真实父子关系，不创建任务，重开保留结果', () async {
    final ai = await controller('createGoalOutline', outline);
    final sending = ai.send('创建目标及分层大纲');
    await waiting(ai);
    expect(await goals.findAll(), isEmpty);
    expect(ai.operations.single.isWrite, isTrue);
    final edited = {...outline, 'title': '我的 Flutter 目标'};
    expect(ai.updateProposal('action', edited), isNull);
    expect(ai.confirmProposal('action'), isNull);
    await sending;
    final goal = (await goals.findAll()).single;
    final nodes = await goals.findNodes(goal.id);
    expect(goal.title, '我的 Flutter 目标');
    expect(nodes, hasLength(3));
    expect(
      nodes.singleWhere((node) => node.title == '布局').parentNodeId,
      nodes.singleWhere((node) => node.title == '基础').id,
    );
    expect(await missions.findAllDetails(), isEmpty);
    final session = ai.currentSessionId!;
    await ai.startNewSession();
    await ai.openConversation(session);
    expect(ai.operations.single.status, AssistantOperationStatus.succeeded);
    expect(ai.operations.single.input['title'], '我的 Flutter 目标');
  });

  test('取消整份大纲零写入；完整权限直接执行整份', () async {
    final ai = await controller('createGoalOutline', outline);
    final sending = ai.send('提出目标');
    await waiting(ai);
    ai.cancelProposal('action');
    await sending;
    expect(await goals.findAll(), isEmpty);
    await ai.close();
    final automatic = await controller(
      'createGoalOutline',
      outline,
      full: true,
    );
    await automatic.send('创建整份目标');
    expect(await goals.findAll(), hasLength(1));
    expect(
      automatic.operations.single.status,
      AssistantOperationStatus.succeeded,
    );
  });

  test('节点写入失败整份回滚，不能留下空目标或半份大纲', () async {
    await db.customStatement(
      "CREATE TRIGGER reject_outline BEFORE INSERT ON goal_nodes WHEN NEW.title = '布局' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    final ai = await controller('createGoalOutline', outline, full: true);
    await ai.send('创建目标');
    expect(await goals.findAll(), isEmpty);
    expect((await db.select(db.goalNodes).get()), isEmpty);
    expect(
      ai.operations.single.status,
      isNot(AssistantOperationStatus.succeeded),
    );
  });

  test('大纲固定请求身份可核对，不重复保存；重复键、孤立父级、深层与超量被拒绝', () async {
    final request = goals.prepareOutlineImport(
      AssistantGoalOutline.parse(outline),
      requestId: 'outline-request',
    );
    await goals.importOutline(request);
    await goals.importOutline(request);
    expect(await goals.findAll(), hasLength(1));
    expect(await goals.findNodes(request.goal.id), hasLength(3));
    final same = goals.prepareOutlineImport(
      AssistantGoalOutline.parse(outline),
      requestId: 'outline-request',
    );
    expect(same.goal.id, request.goal.id);
    expect(
      same.nodes.map((node) => node.id),
      request.nodes.map((node) => node.id),
    );
    for (final nodes in [
      [
        {'key': 'a', 'title': 'A'},
        {'key': 'a', 'title': 'B'},
      ],
      [
        {'key': 'a', 'parentKey': 'missing', 'title': 'A'},
      ],
      [
        for (var i = 0; i < 5; i++)
          {'key': '$i', 'title': '$i', if (i > 0) 'parentKey': '${i - 1}'},
      ],
      [
        for (var i = 0; i < 21; i++) {'key': '$i', 'title': '$i'},
      ],
    ]) {
      expect(
        AssistantGoalOutline.validate({...outline, 'nodes': nodes}),
        isNotNull,
      );
    }
  });

  test('未完成任务生成关联的新尝试，保留原失败事实、方案及材料策略', () async {
    await missions.create(
      title: '练习布局',
      scheduledDate: '2026-10-29',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    var original = (await missions.findAllDetails()).single;
    await missions.execute(
      missions.prepareExecution(
        detail: original,
        type: ExecutionEventType.start,
      ),
    );
    original = (await missions.findAllDetails()).single;
    await missions.execute(
      missions.prepareExecution(
        detail: original,
        type: ExecutionEventType.end,
        report: UserReportedResult.notCompleted,
        userReasonText: '缺少练习',
      ),
    );
    original = (await missions.findAllDetails()).single;
    final ai = await controller('retryMission', {
      'missionId': original.mission.id,
      'scheduledDate': '2026-10-30',
      'steps': ['先写小示例', '再做完整布局'],
    });
    final sending = ai.send('明天重新练习');
    await waiting(ai);
    expect(await missions.findAllDetails(), hasLength(1));
    expect(ai.confirmProposal('action'), isNull);
    await sending;
    final all = await missions.findAllDetails();
    expect(all, hasLength(2));
    final retry = all.singleWhere(
      (detail) => detail.mission.id != original.mission.id,
    );
    final unchanged = all.singleWhere(
      (detail) => detail.mission.id == original.mission.id,
    );
    expect(retry.mission.sourceMissionId, original.mission.id);
    expect(retry.schedule.scheduledDate, '2026-10-30');
    expect(retry.executionPlan.steps, ['先写小示例', '再做完整布局']);
    expect(
      unchanged.events.map((event) => event.id),
      original.events.map((event) => event.id),
    );
    expect(unchanged.failures, hasLength(original.failures.length));
    expect(
      retry.mission.verificationPolicy,
      original.mission.verificationPolicy,
    );
  });

  test('待开始任务不能伪装成再次尝试；强制材料缺少新截止时零写入', () async {
    await missions.create(
      title: '还没开始',
      scheduledDate: '2026-10-29',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    var original = (await missions.findAllDetails()).single;
    var ai = await controller('retryMission', {
      'missionId': original.mission.id,
      'scheduledDate': '2026-10-30',
    }, full: true);
    await ai.send('重做');
    expect(await missions.findAllDetails(), hasLength(1));
    await ai.close();
    final request = missions.prepareCreation(
      title: '交代码',
      scheduledDate: '2026-10-29',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
      verificationPolicy: VerificationPolicy.requiredEvidence,
      verificationCriteria: '代码片段',
      evidenceDeadlineAt: now.add(const Duration(hours: 8)),
    );
    await missions.createPrepared(request);
    await missions.cancel(missionId: request.mission.id);
    original = (await missions.findDetail(missionId: request.mission.id))!;
    ai = await controller('retryMission', {
      'missionId': original.mission.id,
      'scheduledDate': '2026-10-30',
    }, full: true);
    await ai.send('重新做强制材料任务');
    expect(await missions.findAllDetails(), hasLength(2));
    expect(
      ai.operations.every(
        (op) => op.status != AssistantOperationStatus.succeeded,
      ),
      isTrue,
    );
    await ai.close();
    ai = await controller('retryMission', {
      'missionId': original.mission.id,
      'scheduledDate': '2026-10-30',
      'evidenceDeadlineLocal': '2026-10-30 20:00',
    }, full: true);
    await ai.send('保留代码要求，明晚20点前提交新材料');
    final retry = (await missions.findAllDetails()).singleWhere(
      (detail) => detail.mission.sourceMissionId == original.mission.id,
    );
    expect(
      retry.mission.verificationPolicy,
      VerificationPolicy.requiredEvidence,
    );
    expect(retry.executionPlan.verificationCriteria, '代码片段');
    expect(retry.schedule.evidenceDeadlineAt, DateTime.utc(2026, 10, 30, 12));
  });
}
