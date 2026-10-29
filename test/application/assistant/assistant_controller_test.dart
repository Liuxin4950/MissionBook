import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';

import '../../support/assistant_fakes.dart';

void main() {
  late AppDatabase database;
  late MissionService missions;
  late GoalService goals;
  late MemoryAssistantSettingsStore settings;
  AssistantController? controller;
  final now = DateTime.utc(2026, 10, 29, 4);

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(database),
      clock: () => now,
    );
    goals = GoalService(DriftGoalRepository(database));
    settings = MemoryAssistantSettingsStore();
  });

  tearDown(() async {
    await controller?.close();
    await missions.dispose();
    await goals.dispose();
    await database.close();
  });

  AssistantController makeController(ScriptedModel model) {
    final result = AssistantController(
      sessionStore: DriftSessionStore(database),
      settingsStore: settings,
      missions: missions,
      goals: goals,
      modelOverrides: {'deepseek-chat': model, 'deepseek': model},
      clock: () => now,
    );
    controller = result;
    return result;
  }

  Future<void> createMission(String title) => missions.create(
    title: title,
    scheduledDate: '2026-10-29',
    timeZone: 'Asia/Shanghai',
    plannedDurationMinutes: 30,
  );

  Future<void> waitFor(bool Function() condition) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('等待助手状态超时');
  }

  test('真实日期查询经工具返回，快捷查询不依赖模型', () async {
    await createMission('阅读第一章');
    final model = ScriptedModel([
      (_) => toolResponse('call-query', 'schedule_query', const {
        'date': '2026-10-29',
      }),
      (_) => textResponse('今天有阅读第一章。'),
    ]);
    final assistant = makeController(model);
    await assistant.initialize();
    final result = await assistant.send('今天有什么任务');

    expect(result?.answer, '今天有阅读第一章。');
    final toolResult = assistant.transcript
        .whereType<ToolResultMessage>()
        .single;
    expect(toolResult.text, contains('阅读第一章'));
    expect(
      assistant.operations.single.status,
      AssistantOperationStatus.succeeded,
    );

    settings.credential = null;
    await assistant.loadLocalSchedule();
    expect(assistant.localSchedule?.single.mission.title, '阅读第一章');
  });

  test('创建提案可编辑并确认，固定请求只产生一个任务', () async {
    final model = ScriptedModel([
      (_) => toolResponse('call-create', 'mission_create', const {
        'title': '原始标题',
        'scheduledDate': '2026-10-30',
        'plannedMinutes': 25,
      }),
      (_) => textResponse('已按卡片内容创建。'),
    ]);
    final assistant = makeController(model);
    await assistant.initialize();
    final sending = assistant.send('创建复习任务');
    await waitFor(
      () => assistant.operations.any(
        (item) => item.status == AssistantOperationStatus.waitingConfirmation,
      ),
    );
    final operation = assistant.operations.single;

    expect(
      assistant.updateProposal(operation.callId, const {
        'title': '确认后的标题',
        'scheduledDate': '2026-10-30',
        'plannedMinutes': 25,
      }),
      isNull,
    );
    expect(assistant.confirmProposal(operation.callId), isNull);
    await sending;

    final saved = await missions.findAllDetails();
    expect(saved, hasLength(1));
    expect(saved.single.mission.title, '确认后的标题');
    expect(assistant.confirmProposal(operation.callId), isNotNull);
    expect((await missions.findAllDetails()), hasLength(1));
  });

  test('取消提案没有业务写入', () async {
    final model = ScriptedModel([
      (_) => toolResponse('call-create', 'mission_create', const {
        'title': '不保存',
        'scheduledDate': '2026-10-30',
        'plannedMinutes': 25,
      }),
      (_) => textResponse('已取消，没有创建任务。'),
    ]);
    final assistant = makeController(model);
    await assistant.initialize();
    final sending = assistant.send('创建一个任务');
    await waitFor(() => assistant.operations.isNotEmpty);
    assistant.cancelProposal(assistant.operations.single.callId);
    await sending;

    expect(await missions.findAllDetails(), isEmpty);
    expect(
      assistant.operations.single.status,
      AssistantOperationStatus.cancelled,
    );
  });

  test('完整权限直接执行已提供写入工具', () async {
    settings.autoApprove = true;
    final model = ScriptedModel([
      (_) => toolResponse('call-create', 'mission_create', const {
        'title': '自动创建',
        'scheduledDate': '2026-10-30',
        'plannedMinutes': 25,
      }),
      (_) => textResponse('已创建。'),
    ]);
    final assistant = makeController(model);
    await assistant.initialize();
    final result = await assistant.send('创建任务');

    expect(result?.answer, '已创建。');
    expect(
      assistant.operations.single.status,
      AssistantOperationStatus.succeeded,
    );
    expect((await missions.findAllDetails()).single.mission.title, '自动创建');
  });

  test('确认期间外部改期使旧提案冲突，不覆盖新事实', () async {
    await createMission('旧任务');
    final original = (await missions.findAllDetails()).single;
    final model = ScriptedModel([
      (_) => toolResponse('call-edit', 'mission_reschedule', {
        'missionId': original.mission.id,
        'scheduledDate': '2026-11-01',
      }),
      (_) => textResponse('旧提案没有覆盖最新安排。'),
    ]);
    final assistant = makeController(model);
    await assistant.initialize();
    final sending = assistant.send('改到明天');
    await waitFor(() => assistant.operations.isNotEmpty);
    final operation = assistant.operations.single;

    await missions.edit(
      original: original,
      title: original.mission.title,
      objective: original.executionPlan.objective,
      scheduledDate: '2026-11-02',
      plannedDurationMinutes: 30,
      timePolicy: original.schedule.timePolicy,
    );
    expect(assistant.confirmProposal(operation.callId), isNull);
    await sending;

    final current = (await missions.findAllDetails()).single;
    expect(current.schedule.scheduledDate, '2026-11-02');
    expect(assistant.operations.single.status, AssistantOperationStatus.failed);
    expect(assistant.operations.single.error, 'edit_rejected');
  });

  test('停止待确认提案不会创建任务', () async {
    final model = ScriptedModel([
      (_) => toolResponse('call-create', 'mission_create', const {
        'title': '停止前不保存',
        'scheduledDate': '2026-10-30',
        'plannedMinutes': 25,
      }),
    ]);
    final assistant = makeController(model);
    await assistant.initialize();
    final sending = assistant.send('创建任务');
    await waitFor(() => assistant.operations.isNotEmpty);
    assistant.stop();
    await sending;
    expect(await missions.findAllDetails(), isEmpty);
  });

  test('会话关闭后由 Drift 记录恢复', () async {
    final firstModel = ScriptedModel([
      (_) => toolResponse('call-query', 'schedule_query', const {
        'date': '2026-10-29',
      }),
      (_) => textResponse('查询完成'),
    ]);
    final first = makeController(firstModel);
    await first.initialize();
    await first.send('查今天');
    final sessionId = first.currentSessionId;
    await first.close();
    controller = null;

    final second = makeController(ScriptedModel([]));
    await second.initialize();
    expect(second.currentSessionId, sessionId);
    expect(second.transcript.whereType<UserMessage>().single.text, '查今天');
    expect(second.operations.single.status, AssistantOperationStatus.succeeded);
  });
}
