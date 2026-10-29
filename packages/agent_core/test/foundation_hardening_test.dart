import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:agent_core/src/models/request_runner.dart';
import 'package:agent_core/src/models/sse_reader.dart';
import 'package:agent_core/src/models/stream_decoder.dart';
import 'package:agent_core/src/models/wire_codec.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
  test('省略不可回传的纯思考消息，不向供应商发送空 assistant 内容', () {
    final profiles = AgentConfiguration.deepSeek();
    final reasoning = AssistantMessage(
      provider: 'deepseek',
      model: 'deepseek-flash',
      content: [const ThinkingBlock(text: '尚在分析')],
    );
    final history = [UserMessage(text: '问题'), reasoning];
    final request = _request(history);
    final chat = encodeModelRequest(
      profiles.profile('deepseek-chat'),
      request,
      stream: false,
    );
    expect(chat['messages'], hasLength(1));
    expect(history, hasLength(2)); // 只转换发送内容，不删除原始思考。
    final messages = encodeModelRequest(
      profiles.profile('deepseek'),
      request,
      stream: false,
    );
    expect(messages['messages'], hasLength(2)); // 同模型 Messages 仍保留有效思考块。
    final switched = encodeModelRequest(
      testProfile('other'),
      request,
      stream: false,
    );
    expect(switched['messages'], hasLength(1)); // 不把别的模型思考变成空消息。
  });

  test('两协议的输入用量统一为含缓存的总量，缓存不重复计入', () {
    final messages = decodeUsage(ModelProtocol.messages, {
      'input_tokens': 185,
      'cache_read_input_tokens': 4224,
      'cache_creation_input_tokens': 12,
      'output_tokens': 1,
    });
    final chat = decodeUsage(ModelProtocol.chatCompletions, {
      'prompt_tokens': 4421,
      'prompt_tokens_details': {'cached_tokens': 4224},
      'completion_tokens': 1,
    });
    expect(messages.inputTokens, 4421);
    expect(messages.cachedInputTokens, 4224);
    expect(chat.toJson(), messages.toJson());
    expect((chat + messages).inputTokens, 8842);
    expect(
      decodeUsage(ModelProtocol.chatCompletions, {
        'prompt_tokens': 100,
        'prompt_cache_hit_tokens': 80,
        'prompt_tokens_details': {'cached_tokens': 80},
      }).cachedInputTokens,
      80,
    );
  });

  test('只返回思考时保存原文和用量，重开后可以继续生成正文', () async {
    var requests = 0;
    final runtime = testRuntime(
      main: (request, token) {
        if (requests++ == 0) {
          return ModelResponse(
            message: AssistantMessage(
              provider: 'test',
              model: 'test-model',
              content: [const ThinkingBlock(text: '尚在分析')],
            ),
            stopReason: ModelStopReason.completed,
            usage: const TokenUsage(inputTokens: 50, outputTokens: 20),
          );
        }
        expect(request.messages.last.content.single, isA<ThinkingBlock>());
        return textReply('完整回答');
      },
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession(id: 'thinking-only');
    final first = await session.send('问题');
    expect(first.reason, AgentStopReason.failed);
    expect(first.failure?.code, 'empty_answer');
    expect(first.usage.outputTokens, 20);
    expect(session.transcript.last.content.single, isA<ThinkingBlock>());
    await session.close();
    final reopened = await runtime.openSession('thinking-only');
    final resumed = await reopened.resume();
    expect(resumed.reason, AgentStopReason.completed);
    expect(resumed.answer, '完整回答');
    expect(reopened.transcript.whereType<UserMessage>(), hasLength(1));
  });

  test('不支持的图片在写入前拒绝，会话仍能正常对话', () async {
    final profile = ModelProfile.fromJson({
      ...testProfile('main').toJson(),
      'supportsImages': false,
    });
    final runtime = AgentRuntime(
      configuration: AgentConfiguration(
        profiles: [profile],
        defaultModelProfile: 'main',
      ),
      store: MemorySessionStore(),
      credentials: (_) => null,
      tools: [],
      authorize: (tool, call, token) => const ToolDecision.allow(),
      modelOverrides: {
        'main': CallbackModel((request, token) => textReply('正常回答')),
      },
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession();
    final count = session.recordCount;
    await expectLater(
      session.sendMessage(
        UserMessage.withContent(
          content: [ImageBlock(url: 'https://example.invalid/a.png')],
        ),
      ),
      throwsA(
        isA<ModelException>().having(
          (error) => error.code,
          'code',
          'unsupported_images',
        ),
      ),
    );
    expect(session.recordCount, count);
    expect(session.transcript, isEmpty);
    expect((await session.send('普通问题')).reason, AgentStopReason.completed);
  });

  test('生成设置用于实际请求，单独换摘要模型不重置主模型设置', () async {
    final runtime = AgentRuntime(
      configuration: AgentConfiguration(
        profiles: [
          testProfile('main', protocol: ModelProtocol.chatCompletions),
          testProfile('summary'),
        ],
        defaultModelProfile: 'main',
      ),
      store: MemorySessionStore(),
      credentials: (_) => null,
      tools: [],
      authorize: (tool, call, token) => const ToolDecision.allow(),
      modelOverrides: {
        'main': CallbackModel((request, token) {
          expect(request.jsonOutput, true);
          expect(request.maxOutputTokens, 1024);
          expect(request.reasoningEffort, ReasoningEffort.low);
          expect(request.systemPrompt, contains('JSON'));
          return textReply('{"ok":true}');
        }),
      },
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession();
    await session.configureGeneration(
      maxOutputTokens: 1024,
      thinking: ReasoningEffort.low,
      jsonOutput: true,
    );
    await session.selectModels(summary: 'summary');
    expect((await session.send('返回结果')).answer, '{"ok":true}');
  });

  test('业务明确拒绝与只读异常均可回传模型，写入未知异常仍拦截', () async {
    for (final readOnly in [false, true]) {
      var requests = 0;
      final runtime = testRuntime(
        main: (request, token) =>
            ++requests == 1 ? toolReply('a') : textReply('已处理失败'),
        tools: [
          AgentTool(
            definition: readTool(
              (input, context) => const ToolOutput.success(''),
            ).definition,
            readOnly: readOnly,
            execute: (input, context) {
              if (readOnly) throw StateError('只读查询失败');
              throw const ToolRejected('conflict', '数据库事务已回滚');
            },
          ),
        ],
      );
      addTearDown(runtime.close);
      final session = await runtime.createSession();
      expect((await session.send('执行')).reason, AgentStopReason.completed);
      expect(session.needsOutcomeResolution, false);
      expect(
        session.transcript.whereType<ToolResultMessage>().single.errorCode,
        readOnly ? 'tool_failed' : 'conflict',
      );
    }
  });

  test('写入后抛取消必须标记未知，核对使用结构化结果且不改原始事实', () async {
    var effects = 0;
    String? key;
    final runtime = testRuntime(
      main: (request, token) => toolReply('write'),
      tools: [
        readTool((input, context) {
          effects++;
          key = context.idempotencyKey;
          context.cancellation.cancel();
          context.cancellation.throwIfCancelled();
          return const ToolOutput.success('unreachable');
        }),
      ],
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession(id: 'business');
    expect((await session.send('写入')).failure?.code, 'tool_outcome_unknown');
    expect(effects, 1);
    expect(key, 'business:write');
    expect(session.needsOutcomeResolution, true);
    await expectLater(session.send('继续'), throwsStateError);
    await session.resolveToolOutcome(
      'write',
      const ToolOutput.success('已提交'),
      source: '按幂等键查库',
    );
    expect(session.needsOutcomeResolution, false);
    expect(session.resolvedOutcomes['write']!.text, '已提交');
    expect(
      session.transcript.whereType<ToolResultMessage>().single.errorCode,
      'outcome_unknown',
    );
  });

  test('整轮期限可终止不返回的模型；不返回的写工具必须核对', () async {
    for (final toolHangs in [false, true]) {
      final loop = AgentLoop(
        model: CallbackModel(
          (request, token) =>
              toolHangs ? toolReply('hang') : Completer<ModelResponse>().future,
        ),
        systemPrompt: '',
        tools: [readTool((input, context) => Completer<ToolOutput>().future)],
        authorize: (tool, call, token) => const ToolDecision.allow(),
        maxRunDuration: const Duration(milliseconds: 35),
      );
      addTearDown(loop.close);
      final result = await loop
          .run(input: '执行')
          .timeout(const Duration(seconds: 2));
      expect(result.reason, AgentStopReason.failed);
      expect(
        result.failure?.code,
        toolHangs ? 'tool_outcome_unknown' : 'turn_timeout',
      );
    }
  });

  test('触发线与硬预算分开，摘要低于硬预算即可接受', () async {
    final engine = ContextCompactor(
      policy: ContextPolicy(),
      conversationProfile: testProfile('main', window: 64000, output: 2048),
      summaryProfile: testProfile('summary'),
      summaryModel: CallbackModel((request, token) => textReply('摘要')),
      estimator: const _BudgetEstimator(),
    );
    final result = await engine.prepare(
      _request([
        UserMessage(text: '旧内容'),
        textReply('记录').message,
        UserMessage(text: '当前要求'),
      ]),
      CancellationToken(),
    );
    expect(result!.afterTokens, 55000);
    expect(result.afterTokens, greaterThan(engine.triggerLimit));
    expect(result.afterTokens, lessThan(engine.inputLimit));
  });

  test('图片以视觉块进入摘要，base64 不进入文字 token 估算', () async {
    final profile = AgentConfiguration.deepSeek().profile('deepseek-chat');
    final small = ImageBlock(url: 'data:image/png;base64,${'QUJD' * 2}');
    final large = ImageBlock(url: 'data:image/png;base64,${'QUJD' * 20000}');
    final meter = const ApproximateTokenEstimator();
    int count(ImageBlock image) => meter.estimate(
      profile,
      _request([
        UserMessage.withContent(content: [image]),
      ]),
    );
    expect(count(small), count(large));
    ModelRequest? summaryRequest;
    final engine = ContextCompactor(
      policy: ContextPolicy(keepRecentMessages: 1),
      conversationProfile: profile,
      summaryProfile: profile,
      summaryModel: CallbackModel((request, token) {
        summaryRequest = request;
        return textReply('图中文字：测试');
      }),
    );
    await engine.prepare(
      _request([
        UserMessage.withContent(content: [large]),
        UserMessage(text: '继续'),
      ]),
      CancellationToken(),
      trigger: CompactionTrigger.manual,
    );
    expect(
      summaryRequest!.messages
          .expand((message) => message.content)
          .whereType<ImageBlock>(),
      hasLength(1),
    );
    expect(
      summaryRequest!.messages.map((message) => message.text).join(),
      isNot(contains('QUJD')),
    );
  });

  test('兼容重复相同 id 和缺 function 的增量，但拒绝同一索引换 id', () async {
    for (final headerOnly in [false, true]) {
      final frames = [
        _chat({
          'tool_calls': [
            {
              'index': 0,
              'id': 'a',
              if (!headerOnly) 'function': {'name': 'read', 'arguments': ''},
            },
          ],
        }),
        _chat({
          'tool_calls': [
            {
              'index': 0,
              'id': 'a',
              'function': {'name': 'read', 'arguments': '{}'},
            },
          ],
        }),
        _chat({}, finish: 'tool_calls'),
        const ServerSentEvent(null, '[DONE]'),
      ];
      final events = await decodeChatStream(
        testProfile('chat', protocol: ModelProtocol.chatCompletions),
        Stream.fromIterable(frames),
      ).toList();
      expect(
        (events.last as ModelCompleted).response.message.toolCalls.single.id,
        'a',
      );
    }
    await expectLater(
      decodeChatStream(
        testProfile('chat', protocol: ModelProtocol.chatCompletions),
        Stream.fromIterable([
          _chat({
            'tool_calls': [
              {'index': 0, 'id': 'a'},
            ],
          }),
          _chat({
            'tool_calls': [
              {'index': 0, 'id': 'b'},
            ],
          }),
        ]),
      ).toList(),
      throwsFormatException,
    );
  });

  test('Retry-After 可超过本地退避上限，取消不继续请求', () async {
    final token = CancellationToken();
    Duration? scheduled;
    final runner = ModelRequestRunner(
      model: CallbackModel(
        (request, token) => throw const ModelException(
          'rate_limit',
          '限流',
          retryable: true,
          retryAfter: Duration(seconds: 60),
        ),
      ),
      retry: RetryPolicy(),
    );
    await expectLater(
      runner.run(
        _request([UserMessage(text: '问题')]),
        token,
        onEvent: (event) {
          if (event is ModelAttemptFailed) {
            scheduled = event.delay;
            token.cancel();
          }
        },
      ),
      throwsA(isA<AgentCancelled>()),
    );
    expect(scheduled, const Duration(seconds: 60));
  });

  test('持续心跳和凭据等待都受到请求总时长约束', () async {
    for (final waitingKey in [false, true]) {
      final profile = ModelProfile.fromJson({
        ...testProfile(
          'timed',
          protocol: ModelProtocol.chatCompletions,
        ).toJson(),
        'requestTimeoutMs': 2000,
        'totalRequestTimeoutMs': 70,
      });
      final client = MockClient.streaming((request, body) async {
        await body.drain<void>();
        return http.StreamedResponse(
          Stream.periodic(
            const Duration(milliseconds: 5),
            (_) => utf8.encode(': keepalive\n\n'),
          ),
          200,
        );
      });
      final model = HttpAgentModel(
        profile: profile,
        credentials: (_) => waitingKey ? Completer<String?>().future : 'test',
        client: client,
      );
      addTearDown(() {
        model.close();
        client.close();
      });
      await expectLater(
        model.complete(
          _request([UserMessage(text: '问题')]),
          CancellationToken(),
        ),
        throwsA(
          isA<ModelException>().having(
            (error) => error.code,
            'code',
            'request_timeout',
          ),
        ),
      );
    }
  });

  test('断流前已报告用量计入重试总数，且声明可能有未报告用量', () async {
    final loop = AgentLoop(
      model: _RetryUsageModel(),
      systemPrompt: '',
      tools: [],
      retry: RetryPolicy(initialDelay: Duration.zero, maxDelay: Duration.zero),
      authorize: (tool, call, token) => const ToolDecision.allow(),
    );
    addTearDown(loop.close);
    final result = await loop.run(input: '问题');
    expect(result.reason, AgentStopReason.completed);
    expect(result.modelAttempts, 2);
    expect(result.usage.inputTokens, 17);
    expect(result.usage.outputTokens, 5);
    expect(result.usageIncomplete, true);
  });

  test('页面晚订阅仍可读取已经到达的文字快照', () async {
    final model = _PausedModel();
    final runtime = AgentRuntime(
      configuration: testConfiguration(),
      store: MemorySessionStore(),
      credentials: (_) => null,
      tools: [],
      authorize: (tool, call, token) => const ToolDecision.allow(),
      modelOverrides: {'main': model},
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession();
    final first = Completer<void>();
    final subscription = session.events.listen((event) {
      if (event is ModelStreamUpdated &&
          event.update is ModelTextDelta &&
          !first.isCompleted) {
        first.complete();
      }
    });
    final pending = session.send('问题');
    await first.future;
    await subscription.cancel();
    expect(session.activity.text, '第一段');
    expect(session.activity.isRunning, true);
    model.release.complete();
    expect((await pending).answer, '第一段后续');
    expect(session.activity.text, '第一段后续');
    expect(session.activity.isRunning, false);
  });

  test('请求说明只保存一次，导入不再内嵌整个历史，生成选项可恢复', () async {
    final runtime = testRuntime();
    addTearDown(runtime.close);
    final session = await runtime.createSession(
      id: 'dedup',
      systemPrompt: '长提示' * 500,
    );
    for (var i = 0; i < 5; i++) {
      await session.send('第 $i 轮');
    }
    final records = await session.readRecords();
    expect(
      records.where((record) => record.type == 'request_spec_saved'),
      hasLength(1),
    );
    expect(
      records
          .where((record) => record.type == 'request_prepared')
          .every(
            (record) =>
                !record.data.containsKey('tools') &&
                record.data.containsKey('specId'),
          ),
      true,
    );
    final imported = await runtime.importSession(
      await session.export(),
      id: 'copy',
    );
    expect(
      (await imported.readRecords()).any(
        (record) => record.type == 'session_imported',
      ),
      false,
    );
    await imported.rename('新名称');
    await imported.configureGeneration(
      maxOutputTokens: 1024,
      thinking: ReasoningEffort.low,
    );
    await imported.close();
    final reopened = await runtime.openSession('copy');
    expect(reopened.title, '新名称');
    expect(reopened.outputTokens, 1024);
    expect(reopened.reasoningEffort, ReasoningEffort.low);
  });

  test('明确可忽略的新诊断记录可跳过，未知业务记录拒绝导入', () async {
    final runtime = testRuntime();
    addTearDown(runtime.close);
    final session = await runtime.createSession(id: 'versioned');
    final exported = await session.export();
    final raw = exported['records'] as List<Object?>;
    Map<String, Object?> next(bool ignorable) => {
      ...exported,
      'records': [
        ...raw,
        SessionRecord(
          sequence: raw.length,
          timestamp: DateTime.now(),
          type: 'future-event',
          version: 2,
          ignorable: ignorable,
          data: {},
        ).toJson(),
      ],
    };
    expect((await runtime.importSession(next(true))).title, '新会话');
    await expectLater(
      runtime.importSession(next(false)),
      throwsFormatException,
    );
  });

  test('分支不能切开多工具组；完整工具边界不重做写入', () async {
    var calls = 0;
    var effects = 0;
    final runtime = testRuntime(
      main: (request, token) {
        if (++calls != 1) return textReply('完成');
        return ModelResponse(
          message: AssistantMessage(
            provider: 'test',
            model: 'test-model',
            content: [
              ToolCallBlock(id: 'a', name: 'read', input: {}),
              ToolCallBlock(id: 'b', name: 'read', input: {}),
            ],
          ),
          stopReason: ModelStopReason.toolUse,
        );
      },
      tools: [
        readTool((input, context) {
          effects++;
          return const ToolOutput.success('已提交');
        }),
      ],
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession();
    await session.send('执行两个动作');
    final results = session.transcript.whereType<ToolResultMessage>().toList();
    await expectLater(
      session.fork(throughMessageId: results.first.id),
      throwsArgumentError,
    );
    final branch = await session.fork(throughMessageId: results.last.id);
    await branch.send('继续');
    expect(effects, 2);
  });
}

ModelRequest _request(List<AgentMessage> messages) =>
    ModelRequest(systemPrompt: '', messages: messages, tools: []);
ServerSentEvent _chat(Map<String, Object?> delta, {String? finish}) =>
    ServerSentEvent(
      null,
      jsonEncode({
        'model': 'test-model',
        'choices': [
          {'index': 0, 'delta': delta, 'finish_reason': finish},
        ],
      }),
    );

final class _BudgetEstimator implements TokenEstimator {
  const _BudgetEstimator();
  @override
  int estimate(ModelProfile profile, ModelRequest request) {
    if (profile.id == 'summary') return 1000;
    if (request.messages.any((message) => message is ContextSummaryMessage) ||
        request.messages.length == 1) {
      return 55000;
    }
    return 80000;
  }
}

final class _RetryUsageModel implements StreamingAgentModel {
  var calls = 0;
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async => textReply('完成');
  @override
  Stream<ModelStreamEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (++calls == 1) {
      yield const ModelUsageSnapshot(
        TokenUsage(inputTokens: 7, outputTokens: 2),
      );
      throw const ModelException('stream_interrupted', '断流', retryable: true);
    }
    yield ModelCompleted(
      ModelResponse(
        message: textReply('完成').message,
        stopReason: ModelStopReason.completed,
        usage: const TokenUsage(inputTokens: 10, outputTokens: 3),
      ),
    );
  }
}

final class _PausedModel implements StreamingAgentModel {
  final release = Completer<void>();
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async => textReply('第一段后续');
  @override
  Stream<ModelStreamEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    yield const ModelTextDelta(0, '第一段');
    await release.future;
    yield const ModelTextDelta(0, '后续');
    yield ModelCompleted(textReply('第一段后续'));
  }
}
