// 多轮连续压缩与旧摘要组合的评测。
// 判定依据：摘要请求输入、压缩后的模型可见上下文、核心偏好是否仍被固定保留。
// 运行：MEMORY_COMPACTION=1 flutter test --no-pub test/eval/memory_multi_compaction_test.dart
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

final _enabled = Platform.environment['MEMORY_COMPACTION'] == '1';
const _window = 20000;

AgentConfiguration _configuration({bool auto = false}) {
  final base = AgentConfiguration.deepSeek();
  return AgentConfiguration(
    profiles: [
      for (final profile in base.profiles)
        ModelProfile.fromJson({
          ...profile.toJson(),
          'contextWindowTokens': _window,
          'maxOutputTokens': 512,
          'reasoningEffort': 'off',
        }),
    ],
    defaultModelProfile: base.defaultModelProfile,
    maxSteps: 4,
    maxRunDuration: const Duration(minutes: 2),
    // 只走手动压缩，避免自动压缩干扰“连续两次压缩”的判定。
    context: ContextPolicy(
      enabled: auto,
      triggerRatio: auto ? 0.3 : 0.8,
      targetRatio: auto ? 0.2 : 0.5,
      headroomTokens: 512,
      keepRecentMessages: 6,
      summaryMaxTokens: 256,
      maxSummaryCalls: 3,
    ),
  );
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late RecordService records;
  late DriftMemoryRepository repository;
  late MemoryService memory;
  late _DigestModel model;
  AssistantController? assistant;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db));
    goals = GoalService(DriftGoalRepository(db));
    records = RecordService(
      DriftRecordRepository(db),
      missions,
      missions.attachments,
    );
    repository = DriftMemoryRepository(db);
    memory = MemoryService(repository);
    model = _DigestModel();
  });

  tearDown(() async {
    await assistant?.close();
    assistant = null;
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<AssistantController> start({bool auto = false}) async {
    final controller = AssistantController(
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
      configuration: _configuration(auto: auto),
      modelOverrides: {'deepseek-chat': model},
    );
    assistant = controller;
    await controller.initialize();
    await controller.startNewSession();
    return controller;
  }

  Future<void> seed() async {
    await memory.save({
      'id': 'core',
      'content': '我每天早上七点起床',
      'layer': 'identity',
      'certainty': 'stated',
      'sourceKind': 'user',
      'topic': '起床时间',
      'importance': 90,
    });
    await memory.save({
      'id': 'commute',
      'content': '我上班先坐42路公交再换7号线',
      'layer': 'semantic',
      'certainty': 'stated',
      'sourceKind': 'user',
      'topic': '通勤路线',
    });
  }

  Future<void> longTurn(AssistantController ai, String prefix) =>
      ai.send('$prefix${'背景资料。' * 600}');

  for (final auto in [false, true]) {
    test('[真实查询遗忘] getMemory→忘记→${auto ? '自动' : '手动'}压缩→重开', () async {
      await seed();
      model.queryMemory = true;
      final ai = await start(auto: auto);
      await ai.send('查询我的通勤记忆。用户原话：本次禁止删除任务。');
      expect(ai.errorMessage, isNull);
      final original = ai.transcript.whereType<ToolResultMessage>().singleWhere(
        (message) => message.toolName == 'getMemory',
      );
      expect(original.text, contains('42路'));
      expect(requestText(model.requests.last), contains('42路'));
      await repository.forgetMemory('commute');
      model.summaryRequests.clear();
      for (var i = 0; i < 6; i++) {
        await longTurn(ai, '遗忘后第$i轮：');
        expect(ai.errorMessage, isNull);
      }
      if (!auto) expect(await ai.compactConversation(), isNotNull);
      expect(model.summaryRequests, isNotEmpty);
      for (final request in model.summaryRequests) {
        expect(requestText(request), isNot(contains('42路')));
      }
      expect(requestText(model.requests.last), isNot(contains('42路')));
      final id = ai.currentSessionId!;
      // 当前控制器仍持有会话窗口；后续关闭并重开会验证失效记录已持久化，
      // 避免在同一 DriftSessionStore 上重复打开活动会话。
      expect(
        ai.transcript
            .whereType<ToolResultMessage>()
            .singleWhere((message) => message.id == original.id)
            .text,
        contains('42路'),
      );
      await ai.close();
      assistant = null;
      final reopened = await start(auto: auto);
      await reopened.openConversation(id);
      await reopened.send('重开后继续确认');
      expect(reopened.errorMessage, isNull);
      expect(requestText(model.requests.last), isNot(contains('42路')));
      expect(
        reopened.transcript.whereType<UserMessage>().first.text,
        contains('本次禁止删除任务'),
      );
    }, timeout: const Timeout(Duration(minutes: 5)));
  }

  test(
    '[多轮压缩] 两次连续压缩后核心偏好仍在、已忘记内容不残留',
    () async {
      await seed();
      final ai = await start();
      await longTurn(ai, '第一轮：');
      await longTurn(ai, '第二轮：');
      await ai.send('继续整理。');

      final first = await ai.compactConversation();
      expect(first, isNotNull, reason: '第一次手动压缩应成功');
      expect(
        requestText(model.summaryRequests.last),
        isNot(contains('42路')),
        reason: '第一次压缩的摘要输入不得包含记忆块',
      );
      expect(
        requestText(model.summaryRequests.last),
        isNot(contains('七点')),
        reason: '记忆块是供给块，不得进入摘要输入',
      );

      await repository.forgetMemory('commute');
      await longTurn(ai, '第三轮：');
      await longTurn(ai, '第四轮：');
      await ai.send('继续整理。');

      final second = await ai.compactConversation();
      expect(second, isNotNull, reason: '第二次手动压缩应成功');
      expect(
        requestText(model.summaryRequests.last),
        isNot(contains('42路')),
        reason: '第二次压缩的摘要输入不得重新引入已忘记内容',
      );

      await ai.send('最后确认。');
      final visible = requestText(model.requests.last);
      expect(visible, contains('七点'), reason: '核心偏好应固定在模型可见上下文中');
      expect(visible, isNot(contains('42路')), reason: '已忘记内容不得残留在可见上下文');
      expect(visible, contains('摘要'), reason: '连续压缩后的上下文应包含摘要消息');
    },
    skip: _enabled ? false : '设置 MEMORY_COMPACTION=1 运行压缩路径评测',
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    '[旧摘要组合] 清洗前生成的旧摘要不得进入新压缩的摘要输入或可见上下文',
    () async {
      final conversationProfile = ModelProfile(
        id: 'legacy-main',
        provider: 'test',
        model: 'legacy-main',
        endpoint: Uri.parse('https://example.test/v1'),
        protocol: ModelProtocol.chatCompletions,
        credentialKey: 'EVAL_KEY',
        contextWindowTokens: 4000,
        maxOutputTokens: 256,
      );
      final summaryProfile = ModelProfile(
        id: 'legacy-summary',
        provider: 'test',
        model: 'legacy-summary',
        endpoint: Uri.parse('https://example.test/v1'),
        protocol: ModelProtocol.chatCompletions,
        credentialKey: 'EVAL_KEY',
        contextWindowTokens: 4000,
        maxOutputTokens: 256,
      );
      final compactor = ContextCompactor(
        policy: ContextPolicy(
          headroomTokens: 128,
          keepRecentMessages: 2,
          summaryMaxTokens: 128,
        ),
        conversationProfile: conversationProfile,
        summaryProfile: summaryProfile,
        summaryModel: model,
      );
      final oldUser = UserMessage(text: '旧对话一', id: 'legacy-u1');
      final oldAnswer = AssistantMessage(
        content: [TextBlock(text: '旧回答一')],
        provider: 'test',
        model: 'test',
        id: 'legacy-a1',
      );
      // 模拟 P1 之前生成的摘要：其中已经写入了后来被用户忘记的通勤路线。
      final legacySummary = ContextSummaryMessage(
        id: 'legacy-summary',
        text: '旧摘要：用户上班先坐42路公交再换7号线',
        summarizedMessageIds: [oldUser.id, oldAnswer.id],
      );
      final history = <AgentMessage>[
        oldUser,
        oldAnswer,
        legacySummary,
        UserMessage(text: '中间对话：${'背景资料。' * 350}'),
        AssistantMessage(
          content: [TextBlock(text: '收到')],
          provider: 'test',
          model: 'test',
        ),
        UserMessage(text: '继续。'),
      ];

      final result = await compactor.prepare(
        ModelRequest(systemPrompt: '系统说明', messages: history, tools: const []),
        CancellationToken(),
        trigger: CompactionTrigger.manual,
      );
      expect(result, isNotNull, reason: '新压缩应成功');
      expect(
        requestText(model.summaryRequests.last),
        isNot(contains('42路')),
        reason: '旧摘要不得被再次喂给新摘要；需要一次性清洗或版本化失效',
      );
      expect(
        requestText(
          ModelRequest(
            systemPrompt: '系统说明',
            messages: result!.contextMessages,
            tools: const [],
          ),
        ),
        isNot(contains('42路')),
        reason: '旧摘要内容不得残留在模型可见上下文',
      );
    },
    skip: _enabled ? false : '设置 MEMORY_COMPACTION=1 运行压缩路径评测',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _DigestModel implements AgentModel {
  _DigestModel();
  final requests = <ModelRequest>[];
  final summaryRequests = <ModelRequest>[];
  bool queryMemory = false;
  bool memoryQueried = false;

  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    if (request.purpose == ModelRequestPurpose.summary) {
      summaryRequests.add(request);
      return textResponse('摘要：${request.messages.length} 条历史已压缩');
    }
    requests.add(request);
    final pendingMemory = request.messages
        .whereType<AssistantMessage>()
        .expand((message) => message.toolCalls)
        .any((call) => call.name == 'getMemory');
    if (queryMemory && !memoryQueried && !pendingMemory) {
      memoryQueried = true;
      final tool = request.tools.where((tool) => tool.name == 'getMemory');
      if (tool.isNotEmpty) {
        return toolResponse('eval-memory-call', 'getMemory', {
          'search': '通勤路线',
          'limit': 10,
        });
      }
    }
    return textResponse('收到。');
  }
}

String requestText(ModelRequest request) =>
    request.messages.map((message) => message.text).join('\n---\n');
