import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mission_book/application/assistant/assistant_attachment.dart';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/assistant/assistant_settings.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_assistant_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';

import '../../support/assistant_fakes.dart';

class PausedSettingsStore extends MemoryAssistantSettingsStore {
  Completer<void>? loadGate;

  @override
  Future<AssistantSettings> load() async {
    await loadGate?.future;
    return super.load();
  }
}

class BackgroundModel implements AgentModel {
  final first = Completer<ModelResponse>();
  int calls = 0;
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) {
    calls++;
    return calls == 1 ? first.future : Future.value(textResponse('继续完成了本轮'));
  }
}

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

  AssistantController makeController(
    AgentModel model, {
    Duration resumeGrace = const Duration(seconds: 20),
  }) {
    final result = AssistantController(
      reader: DriftAssistantReader(database),
      sessionStore: DriftSessionStore(database),
      settingsStore: settings,
      missions: missions,
      goals: goals,
      modelOverrides: {'deepseek-chat': model, 'deepseek': model},
      resumeGrace: resumeGrace,
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

  test('切后台不主动停止健康请求，回前台正常收到结果并可继续发送', () async {
    final model = BackgroundModel();
    final ai = makeController(model);
    await ai.initialize();
    final sending = ai.send('继续处理');
    await waitFor(() => model.calls == 1);
    ai.setForeground(false);
    expect(ai.isRunning, isTrue);
    model.first.complete(textResponse('后台请求完成'));
    await sending;
    ai.setForeground(true);
    expect(ai.isBusy, isFalse);
    await ai.send('下一条');
    expect(model.calls, 2);
  });

  test('回前台连接无进展时结束旧等待，继续同一轮不重复用户消息', () async {
    final model = BackgroundModel();
    final ai = makeController(
      model,
      resumeGrace: const Duration(milliseconds: 20),
    );
    await ai.initialize();
    final sending = ai.send('处理这项请求');
    await waitFor(() => model.calls == 1);
    ai.setForeground(false);
    ai.setForeground(true);
    await sending.timeout(const Duration(seconds: 2));
    expect(ai.isBusy, isFalse);
    expect(ai.canContinueInterrupted, isTrue);
    await ai.continueInterrupted();
    expect(ai.transcript.whereType<UserMessage>(), hasLength(1));
    expect(ai.transcript.whereType<AssistantMessage>().last.text, '继续完成了本轮');
    expect(ai.isBusy, isFalse);
  });

  test('角色与风格实际进入模型请求，修改后已有会话与重开会话都生效', () async {
    final model = ScriptedModel([
      (_) => textResponse('你好'),
      (_) => textResponse('继续'),
      (_) => textResponse('已恢复'),
    ]);
    final assistant = makeController(model);
    await assistant.initialize();
    await assistant.send('你好');
    final first = assistant.currentSessionId!;
    final permission = assistant.permissionMode;
    await assistant.savePersona(
      const AssistantPersona(
        name: '小书',
        userAddress: '小刘',
        role: AssistantRole.coach,
        replyStyle: AssistantReplyStyle.explanatory,
        avatar: AssistantAvatar.book,
      ),
    );
    await assistant.send('讲讲事务');
    expect(model.requests.last.systemPrompt, contains('小书'));
    expect(model.requests.last.systemPrompt, contains('用户希望被称为 "小刘"'));
    expect(
      model.requests.last.systemPrompt,
      contains(AssistantRole.coach.instruction),
    );
    expect(
      model.requests.last.systemPrompt,
      contains(AssistantReplyStyle.explanatory.instruction),
    );
    expect(assistant.permissionMode, permission);
    await assistant.startNewSession();
    await assistant.openConversation(first);
    await assistant.send('继续');
    expect(model.requests.last.systemPrompt, contains('小书'));
    expect(model.requests.last.systemPrompt, contains('不能改变工具权限'));
    expect(model.requests.last.systemPrompt, contains('小刘'));
  });

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

  test('默认档读取等待授权，宽松档自动查询且仍拦住写入', () async {
    settings.permissionMode = AssistantPermissionMode.standard;
    final assistant = makeController(
      ScriptedModel([
        (_) => toolResponse('strict-read', 'schedule_query', {}),
        (_) => textResponse('查询结束'),
        (_) => toolResponse('relaxed-read', 'schedule_query', {}),
        (_) => toolResponse('relaxed-write', 'mission_create', {
          'title': '应取消',
          'scheduledDate': '2026-10-30',
          'plannedMinutes': 20,
        }),
        (_) => textResponse('已取消'),
      ]),
    );
    await assistant.initialize();
    final first = assistant.send('读取今天');
    await waitFor(
      () => assistant.operations.any(
        (op) => op.status == AssistantOperationStatus.waitingConfirmation,
      ),
    );
    expect(assistant.operations.single.isWrite, isFalse);
    expect(assistant.transcript.whereType<ToolResultMessage>(), isEmpty);
    expect(assistant.confirmProposal('strict-read'), isNull);
    await first;
    await assistant.setPermissionMode(AssistantPermissionMode.relaxed);
    final second = assistant.send('读取后创建');
    await waitFor(
      () => assistant.operations.any(
        (op) =>
            op.callId == 'relaxed-write' &&
            op.status == AssistantOperationStatus.waitingConfirmation,
      ),
    );
    expect(
      assistant.operations
          .firstWhere((op) => op.callId == 'relaxed-read')
          .status,
      AssistantOperationStatus.succeeded,
    );
    assistant.cancelProposal('relaxed-write');
    await second;
    expect(await missions.findAllDetails(), isEmpty);
  });

  test('图片和文本附件实际送入模型并在重开会话后完整恢复', () async {
    final image = AssistantAttachment.fromBytes(
      'small.png',
      await File('assets/illustrations/day-plan.png').readAsBytes(),
    );
    final file = AssistantAttachment.fromBytes(
      'plan.md',
      Uint8List.fromList(utf8.encode('明天复习布局')),
    );
    final model = ScriptedModel([(_) => textResponse('已读附件')]);
    final assistant = makeController(model);
    await assistant.initialize();
    final message = UserMessage.withContent(content: [image.block, file.block]);
    await assistant.sendMessage(message);
    final received = model.requests.single.messages
        .whereType<UserMessage>()
        .single;
    expect(
      received.content.whereType<ImageBlock>().single.url,
      (image.block as ImageBlock).url,
    );
    expect(AssistantAttachment.textFile(received.content.last)?.text, '明天复习布局');
    await assistant.close();
    final restored = makeController(ScriptedModel([]));
    await restored.initialize();
    final saved = restored.transcript.whereType<UserMessage>().single;
    expect(saved.id, message.id);
    expect((saved.content.first as ImageBlock).label, 'small.png');
    expect(AssistantAttachment.textFile(saved.content.last)?.name, 'plan.md');
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
    expect(assistant.operations.single.input['title'], '确认后的标题');
    final sessionId = assistant.currentSessionId!;
    await assistant.close();
    final restored = makeController(ScriptedModel([]));
    await restored.initialize();
    expect(restored.currentSessionId, sessionId);
    expect(restored.operations.single.input['title'], '确认后的标题');
    expect(restored.confirmProposal(operation.callId), isNotNull);
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
  test('非法日历日期零写入且不会阻塞为未知结果', () async {
    settings.autoApprove = true;
    final assistant = makeController(
      ScriptedModel([
        (_) => toolResponse('invalid-date', 'mission_create', {
          'title': '非法任务',
          'scheduledDate': '2026-02-30',
          'plannedMinutes': 20,
        }),
        (_) => textResponse('日期无效，没有保存。'),
      ]),
    );
    await assistant.initialize();
    await assistant.send('创建任务');
    expect(await missions.findAllDetails(), isEmpty);
    expect(assistant.needsOutcomeResolution, isFalse);
    expect(assistant.operations.single.status, AssistantOperationStatus.failed);
  });

  test('纽约任务改期仍按原时区解释15点', () async {
    settings.autoApprove = true;
    await missions.create(
      title: '纽约任务',
      scheduledDate: '2026-10-29',
      timeZone: 'America/New_York',
      plannedDurationMinutes: 20,
      timePolicy: TimePolicy.fixed,
      fixedStartAt: tz.TZDateTime(
        tz.getLocation('America/New_York'),
        2026,
        10,
        29,
        15,
      ).toUtc(),
    );
    final mission = (await missions.findAllDetails()).single;
    final assistant = makeController(
      ScriptedModel([
        (_) => toolResponse('ny-reschedule', 'mission_reschedule', {
          'missionId': mission.mission.id,
          'scheduledDate': '2026-10-30',
          'fixedStartLocal': '15:00',
        }),
        (_) => textResponse('已调整。'),
      ]),
    );
    await assistant.initialize();
    await assistant.send('挪到明天下午3点');
    final saved = await missions.findDetail(missionId: mission.mission.id);
    final local = tz.TZDateTime.from(
      saved!.schedule.fixedStartAt!,
      tz.getLocation('America/New_York'),
    );
    expect(local.hour, 15);
    expect(local.day, 30);
  });

  test('节点原位会话、编辑回执和跨重开引用一致', () async {
    final goal = goals.prepareCreation(title: '学习Flutter');
    await goals.create(goal);
    final node = goals.prepareNodeCreation(goalId: goal.id, title: '布局基础');
    await goals.createNode(node);
    final assistant = makeController(
      ScriptedModel([
        (_) => toolResponse('rename-node', 'goal_node_update', {
          'nodeId': node.id,
          'title': '响应式布局',
        }),
        (_) => textResponse('已修改节点。'),
      ]),
    );
    await assistant.initialize();
    await assistant.openNodeReference(node.id);
    final sessionId = assistant.currentSessionId;
    final sending = assistant.send('把这个节点改名为响应式布局');
    await waitFor(() => assistant.operations.isNotEmpty);
    expect((await goals.findNodeById(node.id))!.title, '布局基础');
    expect(
      assistant.updateProposal('rename-node', {
        'nodeId': 'another-node',
        'title': '错误',
      }),
      isNotNull,
    );
    assistant.confirmProposal('rename-node');
    await sending;
    expect((await goals.findNodeById(node.id))!.title, '响应式布局');
    final receipt = await missions.findOperationReceipt(
      '$sessionId:rename-node',
    );
    expect(receipt?.kind, 'goal_node_update');
    await assistant.close();
    final restored = makeController(ScriptedModel([]));
    await restored.initialize();
    await restored.openNodeReference(node.id);
    expect(restored.currentSessionId, sessionId);
    expect(restored.reference?.type, AssistantReferenceType.node);
    expect(restored.reference?.goalId, goal.id);
    expect(
      restored.transcript.whereType<UserMessage>().single.text,
      contains('这个节点'),
    );
  });
  test('首个会话前切换模型会影响新会话，历史改名仅修改指定会话', () async {
    final assistant = makeController(ScriptedModel([]));
    await assistant.initialize();
    await assistant.selectModelProfile('deepseek');
    await assistant.startNewSession();
    expect(assistant.modelProfileId, 'deepseek');
    final first = assistant.currentSessionId!;
    await assistant.renameCurrentSession('第一段');
    await assistant.startNewSession();
    final second = assistant.currentSessionId!;
    await assistant.renameCurrentSession('第二段');
    await assistant.renameConversation(first, '改过的第一段');
    expect(assistant.currentSessionId, second);
    expect(assistant.sessionTitle, '第二段');
    expect(
      assistant.conversations.singleWhere((item) => item.id == first).title,
      '改过的第一段',
    );
    await assistant.openConversation(first);
    expect(assistant.sessionTitle, '改过的第一段');
    expect(assistant.modelProfileId, 'deepseek');
  });

  test('完整任务编辑保留归属且只提交一次，取消有独立回执', () async {
    settings.autoApprove = true;
    await createMission('原标题');
    final original = (await missions.findAllDetails()).single;
    final assistant = makeController(
      ScriptedModel([
        (_) => toolResponse('edit-mission', 'mission_update', {
          'missionId': original.mission.id,
          'title': '新标题',
          'steps': ['先阅读', '再验证'],
          'notes': '新备注',
        }),
        (_) => textResponse('已修改。'),
        (_) => toolResponse('cancel-mission', 'mission_cancel', {
          'missionId': original.mission.id,
        }),
        (_) => textResponse('已取消。'),
      ]),
    );
    await assistant.initialize();
    await assistant.send('修改这个任务');
    final saved = (await missions.findDetail(missionId: original.mission.id))!;
    expect(saved.mission.title, '新标题');
    expect(saved.executionPlan.steps, ['先阅读', '再验证']);
    expect(saved.executionPlan.notes, '新备注');
    expect(saved.schedule.scheduledDate, original.schedule.scheduledDate);
    await assistant.send('取消这个任务');
    expect(
      (await missions.findDetail(
        missionId: original.mission.id,
      ))!.mission.cancelledAt,
      isNotNull,
    );
    expect(
      (await missions.findOperationReceipt(
        '${assistant.currentSessionId}:cancel-mission',
      ))?.kind,
      'mission_cancel',
    );
    expect((await missions.findAllDetails()), hasLength(1));
  });

  test('自定义服务配置可用于新会话，换回DeepSeek不会混用凭据', () async {
    final assistant = makeController(ScriptedModel([]));
    await assistant.initialize();
    final profile = ModelProfile(
      id: 'custom',
      provider: 'custom',
      model: 'custom-model',
      endpoint: Uri.parse('https://example.invalid/v1/chat/completions'),
      protocol: ModelProtocol.chatCompletions,
      credentialKey: 'MISSIONBOOK_CUSTOM_API_KEY',
      supportsImages: false,
    );
    await assistant.saveCustomProfile(profile);
    await assistant.saveCredential('fake-custom', profileId: 'custom');
    await assistant.selectModelProfile('custom');
    await assistant.startNewSession();
    expect(assistant.modelProfileId, 'custom');
    expect(assistant.hasCredential, isTrue);
    expect(assistant.customProfile?.endpoint, profile.endpoint);
    expect(
      await settings.resolveCredential('MISSIONBOOK_CUSTOM_API_KEY'),
      'fake-custom',
    );
    expect(
      await settings.resolveCredential('DEEPSEEK_API_KEY'),
      'test-credential',
    );
    await assistant.saveCredential('', profileId: 'custom');
    expect(assistant.hasCredential, isFalse);
    await assistant.selectModelProfile('deepseek-chat');
    expect(assistant.hasCredential, isTrue);
  });

  test('保存设置期间拒绝发送和切换会话，关闭等待配置落地', () async {
    final paused = PausedSettingsStore();
    settings = paused;
    final model = ScriptedModel([]);
    final assistant = makeController(model);
    await assistant.initialize();
    await assistant.startNewSession();
    paused.loadGate = Completer<void>();
    final saving = assistant.saveCredential('replacement-test-key');
    expect(assistant.configuring, isTrue);
    expect(assistant.isRunning, isFalse);
    await expectLater(assistant.send('不应发出'), throwsStateError);
    await expectLater(assistant.startNewSession(), throwsStateError);
    await expectLater(
      assistant.selectModelProfile('deepseek'),
      throwsStateError,
    );
    var closed = false;
    final closing = assistant.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    paused.loadGate!.complete();
    await saving;
    await closing;
    expect(model.requests, isEmpty);
    expect(assistant.configuring, isFalse);
  });

  test('打开旧会话后再次选择已存默认模型，实际会话也会切换', () async {
    final assistant = makeController(ScriptedModel([]));
    await assistant.initialize();
    await assistant.startNewSession();
    final oldId = assistant.currentSessionId!;
    await assistant.selectModelProfile('deepseek');
    await assistant.startNewSession();
    await assistant.selectModelProfile('deepseek-chat');
    await assistant.openConversation(oldId);
    expect(assistant.modelProfileId, 'deepseek');
    await assistant.selectModelProfile('deepseek-chat');
    expect(assistant.modelProfileId, 'deepseek-chat');
  });
}
