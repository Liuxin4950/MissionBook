import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/assistant/assistant_goal_outline.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_assistant_reader.dart';
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
      reader: DriftAssistantReader(db),
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

  test('整份大纲可修改后一次确认，保存真实父子关系，不创建任务，重开保留结果', () async {
    final ai = await controller('goal_outline_create', outline);
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
    final ai = await controller('goal_outline_create', outline);
    final sending = ai.send('提出目标');
    await waiting(ai);
    ai.cancelProposal('action');
    await sending;
    expect(await goals.findAll(), isEmpty);
    await ai.close();
    final automatic = await controller(
      'goal_outline_create',
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
    final ai = await controller('goal_outline_create', outline, full: true);
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
    final ai = await controller('mission_retry', {
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
    var ai = await controller('mission_retry', {
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
    original = (await missions.findDetailSnapshot(
      missionId: request.mission.id,
    ))!;
    ai = await controller('mission_retry', {
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
    ai = await controller('mission_retry', {
      'missionId': original.mission.id,
      'scheduledDate': '2026-10-30',
      'evidenceDeadlineLocal': '2026-10-30 20:00',
    }, full: true);
    await ai.send('保留代码要求，明晚20点前提交新材料');
    final retry = (await missions.findAllDetails()).singleWhere(
      (detail) => detail.mission.sourceMissionId == original.mission.id,
    );
    expect(retry.mission.verificationPolicy, VerificationPolicy.requiredEvidence);
    expect(retry.executionPlan.verificationCriteria, '代码片段');
    expect(retry.schedule.evidenceDeadlineAt, DateTime.utc(2026, 10, 30, 12));
  });
}
