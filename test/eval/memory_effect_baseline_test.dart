// 记忆效果评测场景集：断言的是「目标行为」，不是当前实现。
// 在重构完成前允许失败，失败项即前基线证据；重构后同一文件应当全部通过。
// 运行：MEMORY_EVAL=1 flutter test --no-pub test/eval/memory_effect_baseline_test.dart
// 覆盖：跨会话回忆、目标级记忆、矛盾信息不覆盖、观察不当事实、压缩后仍在、
// 同义召回、写入闭环与回执幂等、检索结果回传模型。真实模型采纳不在本文件判定。
//
// 版本说明：P1 落地后本文件被适配到新 schema/API（memoryItems、layer/sourceKind/topic）。
// 各场景断言经逐条核对未被削弱；但 S6 已拆为 A（显式别名）与 B（自动同义消解），
// 原基线中的 S6 对应 B。因此 186ed75 的 5 通过/4 失败与当前结果不是同一测试文件版本的严格对比。
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/data/web/web_settings_store.dart';

import '../support/assistant_fakes.dart';

final _enabled = Platform.environment['MEMORY_EVAL'] == '1';

/// 评测集不进入默认门禁：前基线阶段有意失败，避免掩盖真实回归。
void evalTest(String name, Future<void> Function() body) => test(
  name,
  body,
  skip: _enabled ? false : '设置 MEMORY_EVAL=1 运行记忆效果评测场景集',
);

void main() {
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late RecordService records;
  late MemoryService memory;
  late DriftMemoryRepository repository;
  late DateTime now;
  AssistantController? assistant;

  setUp(() {
    now = DateTime.utc(2030, 1, 1, 8);
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db, clock: () => now));
    goals = GoalService(DriftGoalRepository(db));
    records = RecordService(
      DriftRecordRepository(db, clock: () => now),
      missions,
      missions.attachments,
    );
    repository = DriftMemoryRepository(db, clock: () => now);
    memory = MemoryService(repository);
  });

  tearDown(() async {
    await assistant?.close();
    assistant = null;
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<AssistantController> controller(_EvalModel model) async {
    final result = AssistantController(
      unifiedReader: DriftUnifiedReader(db),
      sessionStore: DriftSessionStore(db),
      settingsStore: MemoryAssistantSettingsStore()
        ..permissionMode = AssistantPermissionMode.full,
      missions: missions,
      goals: goals,
      records: records,
      memory: memory,
      analysis: DriftAnalysisStore(db),
      web: WebService(
        settings: const SecureWebSettings(),
        quota: DriftSearchQuota(db),
        fetchClient: () => throw StateError('评测集不出网'),
      ),
      modelOverrides: {'deepseek-chat': model},
    );
    assistant = result;
    await result.initialize();
    return result;
  }

  evalTest('[S1] 跨会话后能回忆用户偏好', () async {
    final model = _EvalModel([
      (_) => toolResponse('s1-save', 'saveMemory', {
        'content': '每天早上七点起床',
        'layer': 'identity',
        'certainty': 'stated',
        'topic': '起床时间',
        'basis': '我每天早上七点起床，记住这一点',
      }),
      (_) => textResponse('已经记住。'),
      (_) => textResponse('你一般早上七点起床。'),
    ]);
    final ai = await controller(model);
    await ai.send('我每天早上七点起床，记住这一点');

    await ai.startNewSession();
    await ai.send('我一般几点起床？');

    final delivered = requestText(model.requests.last);
    expect(
      delivered,
      contains('每天早上七点起床'),
      reason: '新会话的模型请求必须带上上一会话写入的偏好',
    );
    final rows = await db.select(db.memoryItems).get();
    expect(rows.single.content, '每天早上七点起床');
    expect(rows.single.certainty, 'stated');
  });

  evalTest('[S2] 目标级记忆进入该目标的助手上下文', () async {
    final goal = goals.prepareCreation(title: '三个月通过考试');
    await goals.create(goal);
    await memory.save({
      'id': 'goal-memory',
      'content': '这个目标是为了三个月后通过考试',
      'layer': 'semantic',
      'certainty': 'stated',
      'sourceKind': 'user',
      'topic': '目标动机',
      'goalId': goal.id,
    });
    final model = _EvalModel([(_) => textResponse('这个目标是为了三个月后通过考试。')]);
    final ai = await controller(model);
    await ai.openGoalReference(goal.id);
    await ai.send('我为什么要考这个试？');

    expect(
      requestText(model.requests.last),
      contains('三个月后通过考试'),
      reason: '引用目标时，目标级记忆必须进入上下文，而不是只取全局记忆',
    );
  });

  evalTest('[S3] 矛盾信息不静默覆盖原事实', () async {
    Map<String, Object?> entry(String id, String content) => {
      'id': id,
      'content': content,
      'layer': 'semantic',
      'certainty': 'stated',
      'sourceKind': 'extraction',
      'topic': '学习时段',
    };
    await repository.saveMemory(entry('old', '我晚上学习效率更高'));
    await repository.saveMemory(entry('new', '我早上学习效率更高'));

    final rows = await db.select(db.memoryItems).get();
    final old = rows.singleWhere((row) => row.id == 'old');
    expect(
      old.content,
      '我晚上学习效率更高',
      reason: '同主题新说法不得覆盖已有事实，否则是静默数据丢失',
    );
    expect(old.certainty, 'stated');
    final all = (await repository.queryMemory())['items'] as List;
    final contents = [
      for (final item in all) (item as Map<String, Object?>)['content'] as String,
    ];
    expect(contents, containsAll(['我晚上学习效率更高', '我早上学习效率更高']));
    final added = rows.singleWhere((row) => row.id == 'new');
    expect(added.certainty, 'unverified', reason: '并存的冲突说法只能是未验证候选');
  });

  evalTest('[S4] 观察可写入、标注未验证且不当作事实', () async {
    final model = _EvalModel([
      (_) => toolResponse('s4-save', 'saveMemory', {
        'content': '用户可能更喜欢早晨',
        'layer': 'observation',
        'basis': '我感觉早上学习更专注',
      }),
      (_) => textResponse('已记为待验证观察。'),
      (_) => textResponse('目前只有待验证观察。'),
    ]);
    final ai = await controller(model);
    await ai.send('我感觉早上学习更专注，但还不确定');

    final result = ai.transcript.whereType<ToolResultMessage>().single;
    expect(
      result.isError,
      isFalse,
      reason: '观察应当可以由助手写入；实际 ${result.errorCode} ${result.text}',
    );
    final row = (await db.select(db.memoryItems).get()).single;
    expect(row.layer, 'observation');
    expect(row.certainty, 'unverified');

    await ai.send('我早上状态怎么样？');
    final blocks = memoryBlocks(model.requests.last);
    expect(blocks, isNotNull, reason: '记忆上下文应当是分块结构');
    expect(
      blockContents(blocks!, 'unverified'),
      contains('用户可能更喜欢早晨'),
      reason: '观察必须在未验证块中单独标注',
    );
    for (final name in ['stable', 'goal', 'topic']) {
      expect(
        blockContents(blocks, name),
        isNot(contains('用户可能更喜欢早晨')),
        reason: '观察不得混入事实块 $name',
      );
    }
  });

  evalTest('[S5] 长对话压缩后核心记忆仍在模型请求中', () async {
    final profile = ModelProfile(
      id: 'eval-main',
      provider: 'test',
      model: 'eval-main',
      endpoint: Uri.parse('https://example.test/v1'),
      protocol: ModelProtocol.chatCompletions,
      credentialKey: 'EVAL_KEY',
      contextWindowTokens: 4000,
      maxOutputTokens: 400,
    );
    final summary = ModelProfile(
      id: 'eval-summary',
      provider: 'test',
      model: 'eval-summary',
      endpoint: Uri.parse('https://example.test/v1'),
      protocol: ModelProtocol.chatCompletions,
      credentialKey: 'EVAL_KEY',
      contextWindowTokens: 4000,
      maxOutputTokens: 256,
    );
    final model = _EvalModel(const []);
    final compactor = ContextCompactor(
      policy: ContextPolicy(
        headroomTokens: 128,
        keepRecentMessages: 2,
        summaryMaxTokens: 128,
      ),
      conversationProfile: profile,
      summaryProfile: summary,
      summaryModel: model,
    );
    final memoryMessage = ContextMessage(
      source: 'mission_book_memory',
      text: '当前有效记忆：用户每天早上七点起床',
    );
    final history = <AgentMessage>[
      UserMessage(text: '学习记录和明确约束。' * 300),
      textResponse('已记录。' * 200).message,
      memoryMessage,
      UserMessage(text: '我现在只剩两小时，请继续。'),
    ];
    final result = await compactor.prepare(
      ModelRequest(systemPrompt: '系统说明', messages: history, tools: const []),
      CancellationToken(),
    );
    expect(result, isNotNull, reason: '长历史应当触发压缩');
    final compacted = result!.contextMessages;
    expect(
      compacted.whereType<ContextMessage>().map((item) => item.text),
      contains('当前有效记忆：用户每天早上七点起床'),
      reason: '压缩保留的最近消息必须包含本轮记忆块',
    );
    expect(
      result.summary.summarizedMessageIds,
      isNot(contains(memoryMessage.id)),
      reason: '被保留的记忆块不应出现在摘要覆盖范围',
    );
    final next = ModelRequest(
      systemPrompt: '系统说明',
      messages: compacted,
      tools: const [],
    );
    expect(requestText(next), contains('每天早上七点起床'));
  });

  // 能力 A：调用方（AI 工具/抽取任务）显式登记别名后按别名召回。
  evalTest('[S6-A] 显式登记别名后按别名召回（能力 A）', () async {
    await memory.save({
      'id': 'run',
      'content': '我习惯早上跑步',
      'layer': 'identity',
      'certainty': 'stated',
      'sourceKind': 'user',
      'topic': '运动习惯',
      'aliases': ['晨跑', '早上跑步'],
    });
    final exact = (await repository.queryMemory(search: '早上跑步'))['items'] as List;
    expect(exact, hasLength(1), reason: '字面命中应当可召回');
    final synonym = (await repository.queryMemory(search: '晨跑'))['items'] as List;
    expect(
      [for (final item in synonym) (item as Map)['content']],
      contains('我习惯早上跑步'),
      reason: '显式登记别名后，无共同字面的查询应命中同一主题',
    );
  });

  // 能力 B：不提供任何别名，系统自行把「晨跑」与「早上跑步」消解为同一主题。
  // 这是原始 S6 的场景；当前实现依赖显式别名，因此本用例失败即能力边界证据。
  evalTest('[S6-B] 未登记别名时自动同义消解（能力 B）', () async {
    await memory.save({
      'id': 'run-auto',
      'content': '我习惯早上跑步',
      'layer': 'identity',
      'certainty': 'stated',
      'sourceKind': 'user',
      'topic': '运动习惯',
    });
    final synonym = (await repository.queryMemory(search: '晨跑'))['items'] as List;
    expect(
      [for (final item in synonym) (item as Map)['content']],
      contains('我习惯早上跑步'),
      reason: 'B 未实现：没有任何别名输入时，关键词“晨跑”与“早上跑步”无共同字面片段',
    );
  });

  evalTest('[S7] 助手写入经仓储落库并生成幂等回执', () async {
    final model = _EvalModel([
      (_) => toolResponse('s7-save', 'saveMemory', {
        'content': '工作日喜欢在上午学习',
        'layer': 'identity',
        'certainty': 'stated',
        'topic': '学习时段',
        'basis': '以后工作日我都想在上午学习',
      }),
      (_) => textResponse('记住了。'),
    ]);
    final ai = await controller(model);
    await ai.send('以后工作日我都想在上午学习');

    final result = ai.transcript.whereType<ToolResultMessage>().single;
    expect(result.isError, isFalse);
    final row = (await db.select(db.memoryItems).get()).single;
    expect(row.content, '工作日喜欢在上午学习');
    expect(row.sourceKind, 'assistant');
    expect(row.sourceRef, startsWith('conversation:'));
    final receipts = await db.select(db.operationReceipts).get();
    expect(receipts, hasLength(1));
    expect(receipts.single.kind, 'memory_save');
    expect(
      receipts.single.entityId,
      row.id,
      reason: '回执 entityId 必须等于最终记忆 id',
    );
    expect((jsonDecode(result.text) as Map)['status'], 'created');
  });

  evalTest('[S7b] 同一操作编号重复提交不产生第二条记忆或回执', () async {
    final entry = {
      'id': 'idem-memory',
      'content': '喜欢上午学习',
      'layer': 'identity',
      'certainty': 'stated',
      'sourceKind': 'user',
      'topic': '学习时段',
    };
    final first = await repository.saveMemory(entry, operationId: 'op-idem');
    final second = await repository.saveMemory(entry, operationId: 'op-idem');
    expect(second, first);
    expect(await db.select(db.memoryItems).get(), hasLength(1));
    expect(await db.select(db.operationReceipts).get(), hasLength(1));
  });

  evalTest('[S8] 检索结果回传模型（实际采纳需真实模型验证）', () async {
    await memory.save({
      'id': 'allergy',
      'content': '对花生过敏，不能吃花生',
      'layer': 'identity',
      'certainty': 'stated',
      'sourceKind': 'user',
      'topic': '过敏',
    });
    final model = _EvalModel([
      (_) => toolResponse('s8-query', 'getMemory', {'search': '过敏'}),
      (_) => textResponse('已查到你的过敏记录。'),
    ]);
    final ai = await controller(model);
    await ai.send('帮我查一下我的过敏记录');

    final result = ai.transcript.whereType<ToolResultMessage>().single;
    expect(result.isError, isFalse);
    expect(result.text, contains('花生'));
    expect(
      requestText(model.requests.last),
      contains('对花生过敏'),
      reason: '工具结果必须在下一轮请求中回传给模型',
    );
  });
}

/// 会话模型；摘要请求单独记账，不消耗脚本响应。
class _EvalModel implements AgentModel {
  _EvalModel(Iterable<ModelResponse Function(ModelRequest)> responses)
    : _responses = Queue.of(responses);
  final Queue<ModelResponse Function(ModelRequest)> _responses;
  final requests = <ModelRequest>[];
  final summaryRequests = <ModelRequest>[];

  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    if (request.purpose == ModelRequestPurpose.summary) {
      summaryRequests.add(request);
      return textResponse('早期对话已压缩为摘要。');
    }
    requests.add(request);
    if (_responses.isEmpty) throw StateError('脚本模型没有更多响应');
    return _responses.removeFirst()(request);
  }
}

String requestText(ModelRequest request) =>
    request.messages.map((message) => message.text).join('\n---\n');

/// 解析本轮记忆上下文的分块 JSON；不是对象（旧实现返回数组/空）时返回 null。
Map<String, Object?>? memoryBlocks(ModelRequest request) {
  for (final message in request.messages.whereType<ContextMessage>()) {
    if (message.source != 'mission_book_memory') continue;
    final index = message.text.indexOf('：');
    if (index < 0) return null;
    final decoded = jsonDecode(message.text.substring(index + 1));
    return decoded is Map<String, Object?> ? decoded : null;
  }
  return null;
}

List<String> blockContents(Map<String, Object?> blocks, String name) => [
  for (final item in (blocks[name] as List? ?? const []))
    (item as Map<String, Object?>)['content'] as String,
];
