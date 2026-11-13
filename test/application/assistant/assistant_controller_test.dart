import 'package:mission_book/data/assistant/drift_unified_reader.dart';
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
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
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

class SwitchableMemory extends MemoryService {
  SwitchableMemory(super.repository);
  bool failing = false;

  @override
  Future<Map<String, Object?>> query({
    String? goalId,
    String? search,
    int offset = 0,
    int limit = 20,
    bool includeExpired = false,
    String? layer,
    String? certainty,
    int? candidateLimit,
  }) {
    if (failing) throw StateError('记忆读取失败');
    return super.query(
      goalId: goalId,
      search: search,
      offset: offset,
      limit: limit,
      includeExpired: includeExpired,
      layer: layer,
      certainty: certainty,
      candidateLimit: candidateLimit,
    );
  }
}

class PausedDeleteStore extends DriftSessionStore {
  PausedDeleteStore(super.database);
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> delete(String id) async {
    entered.complete();
    await release.future;
    await super.delete(id);
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
    DriftSessionStore? sessionStore,
    MemoryService? memory,
  }) {
    final result = AssistantController(
      unifiedReader: DriftUnifiedReader(database),
      sessionStore: sessionStore ?? DriftSessionStore(database),
      settingsStore: settings,
      missions: missions,
      goals: goals,
      memory: memory,
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

  test('记忆每轮只注入最新一份，读取失败不阻断发送', () async {
    final repository = DriftMemoryRepository(database, clock: () => now);
    await repository.saveMemory({
      'id': 'memory',
      'content': '喜欢上午学习',
      'layer': 'identity',
      'certainty': 'stated',
      'topic': '学习时间',
      'sourceKind': 'user',
    });
    final memory = SwitchableMemory(repository);
    final model = ScriptedModel([
      (_) => textResponse('第一答'),
      (_) => textResponse('第二答'),
      (_) => textResponse('第三答'),
      (_) => textResponse('第四答'),
    ]);
    final ai = makeController(model, memory: memory);
    await ai.initialize();
    List<ContextMessage> blocks(ModelRequest request) => request.messages
        .whereType<ContextMessage>()
        .where((message) => message.source == 'mission_book_memory')
        .toList();
    await ai.send('第一问');
    expect(blocks(model.requests.last), hasLength(1));
    expect(blocks(model.requests.last).single.text, contains('喜欢上午学习'));
    await ai.send('第二问');
    expect(blocks(model.requests.last), hasLength(1));
    memory.failing = true;
    await ai.send('第三问');
    expect(ai.errorMessage, isNull);
    expect(blocks(model.requests.last), isEmpty);
    expect(model.requests, hasLength(3));
    expect(ai.memoryWarning, isNotNull);
    memory.failing = false;
    await ai.send('恢复后的问题');
    expect(ai.memoryWarning, isNull);
    expect(blocks(model.requests.last), hasLength(1));
  });

  test('直接采用记忆的旧回答在遗忘后不回流，原始对话仍可查看', () async {
    final memory = MemoryService(DriftMemoryRepository(database));
    await memory.save({
      'id': 'private',
      'content': '我的验收标记是赤杉6814',
      'topic': '验收标记',
      'layer': 'semantic',
      'certainty': 'stated',
      'sourceKind': 'user',
    });
    final model = ScriptedModel([
      (_) => textResponse('你的标记是赤杉6814'),
      (_) => textResponse('不知道'),
    ]);
    final ai = makeController(model, memory: memory);
    await ai.initialize();
    await ai.send('我的验收标记是什么');
    await memory.forget('private');
    await ai.send('现在还知道我的标记吗');
    expect(
      model.requests.last.messages.map((m) => m.text).join(),
      isNot(contains('赤杉6814')),
    );
    expect(ai.transcript.map((m) => m.text).join(), contains('赤杉6814'));
    expect(ai.errorMessage, isNull);
  });

  test('并发打开同一会话和切换全局入口不会重复持有运行时会话', () async {
    final ai = makeController(ScriptedModel([(_) => textResponse('已回答')]));
    await ai.initialize();
    await ai.send('建立全局历史');
    final global = ai.currentSessionId!;
    await ai.startNewSession();
    await Future.wait([
      ai.openConversation(global),
      ai.openConversation(global),
    ]);
    expect(ai.currentSessionId, global);
    expect(ai.transcript.whereType<UserMessage>().length, 1);
    expect(ai.isBusy, false);
    await ai.startNewSession();
    await Future.wait([
      ai.openConversation(global),
      ai.openGlobalConversation(),
    ]);
    expect(ai.currentSessionId, global);
  });

  test('外部截图通知当前聊天并在达到数量上限时保留原草稿', () async {
    final ai = makeController(ScriptedModel([]));
    await ai.initialize();
    final image = AssistantAttachment.fromBytes(
      'screen.png',
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      ),
    );
    var changes = 0;
    ai.addListener(() => changes++);
    for (var i = 0; i < AssistantAttachment.maxCount; i++) {
      ai.addCapturedAttachment(image);
    }
    expect(changes, AssistantAttachment.maxCount);
    expect(() => ai.addCapturedAttachment(image), throwsFormatException);
    expect(ai.attachmentsFor(ai.draftKey).length, AssistantAttachment.maxCount);
    expect(ai.currentSessionId, isNull);
  });

  test('后台超过写租约仍可发送，回前台不需要重启应用', () async {
    var leaseClock = now;
    final model = ScriptedModel([
      (_) => textResponse('正常回答'),
      (_) => textResponse('正常回答'),
    ]);
    final assistant = AssistantController(
      unifiedReader: DriftUnifiedReader(database),
      sessionStore: DriftSessionStore(database, clock: () => leaseClock),
      settingsStore: settings,
      missions: missions,
      goals: goals,
      modelOverrides: {'deepseek-chat': model, 'deepseek': model},
      clock: () => now,
    );
    controller = assistant;
    await assistant.initialize();
    await assistant.saveCredential('test-key');
    await assistant.send('第一条');
    final sessionId = assistant.currentSessionId;
    assistant.setForeground(false);
    leaseClock = leaseClock.add(const Duration(minutes: 10));
    assistant.setForeground(true);
    await assistant.send('回到前台继续');
    expect(assistant.currentSessionId, sessionId);
    expect(assistant.errorMessage, isNull);
    expect(assistant.transcript.whereType<UserMessage>().length, 2);
  });

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

  test('自定义角色和回答风格进入当前及重开会话的模型请求', () async {
    final model = ScriptedModel([
      (_) => textResponse('收到'),
      (_) => textResponse('继续'),
    ]);
    final assistant = makeController(model);
    await assistant.initialize();
    const persona = AssistantPersona(
      customRole: '协助我修改小说，先保留原意再提出修改。',
      customReplyStyle: '每次先列两个要点，再给一个具体例子。',
    );
    await assistant.savePersona(persona);
    await assistant.send('开始');
    final id = assistant.currentSessionId!;
    expect(model.requests.last.systemPrompt, contains(persona.customRole));
    expect(
      model.requests.last.systemPrompt,
      contains(persona.customReplyStyle),
    );
    await assistant.startNewSession();
    await assistant.openConversation(id);
    await assistant.send('继续');
    expect(model.requests.last.systemPrompt, contains(persona.customRole));
    expect(model.requests.last.systemPrompt, contains('不能改变工具权限'));
  });

  test('删除会话回收草稿；打开另一会话不沿用旧错误和迟到保存', () async {
    final model = ScriptedModel([
      (_) => throw StateError('模拟模型失败'),
      (_) => textResponse('第二个会话'),
      (_) => throw StateError('第二次模型失败'),
    ]);
    final assistant = makeController(model);
    await assistant.initialize();
    await assistant.send('失败输入');
    final failedId = assistant.currentSessionId!;
    expect(assistant.errorMessage, isNotNull);
    assistant.saveDraft(failedId, '失败会话草稿');
    assistant.saveAttachments(failedId, [
      AssistantAttachment.fromBytes(
        'draft.txt',
        Uint8List.fromList(utf8.encode('失败会话附件')),
      ),
    ]);

    await assistant.startNewSession();
    await assistant.send('第二个会话');
    final secondId = assistant.currentSessionId!;
    expect(secondId, isNot(failedId));
    assistant.saveDraft(secondId, '当前会话草稿');
    final failedAgain = await assistant.send('再次失败');
    expect(failedAgain?.failure, isNotNull);
    expect(assistant.errorMessage, isNotNull);

    await assistant.openConversation(failedId);
    expect(assistant.errorMessage, isNull);
    await assistant.deleteConversation(failedId);
    expect(assistant.currentSessionId, secondId);
    expect(assistant.draftFor(failedId), isEmpty);
    expect(assistant.attachmentsFor(failedId), isEmpty);

    assistant.saveDraft(failedId, '旧页面延迟保存的草稿');
    assistant.saveAttachments(failedId, [
      AssistantAttachment.fromBytes(
        'late.txt',
        Uint8List.fromList(utf8.encode('旧页面延迟保存的附件')),
      ),
    ]);
    expect(assistant.draftFor(failedId), isEmpty);
    expect(assistant.attachmentsFor(failedId), isEmpty);
    expect(assistant.draftFor(secondId), '当前会话草稿');
  });

  test('真实日期查询经工具返回，快捷查询不依赖模型', () async {
    await createMission('阅读第一章');
    final model = ScriptedModel([
      (_) => toolResponse('call-query', 'getSchedule', const {
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

  test('工具准备阶段的业务拒绝保留分类编号，不冒充权限不足', () async {
    final assistant = makeController(
      ScriptedModel([
        (_) => toolResponse('missing-goal', 'updateGoal', const {
          'goalId': 'gone',
          'title': '新名称',
        }),
        (_) => textResponse('目标不存在，需要重新查询'),
      ]),
    );
    await assistant.initialize();
    await assistant.send('把已删除的目标改名');
    final toolResult = assistant.transcript
        .whereType<ToolResultMessage>()
        .single;
    expect(toolResult.errorCode, 'not_found');
    expect(toolResult.text, contains('gone'));
  });

  test('默认档读取等待授权，宽松档自动查询且仍拦住写入', () async {
    settings.permissionMode = AssistantPermissionMode.standard;
    final assistant = makeController(
      ScriptedModel([
        (_) => toolResponse('strict-read', 'getSchedule', {}),
        (_) => textResponse('查询结束'),
        (_) => toolResponse('relaxed-read', 'getSchedule', {}),
        (_) => toolResponse('relaxed-write', 'createMission', {
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
      (_) => toolResponse('call-create', 'createMission', const {
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
      (_) => toolResponse('call-create', 'createMission', const {
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
    settings.permissionMode = AssistantPermissionMode.full;
    final model = ScriptedModel([
      (_) => toolResponse('call-create', 'createMission', const {
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
      (_) => toolResponse('call-edit', 'rescheduleMission', {
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
      (_) => toolResponse('call-create', 'createMission', const {
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
      (_) => toolResponse('call-query', 'getSchedule', const {
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
    settings.permissionMode = AssistantPermissionMode.full;
    final assistant = makeController(
      ScriptedModel([
        (_) => toolResponse('invalid-date', 'createMission', {
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
    settings.permissionMode = AssistantPermissionMode.full;
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
        (_) => toolResponse('ny-reschedule', 'rescheduleMission', {
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
        (_) => toolResponse('rename-node', 'updateGoalNode', {
          'nodeId': node.id,
          'title': '响应式布局',
        }),
        (_) => textResponse('已修改节点。'),
      ]),
    );
    await assistant.initialize();
    await assistant.openNodeReference(node.id);
    expect(assistant.currentSessionId, isNull);
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
    final sessionId = assistant.currentSessionId;
    final receipt = await missions.findOperationReceipt(
      '$sessionId:rename-node',
    );
    expect(receipt?.kind, 'updateGoalNode');
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
    final assistant = makeController(
      ScriptedModel([
        (_) => textResponse('第一段回答'),
        (_) => textResponse('第二段回答'),
      ]),
    );
    await assistant.initialize();
    await assistant.selectModelProfile('deepseek');
    await assistant.startNewSession();
    expect(assistant.modelProfileId, 'deepseek');
    expect(assistant.currentSessionId, isNull);
    await assistant.send('第一段讨论');
    final first = assistant.currentSessionId!;
    await assistant.renameCurrentSession('第一段');
    await assistant.startNewSession();
    expect(assistant.currentSessionId, isNull);
    await assistant.send('第二段讨论');
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
    settings.permissionMode = AssistantPermissionMode.full;
    await createMission('原标题');
    final original = (await missions.findAllDetails()).single;
    final assistant = makeController(
      ScriptedModel([
        (_) => toolResponse('edit-mission', 'updateMission', {
          'missionId': original.mission.id,
          'title': '新标题',
          'steps': ['先阅读', '再验证'],
          'notes': '新备注',
        }),
        (_) => textResponse('已修改。'),
        (_) => toolResponse('cancel-mission', 'cancelMission', {
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
      'cancelMission',
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
    final assistant = makeController(
      ScriptedModel([(_) => textResponse('旧会话回答')]),
    );
    await assistant.initialize();
    await assistant.startNewSession();
    await assistant.send('需要保留的旧讨论');
    final oldId = assistant.currentSessionId!;
    await assistant.selectModelProfile('deepseek');
    await assistant.startNewSession();
    await assistant.selectModelProfile('deepseek-chat');
    await assistant.openConversation(oldId);
    expect(assistant.modelProfileId, 'deepseek');
    await assistant.selectModelProfile('deepseek-chat');
    expect(assistant.modelProfileId, 'deepseek-chat');
  });
  test('删除与切换串行，维护期间拒绝发送且最终会话一致', () async {
    final store = PausedDeleteStore(database);
    final assistant = makeController(
      ScriptedModel([(_) => textResponse('第一条'), (_) => textResponse('第二条')]),
      sessionStore: store,
    );
    await assistant.initialize();
    await assistant.send('第一会话');
    final first = assistant.currentSessionId!;
    await assistant.startNewSession();
    await assistant.send('第二会话');
    final second = assistant.currentSessionId!;
    await assistant.openConversation(first);
    final deletion = assistant.deleteConversation(first);
    await store.entered.future;
    expect(assistant.isBusy, isTrue);
    await expectLater(assistant.send('不能发到正在删除的会话'), throwsStateError);
    final opening = assistant.openConversation(second);
    store.release.complete();
    await Future.wait([deletion, opening]);
    expect(assistant.currentSessionId, second);
    expect(assistant.isBusy, isFalse);
    expect(assistant.conversations.map((item) => item.id), [second]);
  });
}
