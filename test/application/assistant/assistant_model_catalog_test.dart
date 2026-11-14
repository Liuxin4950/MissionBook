import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mission_book/application/assistant/assistant_model_catalog.dart';

void main() {
  for (final protocol in ModelProtocol.values) {
    test('分页合并去重并使用${protocol.name}游标', () async {
      var calls = 0;
      final catalog = AssistantModelCatalog(
        clientFactory: () => MockClient((request) async {
          calls++;
          if (calls == 1) {
            return http.Response(
              '{"data":[{"id":"b"}],"has_more":true,"last_id":"b"}',
              200,
            );
          }
          expect(
            request.url.queryParameters[protocol == ModelProtocol.messages
                ? 'after_id'
                : 'after'],
            'b',
          );
          return http.Response(
            '{"data":[{"id":"a"},{"id":"b"}],"has_more":false}',
            200,
          );
        }),
      );
      expect(
        await catalog.fetch(
          address: 'https://example.invalid/v1',
          protocol: protocol,
          credential: '',
        ),
        ['a', 'b'],
      );
      expect(calls, 2);
    });
  }
  test('分页重复游标与中途失败不会把部分列表报告为成功', () async {
    for (final fails in [true, false]) {
      var calls = 0;
      final catalog = AssistantModelCatalog(
        clientFactory: () => MockClient((_) async {
          calls++;
          if (calls == 2 && fails) return http.Response('', 403);
          return http.Response(
            '{"data":[{"id":"a"}],"has_more":true,"last_id":"a"}',
            200,
          );
        }),
      );
      await expectLater(
        catalog.fetch(
          address: 'https://example.invalid',
          protocol: ModelProtocol.messages,
          credential: '',
        ),
        throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
      );
      expect(calls, 2);
    }
  });
  test('取消获取会关闭客户端且不返回迟到结果', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final token = CancellationToken();
    var closed = false;
    final catalog = AssistantModelCatalog(
      clientFactory: () => _CloseAwareClient((request) {
        started.complete();
        return response.future;
      }, () => closed = true),
    );
    final fetching = catalog.fetch(
      address: 'https://example.invalid',
      protocol: ModelProtocol.messages,
      credential: '',
      cancellation: token,
    );
    final assertion = expectLater(fetching, throwsA(isA<AgentCancelled>()));
    await started.future;
    token.cancel();
    await assertion;
    expect(closed, isTrue);
    response.complete(http.Response('{"data":[{"id":"late"}]}', 200));
  });
  test('已有无版本前缀的完整地址从同级 models 获取列表', () async {
    final catalog = AssistantModelCatalog(
      clientFactory: () => MockClient((request) async {
        expect(request.url.path, '/models');
        return http.Response('{"data":[{"id":"test-model"}]}', 200);
      }),
    );
    expect(
      await catalog.fetch(
        address: 'https://example.invalid/chat/completions',
        protocol: ModelProtocol.chatCompletions,
        credential: '',
      ),
      ['test-model'],
    );
  });
  test('服务根地址、API 前缀和完整请求地址都可获取模型', () async {
    for (final address in [
      'https://example.invalid',
      'https://example.invalid/v1/',
      'https://example.invalid/v1/chat/completions',
      'https://example.invalid/v1/messages',
    ]) {
      final catalog = AssistantModelCatalog(
        clientFactory: () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://example.invalid/v1/models');
          expect(request.headers['Authorization'], 'Bearer draft-key');
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'z-model'},
                {'id': 'a-model'},
                {'id': 'z-model'},
                {'id': ''},
              ],
            }),
            200,
          );
        }),
      );
      expect(
        await catalog.fetch(
          address: address,
          protocol: ModelProtocol.chatCompletions,
          credential: ' draft-key ',
        ),
        ['a-model', 'z-model'],
      );
    }
  });

  test('Messages 使用对应鉴权头且保留自定义路径', () async {
    final catalog = AssistantModelCatalog(
      clientFactory: () => MockClient((request) async {
        expect(request.url.path, '/gateway/v1/models');
        expect(request.headers['x-api-key'], 'saved-key');
        expect(request.headers['anthropic-version'], '2023-06-01');
        return http.Response('{"data":[{"id":"claude-test"}]}', 200);
      }),
    );
    expect(
      await catalog.fetch(
        address: 'https://example.invalid/gateway/v1/messages',
        protocol: ModelProtocol.messages,
        credential: 'saved-key',
      ),
      ['claude-test'],
    );
  });

  test('根地址补全调用路径，已有完整地址保持原值', () {
    expect(
      AssistantModelCatalog.requestEndpoint(
        'https://example.invalid',
        ModelProtocol.chatCompletions,
      ).path,
      '/v1/chat/completions',
    );
    expect(
      AssistantModelCatalog.requestEndpoint(
        'https://example.invalid/proxy/v1',
        ModelProtocol.messages,
      ).path,
      '/proxy/v1/messages',
    );
    expect(
      AssistantModelCatalog.requestEndpoint(
        'https://example.invalid/chat/completions',
        ModelProtocol.chatCompletions,
      ).path,
      '/chat/completions',
    );
  });

  test('拒绝无效地址且不发出请求', () async {
    final catalog = AssistantModelCatalog(
      clientFactory: () => throw StateError('不应请求'),
    );
    for (final address in [
      '',
      'example.invalid',
      'https://key@example.invalid',
      'https://example.invalid?key=secret',
    ]) {
      await expectLater(
        catalog.fetch(
          address: address,
          protocol: ModelProtocol.chatCompletions,
          credential: '',
        ),
        throwsArgumentError,
      );
    }
  });

  test('鉴权、接口缺失、空列表和无效 JSON 提供可操作错误', () async {
    for (final response in [
      http.Response('secret', 401),
      http.Response('secret', 404),
      http.Response('{"data":[]}', 200),
      http.Response('private raw error', 200),
    ]) {
      final catalog = AssistantModelCatalog(
        clientFactory: () => MockClient((_) async => response),
      );
      await expectLater(
        catalog.fetch(
          address: 'https://example.invalid/v1',
          protocol: ModelProtocol.chatCompletions,
          credential: '',
        ),
        throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
      );
    }
  });
}

class _CloseAwareClient extends MockClient {
  _CloseAwareClient(super.fn, this.onClose);
  final void Function() onClose;
  @override
  void close() {
    onClose();
    super.close();
  }
}
