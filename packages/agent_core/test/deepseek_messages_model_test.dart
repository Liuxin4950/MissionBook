import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('HTTP 适配与循环贯通：发送工具 Schema，回传一批匹配的结果，保留思考签名', () async {
    final requests = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://api.deepseek.com/anthropic/v1/messages',
      );
      expect(request.followRedirects, isFalse);
      expect(request.headers['x-api-key'], 'test-key');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      expect(body['stream'], isFalse);
      expect(body['thinking'], {'type': 'disabled'});
      expect(body['system'], '读取时间后回答');
      expect(body['tools'], [
        {
          'name': 'clock',
          'description': '读取时间',
          'input_schema': {'type': 'object', 'additionalProperties': false},
        },
      ]);
      if (requests.length == 1) {
        expect(body['messages'], [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': '现在几点'},
            ],
          },
        ]);
        return _response([
          {
            'type': 'thinking',
            'thinking': '先查时间',
            'signature': 'provider-signature',
          },
          {
            'type': 'tool_use',
            'id': 'clock-1',
            'name': 'clock',
            'input': <String, Object?>{},
          },
          {
            'type': 'tool_use',
            'id': 'clock-2',
            'name': 'clock',
            'input': <String, Object?>{},
          },
        ], reason: 'tool_use');
      }
      final history = body['messages'] as List<dynamic>;
      expect(history, hasLength(3));
      expect((history[1] as Map<String, dynamic>)['content'], [
        {
          'type': 'thinking',
          'thinking': '先查时间',
          'signature': 'provider-signature',
        },
        {
          'type': 'tool_use',
          'id': 'clock-1',
          'name': 'clock',
          'input': <String, Object?>{},
        },
        {
          'type': 'tool_use',
          'id': 'clock-2',
          'name': 'clock',
          'input': <String, Object?>{},
        },
      ]);
      expect(history[2], {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': 'clock-1',
            'content': [
              {'type': 'text', 'text': '13:00'},
            ],
            'is_error': false,
          },
          {
            'type': 'tool_result',
            'tool_use_id': 'clock-2',
            'content': [
              {'type': 'text', 'text': '13:00'},
            ],
            'is_error': false,
          },
        ],
      });
      return _response([
        {'type': 'text', 'text': '现在是十三点'},
      ]);
    });
    final model = DeepSeekMessagesModel(apiKey: 'test-key', client: client);
    final agent = AgentLoop(
      model: model,
      systemPrompt: '读取时间后回答',
      tools: [
        AgentTool(
          definition: ToolDefinition(
            name: 'clock',
            description: '读取时间',
            inputSchema: {'type': 'object', 'additionalProperties': false},
          ),
          execute: (input, context) => const ToolOutput.success('13:00'),
        ),
      ],
      authorize: (tool, call, token) => const ToolDecision.allow(),
    );
    final result = await agent.run(input: '现在几点');
    expect(result.answer, '现在是十三点');
    expect(requests, hasLength(2));
    await agent.close();
    model.close();
    client.close();
  });

  test('HTTP 错误保留状态码，错误消息不包含 Key 或服务端原始响应', () async {
    final client = MockClient(
      (request) async => http.Response('test-key-sensitive', 401),
    );
    final model = DeepSeekMessagesModel(apiKey: 'test-key', client: client);
    await expectLater(
      model.complete(_request(), CancellationToken()),
      throwsA(
        isA<ModelException>()
            .having((error) => error.statusCode, 'status', 401)
            .having(
              (error) => error.message,
              'message',
              isNot(contains('test-key')),
            ),
      ),
    );
    client.close();
  });

  final malformed = <String, String>{
    '非 JSON': 'upstream unavailable',
    '非对象': '[]',
    '缺少字段': '{}',
    '未知内容块': jsonEncode(
      _body([
        {'type': 'future-block'},
      ]),
    ),
    '工具输入不是对象': jsonEncode(
      _body([
        {'type': 'tool_use', 'id': 'a', 'name': 'clock', 'input': []},
      ], reason: 'tool_use'),
    ),
    '未知结束原因': jsonEncode(
      _body([
        {'type': 'text', 'text': 'abc'},
      ], reason: 'future-stop'),
    ),
  };
  for (final entry in malformed.entries) {
    test('${entry.key}不会被静默当成正常回答', () async {
      final client = MockClient(
        (request) async => http.Response(entry.value, 200),
      );
      final model = DeepSeekMessagesModel(apiKey: 'test-key', client: client);
      await expectLater(
        model.complete(_request(), CancellationToken()),
        throwsA(
          isA<ModelException>().having(
            (error) => error.code,
            'code',
            'invalid_response',
          ),
        ),
      );
      client.close();
    });
  }

  test('取消通过 AbortableRequest 通知 HTTP 客户端，并结束等待', () async {
    final client = _WaitingClient();
    final model = DeepSeekMessagesModel(apiKey: 'test-key', client: client);
    final token = CancellationToken();
    final response = model.complete(_request(), token);
    await client.entered.future;
    token.cancel();
    await expectLater(response, throwsA(isA<AgentCancelled>()));
    await client.aborted.future.timeout(const Duration(seconds: 1));
    expect(client.closed, isFalse);
    model.close();
    expect(client.closed, isFalse); // 注入客户端的生命周期属于调用者。
    client.close();
  });

  test('超时也中止 HTTP 请求', () async {
    final client = _WaitingClient();
    final model = DeepSeekMessagesModel(
      apiKey: 'test-key',
      client: client,
      requestTimeout: const Duration(milliseconds: 30),
    );
    await expectLater(
      model.complete(_request(), CancellationToken()),
      throwsA(
        isA<ModelException>().having((error) => error.code, 'code', 'timeout'),
      ),
    );
    await client.aborted.future.timeout(const Duration(seconds: 1));
    client.close();
  });

  test('收到响应头但响应体一直不结束，也受同一个超时限制', () async {
    final body = StreamController<List<int>>();
    final client = MockClient.streaming((request, stream) async {
      await stream.drain<void>();
      return http.StreamedResponse(body.stream, 200);
    });
    final model = DeepSeekMessagesModel(
      apiKey: 'test-key',
      client: client,
      requestTimeout: const Duration(milliseconds: 30),
    );
    await expectLater(
      model.complete(_request(), CancellationToken()),
      throwsA(
        isA<ModelException>().having((error) => error.code, 'code', 'timeout'),
      ),
    );
    await body.close();
    client.close();
  });

  test('错误历史在发送前被拒绝', () async {
    var sent = false;
    final client = MockClient((request) async {
      sent = true;
      return _response([
        {'type': 'text', 'text': '不应请求'},
      ]);
    });
    final model = DeepSeekMessagesModel(apiKey: 'test-key', client: client);
    final request = ModelRequest(
      systemPrompt: '',
      tools: [],
      messages: [
        ToolResultMessage(
          toolCallId: 'missing',
          toolName: 'clock',
          text: '13:00',
        ),
      ],
    );
    await expectLater(
      model.complete(request, CancellationToken()),
      throwsA(
        isA<ModelException>().having(
          (error) => error.code,
          'code',
          'invalid_history',
        ),
      ),
    );
    expect(sent, isFalse);
    client.close();
  });
}

ModelRequest _request() => ModelRequest(
  systemPrompt: '',
  messages: [UserMessage(text: '你好')],
  tools: [],
);

Map<String, Object?> _body(
  List<Map<String, Object?>> blocks, {
  String reason = 'end_turn',
}) => {
  'id': 'msg_test',
  'type': 'message',
  'role': 'assistant',
  'model': 'deepseek-flash',
  'content': blocks,
  'stop_reason': reason,
};

http.Response _response(
  List<Map<String, Object?>> blocks, {
  String reason = 'end_turn',
}) {
  return http.Response(
    jsonEncode(_body(blocks, reason: reason)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

final class _WaitingClient extends http.BaseClient {
  final entered = Completer<void>();
  final aborted = Completer<void>();
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    entered.complete();
    final abortable = request as http.AbortableRequest;
    await abortable.abortTrigger;
    aborted.complete();
    throw http.RequestAbortedException(request.url);
  }

  @override
  void close() => closed = true;
}
