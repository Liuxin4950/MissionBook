import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
  test('Messages UTF-8 逐字节到达仍正确拼接文字、工具参数、思考签名及使用量', () async {
    final model = _httpModel(_messagesFrames(), bytewise: true);
    final events = await model.stream(_request(), CancellationToken()).toList();
    final response = (events.last as ModelCompleted).response;
    expect(
      events.whereType<ModelTextDelta>().map((delta) => delta.text).join(),
      '你好',
    );
    expect(response.message.text, '你好');
    expect(response.message.toolCalls.single.input, {'n': 1});
    expect(
      response.message.content.whereType<ThinkingBlock>().single.signature,
      'sig',
    );
    expect(response.usage.inputTokens, 12);
    expect(response.usage.outputTokens, 4);
    expect(response.stopReason, ModelStopReason.toolUse);
    model.close();
  });

  test('Chat 流支持交错工具参数和 reasoning_content，必须等 [DONE]', () async {
    final frames = <String>[
      _chat({'role': 'assistant', 'reasoning_content': '先查询'}),
      _chat({
        'tool_calls': [
          {
            'index': 0,
            'id': 'a',
            'function': {'name': 'read', 'arguments': '{"n":'},
          },
        ],
      }),
      _chat({
        'tool_calls': [
          {
            'index': 1,
            'id': 'b',
            'function': {'name': 'read', 'arguments': '{"n":2}'},
          },
        ],
      }),
      _chat({
        'tool_calls': [
          {
            'index': 0,
            'function': {'arguments': '1}'},
          },
        ],
      }),
      _chat(<String, Object?>{}, finish: 'tool_calls'),
      'data: ${jsonEncode({
        'model': 'test-model',
        'choices': <Object?>[],
        'usage': {'prompt_tokens': 20, 'completion_tokens': 8},
      })}\n\n',
      'data: [DONE]\n\n',
    ];
    final model = _httpModel(
      frames.join(),
      protocol: ModelProtocol.chatCompletions,
      bytewise: true,
    );
    final events = await model.stream(_request(), CancellationToken()).toList();
    final response = (events.last as ModelCompleted).response;
    expect(response.message.toolCalls.map((call) => call.id), ['a', 'b']);
    expect(response.message.toolCalls.map((call) => call.input), [
      {'n': 1},
      {'n': 2},
    ]);
    expect(
      response.message.content.whereType<ThinkingBlock>().single.text,
      '先查询',
    );
    expect(response.usage.inputTokens, 20);
    model.close();
  });

  final badStreams = <String, String>{
    '没有 message_stop': _messagesFrames().replaceFirst(
      _event('message_stop', {}),
      '',
    ),
    '重复内容编号': _messagesFrames().replaceFirst(
      _event('content_block_stop', {'index': 0}),
      _event('content_block_start', {
        'index': 0,
        'content_block': {'type': 'text', 'text': ''},
      }),
    ),
    '块未结束': _messagesFrames().replaceFirst(
      _event('content_block_stop', {'index': 2}),
      '',
    ),
    '未知内容块': _messagesFrames().replaceFirst(
      '"type":"text","text":""',
      '"type":"unknown","text":""',
    ),
    '不完整工具参数': _messagesFrames().replaceFirst(
      '"partial_json":"1}"',
      '"partial_json":"1"',
    ),
    '末帧缺少空行': _messagesFrames().trimRight(),
  };
  for (final entry in badStreams.entries) {
    test('${entry.key}不交付完整响应或执行工具', () async {
      final model = _httpModel(entry.value);
      var executed = false;
      final loop = AgentLoop(
        model: model,
        systemPrompt: '',
        retry: RetryPolicy(maxRetries: 0),
        tools: [
          readTool((input, context) {
            executed = true;
            return const ToolOutput.success('不应执行');
          }),
        ],
        authorize: (tool, call, token) => const ToolDecision.allow(),
      );
      final result = await loop.run(input: '请求');
      expect(result.reason, AgentStopReason.failed);
      expect(result.messages.whereType<AssistantMessage>(), isEmpty);
      expect(executed, isFalse);
      await loop.close();
      model.close();
    });
  }

  test('Chat 即使有 finish_reason 也不能把缺少 [DONE] 的断流视为成功', () async {
    final model = _httpModel(
      _chat({'content': '半截'}, finish: 'stop'),
      protocol: ModelProtocol.chatCompletions,
    );
    await expectLater(
      model.complete(_request(), CancellationToken()),
      throwsA(
        isA<ModelException>().having(
          (error) => error.code,
          'code',
          'stream_interrupted',
        ),
      ),
    );
    model.close();
  });

  test('被 max_tokens 截断的工具参数不会执行', () async {
    final frames = _messagesFrames()
        .replaceFirst('"partial_json":"1}"', '"partial_json":"1"')
        .replaceFirst('"stop_reason":"tool_use"', '"stop_reason":"max_tokens"');
    final model = _httpModel(frames);
    final response = await model.complete(_request(), CancellationToken());
    expect(response.stopReason, ModelStopReason.maxTokens);
    expect(response.message.toolCalls, isEmpty);
    model.close();
  });

  test('流中断可有限重试，半截回答只留在失败尝试，不进入正式历史', () async {
    final model = _RetryStreamModel();
    final loop = AgentLoop(
      model: model,
      systemPrompt: '',
      tools: [],
      retry: RetryPolicy(
        maxRetries: 1,
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
      ),
      authorize: (tool, call, token) => const ToolDecision.allow(),
    );
    final events = <AgentEvent>[];
    final result = await loop.run(input: '你好', onEvent: events.add);
    expect(result.answer, '完整回答');
    expect(result.modelSteps, 1);
    expect(result.modelAttempts, 2);
    expect(result.messages.whereType<AssistantMessage>(), hasLength(1));
    expect(events.whereType<ModelAttemptFailed>().single.partialText, '半截');
    await loop.close();
  });

  test('退避等待可以立即取消，不继续重试', () async {
    final entered = Completer<void>();
    final loop = AgentLoop(
      model: CallbackModel(
        (request, token) =>
            throw const ModelException('rate_limit', '限流', retryable: true),
      ),
      systemPrompt: '',
      tools: [],
      retry: RetryPolicy(initialDelay: const Duration(seconds: 10)),
      authorize: (tool, call, token) => const ToolDecision.allow(),
    );
    final running = loop.run(
      input: '你好',
      onEvent: (event) {
        if (event is ModelAttemptFailed) entered.complete();
      },
    );
    await entered.future;
    loop.cancel();
    expect(
      (await running.timeout(const Duration(seconds: 1))).reason,
      AgentStopReason.cancelled,
    );
    await loop.close();
  });

  for (final cancel in [false, true]) {
    test('已收到文字的 HTTP 流${cancel ? '可以取消' : '受后续数据超时限制'}，半截文字不入历史', () async {
      final body = StreamController<List<int>>();
      body.add(utf8.encode(_chat({'content': '半截回答'})));
      final client = MockClient.streaming((request, outgoing) async {
        await outgoing.drain<void>();
        return http.StreamedResponse(body.stream, 200);
      });
      final profile = ModelProfile.fromJson({
        ...testProfile(
          'chat',
          protocol: ModelProtocol.chatCompletions,
        ).toJson(),
        'requestTimeoutMs': cancel ? 10000 : 40,
      });
      final model = HttpAgentModel(
        profile: profile,
        credentials: (_) => 'test-key',
        client: client,
      );
      final loop = AgentLoop(
        model: model,
        systemPrompt: '',
        tools: [],
        retry: RetryPolicy(maxRetries: 0),
        authorize: (tool, call, token) => const ToolDecision.allow(),
      );
      final events = <AgentEvent>[];
      try {
        final result = await loop
            .run(
              input: '回答',
              onEvent: (event) {
                events.add(event);
                if (cancel && event is ModelStreamUpdated) loop.cancel();
              },
            )
            .timeout(const Duration(seconds: 2));
        expect(
          result.reason,
          cancel ? AgentStopReason.cancelled : AgentStopReason.failed,
        );
        if (!cancel) expect(result.failure?.code, 'timeout');
        expect(result.messages.whereType<AssistantMessage>(), isEmpty);
        expect(
          events.whereType<ModelAttemptFailed>().single.partialText,
          '半截回答',
        );
      } finally {
        await loop.close();
        model.close();
        client.close();
        await body.close();
      }
    });
  }

  test('完整 Chat 请求使用 Bearer、工具说明和配对结果，回传思考内容', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer test-key');
      final json = jsonDecode(request.body) as Map<String, dynamic>;
      final messages = json['messages'] as List<dynamic>;
      expect((messages[1] as Map<String, dynamic>)['reasoning_content'], '先读取');
      expect(messages[2], {
        'role': 'tool',
        'tool_call_id': 'a',
        'content': '真实结果',
      });
      expect(json['tools'], hasLength(1));
      return http.Response(
        jsonEncode({
          'model': 'test-model',
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {'role': 'assistant', 'content': '根据结果回答'},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final profile = testProfile(
      'chat',
      stream: false,
      protocol: ModelProtocol.chatCompletions,
    );
    final model = HttpAgentModel(
      profile: profile,
      credentials: (_) => 'test-key',
      client: client,
    );
    final request = ModelRequest(
      systemPrompt: '',
      tools: [
        readTool((input, context) => const ToolOutput.success('')).definition,
      ],
      messages: [
        UserMessage(text: '查询'),
        AssistantMessage(
          provider: 'test',
          model: 'test-model',
          content: [
            const ThinkingBlock(text: '先读取'),
            ToolCallBlock(id: 'a', name: 'read', input: {}),
          ],
        ),
        ToolResultMessage(toolCallId: 'a', toolName: 'read', text: '真实结果'),
      ],
    );
    expect(
      (await model.complete(request, CancellationToken())).message.text,
      '根据结果回答',
    );
    client.close();
  });
}

HttpAgentModel _httpModel(
  String data, {
  ModelProtocol protocol = ModelProtocol.messages,
  bool bytewise = false,
}) {
  final bytes = utf8.encode(data);
  final client = MockClient.streaming((request, body) async {
    await body.drain<void>();
    return http.StreamedResponse(
      bytewise
          ? Stream.fromIterable(bytes.map((byte) => [byte]))
          : Stream.value(bytes),
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  });
  addTearDown(client.close);
  return HttpAgentModel(
    profile: testProfile('stream', protocol: protocol),
    credentials: (_) => 'test-key',
    client: client,
  );
}

ModelRequest _request() => ModelRequest(
  systemPrompt: '',
  messages: [UserMessage(text: '你好')],
  tools: [],
);
String _event(String type, Map<String, Object?> fields) =>
    'event: $type\ndata: ${jsonEncode({'type': type, ...fields})}\n\n';
String _messagesFrames() => [
  ': heartbeat\n\n',
  _event('message_start', {
    'message': {
      'type': 'message',
      'role': 'assistant',
      'model': 'test-model',
      'usage': {'input_tokens': 12},
    },
  }),
  _event('content_block_start', {
    'index': 0,
    'content_block': {'type': 'thinking', 'thinking': ''},
  }),
  _event('content_block_delta', {
    'index': 0,
    'delta': {'type': 'thinking_delta', 'thinking': '思考'},
  }),
  _event('content_block_delta', {
    'index': 0,
    'delta': {'type': 'signature_delta', 'signature': 'sig'},
  }),
  _event('content_block_stop', {'index': 0}),
  _event('content_block_start', {
    'index': 1,
    'content_block': {'type': 'text', 'text': ''},
  }),
  _event('content_block_delta', {
    'index': 1,
    'delta': {'type': 'text_delta', 'text': '你好'},
  }),
  _event('content_block_stop', {'index': 1}),
  _event('content_block_start', {
    'index': 2,
    'content_block': {
      'type': 'tool_use',
      'id': 'a',
      'name': 'read',
      'input': <String, Object?>{},
    },
  }),
  _event('content_block_delta', {
    'index': 2,
    'delta': {'type': 'input_json_delta', 'partial_json': '{"n":'},
  }),
  _event('content_block_delta', {
    'index': 2,
    'delta': {'type': 'input_json_delta', 'partial_json': '1}'},
  }),
  _event('content_block_stop', {'index': 2}),
  _event('message_delta', {
    'delta': {'stop_reason': 'tool_use'},
    'usage': {'output_tokens': 4},
  }),
  _event('message_stop', {}),
].join();

String _chat(Map<String, Object?> delta, {String? finish}) =>
    'data: ${jsonEncode({
      'model': 'test-model',
      'choices': [
        {'index': 0, 'delta': delta, 'finish_reason': finish},
      ],
    })}\n\n';

final class _RetryStreamModel implements StreamingAgentModel {
  int attempts = 0;
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken token,
  ) => throw StateError('应消费流式接口');
  @override
  Stream<ModelStreamEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (++attempts == 1) {
      yield const ModelTextDelta(0, '半截');
      throw const ModelException('stream_interrupted', '中断', retryable: true);
    }
    yield const ModelTextDelta(0, '完整回答');
    yield ModelCompleted(textReply('完整回答'));
  }
}
