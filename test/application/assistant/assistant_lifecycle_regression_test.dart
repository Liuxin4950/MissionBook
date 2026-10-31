import 'dart:async';
import 'dart:typed_data';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/evidence/evidence_image_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_assistant_reader.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';

import '../../support/assistant_fakes.dart';

class _Model implements AgentModel {
  _Model(this.respond);
  final FutureOr<ModelResponse> Function(ModelRequest, int) respond;
  final requests = <ModelRequest>[];
  final tokens = <CancellationToken>[];
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) {
    requests.add(request);
    tokens.add(cancellation);
    return Future.sync(() => respond(request, requests.length));
  }
}

class _Images implements EvidenceImageStore, EvidenceImagePicker {
  int reads = 0;
  @override
  Future<Uint8List> read(String storageKey) async {
    reads++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> delete(String storageKey) async {}
  @override
  Future<Set<String>> listKeys() async => {};
  @override
  Future<SelectedEvidenceImage?> pick() async => null;
  @override
  Future<void> writeNew(String storageKey, Uint8List bytes) async {}
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late MemoryAssistantSettingsStore settings;
  late _Images images;
  AssistantController? assistant;
  final now = DateTime.utc(2030, 1, 1);

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    images = _Images();
    missions = MissionService(
      DriftMissionRepository(db, clock: () => now),
      images: EvidenceImageService(store: images, picker: images),
      clock: () => now,
    );
    goals = GoalService(DriftGoalRepository(db));
    settings = MemoryAssistantSettingsStore();
    assistant = null;
  });
  tearDown(() async {
    await assistant?.close();
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<AssistantController> create(
    AgentModel? model, {
    bool supportsImages = true,
  }) async {
    final result = AssistantController(
      reader: DriftAssistantReader(db),
      sessionStore: DriftSessionStore(db),
      settingsStore: settings,
      missions: missions,
      goals: goals,
      clock: () => now,
      analysisTimeout: const Duration(milliseconds: 60),
      connectionTestTimeout: const Duration(milliseconds: 60),
      configuration: AgentConfiguration(
        profiles: [
          ModelProfile(
            id: 'deepseek-chat',
            provider: 'test',
            model: 'test-model',
            endpoint: Uri.parse('https://example.invalid/chat/completions'),
            protocol: ModelProtocol.chatCompletions,
            credentialKey: 'DEEPSEEK_API_KEY',
            supportsImages: supportsImages,
            retry: RetryPolicy(maxRetries: 0),
          ),
        ],
        defaultModelProfile: 'deepseek-chat',
      ),
      modelOverrides: model == null ? const {} : {'deepseek-chat': model},
    );
    assistant = result;
    await result.initialize();
    return result;
  }

  Future<void> waitFor(bool Function() condition) async {
    for (var i = 0; i < 200; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    fail('等待请求状态超时');
  }

  test('分析只携带本次来源、无工具或会话记忆，JSON和图片进入正确模型请求', () async {
    final model = _Model((r, n) => textResponse('来源分析'));
    final ai = await create(model);
    expect(
      await ai.analyze(
        '这张照片',
        imageKey: 'attachments/x/a.png',
        mime: 'image/png',
        json: true,
      ),
      '来源分析',
    );
    final request = model.requests.single;
    expect(request.purpose, ModelRequestPurpose.summary);
    expect(request.jsonOutput, isTrue);
    expect(request.tools, isEmpty);
    expect(request.messages, hasLength(1));
    expect(
      request.messages.single.content.whereType<ImageBlock>().single.url,
      'data:image/png;base64,AQID',
    );
    expect(images.reads, 1);
    expect(ai.transcript, isEmpty);
    expect(await db.select(db.assistantSessions).get(), isEmpty);
  });

  test('无凭据或模型不支持图片时明确拒绝，不读取图片或调用网络', () async {
    settings.credential = null;
    final ai = await create(null);
    await expectLater(ai.analyze('来源'), throwsA(isA<AnalysisUnavailable>()));
    await ai.close();
    settings.credential = 'test';
    final model = _Model((r, n) => textResponse('不应调用'));
    final textOnly = await create(model, supportsImages: false);
    await expectLater(
      textOnly.analyze('图片', imageKey: 'attachments/x/a.png'),
      throwsA(isA<AnalysisUnavailable>()),
    );
    expect(images.reads, 0);
    expect(model.requests, isEmpty);
  });

  test('主会话立即抢占不响应取消的后台分析，迟到错误被接收', () async {
    final late = Completer<ModelResponse>();
    final model = _Model(
      (r, n) => r.purpose == ModelRequestPurpose.summary
          ? late.future
          : textResponse('主会话完成'),
    );
    final ai = await create(model);
    final analyzed = expectLater(
      ai.analyze('后台来源'),
      throwsA(isA<AnalysisInterrupted>()),
    );
    await waitFor(() => model.requests.isNotEmpty);
    await ai.send('处理当前请求');
    await analyzed;
    expect(model.tokens.first.isCancelled, isTrue);
    late.completeError(StateError('迟到模型错误'));
    await Future<void>.delayed(Duration.zero);
    expect(ai.transcript.whereType<UserMessage>().single.text, '处理当前请求');
  });

  test('后台分析超时真正结束等待，迟到成功不发布，下一次仍能调用', () async {
    final late = Completer<ModelResponse>();
    final model = _Model((r, n) => n == 1 ? late.future : textResponse('新的结果'));
    final ai = await create(model);
    await expectLater(ai.analyze('超时来源'), throwsA(isA<TimeoutException>()));
    expect(model.tokens.first.deadlineExceeded, isTrue);
    late.complete(textResponse('过期结果'));
    expect(await ai.analyze('新的来源'), '新的结果');
  });

  test('按需分析仅归属当前主会话，停止后取消并拒绝脱离会话发起', () async {
    final main = Completer<ModelResponse>();
    final analysis = Completer<ModelResponse>();
    final model = _Model(
      (r, n) => r.purpose == ModelRequestPurpose.summary
          ? analysis.future
          : main.future,
    );
    final ai = await create(model);
    await expectLater(
      ai.analyzeOnDemand('无主会话'),
      throwsA(isA<AnalysisInterrupted>()),
    );
    final sending = ai.send('先查看这张图');
    await waitFor(() => model.requests.isNotEmpty);
    final reading = expectLater(
      ai.analyzeOnDemand('图的来源'),
      throwsA(isA<AnalysisInterrupted>()),
    );
    await waitFor(() => model.requests.length == 2);
    ai.stop();
    await reading;
    await sending;
    expect(model.tokens.last.isCancelled, isTrue);
    main.complete(textResponse('迟到主回答'));
    analysis.complete(textResponse('迟到分析'));
  });

  test('按需分析在主会话中正常返回独立来源结果', () async {
    final main = Completer<ModelResponse>();
    final model = _Model(
      (r, n) => r.purpose == ModelRequestPurpose.summary
          ? textResponse('图中内容')
          : main.future,
    );
    final ai = await create(model);
    final sending = ai.send('分析这张图');
    await waitFor(() => model.requests.isNotEmpty);
    expect(await ai.analyzeOnDemand('来源'), '图中内容');
    main.complete(textResponse('完成'));
    await sending;
  });

  test('连接检查有界、无工具和会话写入，空正文给成功回执', () async {
    final model = _Model((r, n) => textResponse('  '));
    final ai = await create(model);
    expect(await ai.testConnection(), '连接成功，模型已返回响应');
    expect(model.requests.single.maxOutputTokens, 64);
    expect(model.requests.single.tools, isEmpty);
    expect(await db.select(db.assistantSessions).get(), isEmpty);
  });

  test('连接检查超时和关闭会取消等待，不接受迟到结果', () async {
    final first = Completer<ModelResponse>();
    final second = Completer<ModelResponse>();
    final model = _Model((r, n) => n == 1 ? first.future : second.future);
    final ai = await create(model);
    await expectLater(ai.testConnection(), throwsA(isA<TimeoutException>()));
    first.complete(textResponse('迟到连接'));
    final pending = expectLater(
      ai.testConnection(),
      throwsA(isA<AgentCancelled>()),
    );
    await waitFor(() => model.requests.length == 2);
    await ai.close();
    await pending;
    second.completeError(StateError('关闭后的响应'));
    await Future<void>.delayed(Duration.zero);
  });

  test('连续点击新会话与空输入零持久化，首条消息才创建且双发不重复创建', () async {
    final first = Completer<ModelResponse>();
    final model = _Model((r, n) => n == 1 ? first.future : textResponse('第二轮'));
    final ai = await create(model);
    for (var i = 0; i < 25; i++) {
      await ai.startNewSession();
    }
    expect(ai.currentSessionId, isNull);
    expect(ai.conversations, isEmpty);
    await expectLater(ai.send('  '), throwsArgumentError);
    await expectLater(
      ai.sendMessage(UserMessage(text: '  ')),
      throwsArgumentError,
    );
    expect(await db.select(db.assistantSessions).get(), isEmpty);
    final sending = ai.send('第一条有效消息');
    expect(await ai.send('重复点击'), isNull);
    await waitFor(() => model.requests.isNotEmpty);
    expect(await db.select(db.assistantSessions).get(), hasLength(1));
    first.complete(textResponse('第一轮'));
    await sending;
    final original = ai.currentSessionId;
    await ai.startNewSession();
    expect(ai.currentSessionId, isNull);
    expect(ai.transcript, isEmpty);
    expect(ai.conversations, hasLength(1));
    await ai.send('另一段讨论');
    expect(ai.currentSessionId, isNot(original));
    expect(ai.conversations, hasLength(2));
  });

  test('对象入口先显示独立草稿，发送时关联原任务且不污染全局输入', () async {
    final ai = await create(_Model((r, n) => textResponse('继续')));
    ai.draft = '全局还没发的输入';
    await missions.create(
      title: '已有任务',
      scheduledDate: '2030-01-01',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
    );
    final id = (await missions.findAllDetails()).single.mission.id;
    await ai.openMissionReference(id);
    expect(ai.currentSessionId, isNull);
    expect(ai.draft, isEmpty);
    ai.draft = '任务还没发的输入';
    await ai.openGlobalConversation();
    expect(ai.draft, '全局还没发的输入');
    expect(await db.select(db.assistantSessions).get(), isEmpty);
    await ai.openMissionReference(id);
    expect(ai.draft, '任务还没发的输入');
    await ai.send('查看这个任务');
    expect((await db.select(db.assistantSessions).get()).single.missionId, id);
    expect(ai.conversations, hasLength(1));
  });

  test('首条输入被能力预检拒绝会清理空壳，已保存用户消息的模型失败保留历史', () async {
    final ai = await create(
      _Model((r, n) => throw StateError('模型失败')),
      supportsImages: false,
    );
    await ai.sendMessage(
      UserMessage.withContent(
        content: [ImageBlock(url: 'data:image/png;base64,AA==')],
      ),
    );
    expect(ai.currentSessionId, isNull);
    expect(await db.select(db.assistantSessions).get(), isEmpty);
    await ai.send('这条用户消息应保存');
    expect(ai.transcript.whereType<UserMessage>().single.text, '这条用户消息应保存');
    expect(await db.select(db.assistantSessions).get(), hasLength(1));
  });

  test('升级提示词进入新会话和历史恢复，讨论与执行及事实边界保持明确', () async {
    final model = _Model((r, n) => textResponse('收到'));
    final ai = await create(model);
    await ai.send('我们先讨论如何安排');
    final id = ai.currentSessionId;
    await ai.close();
    final restored = await create(model);
    expect(restored.currentSessionId, id);
    await restored.send('继续刚才的讨论');
    final prompt = model.requests.last.systemPrompt;
    expect(prompt, contains('用户在讨论、举例'));
    expect(prompt, contains('工具提交成功前不得声称'));
    expect(prompt, contains('STOP 只表示到点停止计时'));
    expect(prompt, contains('角色和风格只调整称呼'));
    expect(restored.transcript.whereType<UserMessage>(), hasLength(2));
  });
}
