import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  test('移除配置后主模型和摘要模型完整使用日志快照执行并记录请求', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final paths = <String>[];
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      paths.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'id': 'response-${paths.length}',
          'model': request.uri.path.substring(1),
          'choices': [
            {
              'message': {'role': 'assistant', 'content': '基于事实的简短回答'},
              'finish_reason': 'stop',
            },
          ],
        }),
      );
      await request.response.close();
    });
    ModelProfile profile(String id) => ModelProfile(
      id: id,
      provider: 'test',
      model: id,
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/$id'),
      protocol: ModelProtocol.chatCompletions,
      credentialKey: 'TEST_KEY',
      requiresCredential: false,
      streamResponses: false,
      contextWindowTokens: 24000,
      maxOutputTokens: 512,
    );
    final store = MemorySessionStore();
    final policy = ContextPolicy(
      headroomTokens: 64,
      keepRecentMessages: 2,
      summaryMaxTokens: 256,
    );
    AgentRuntime runtime(AgentConfiguration config) => AgentRuntime(
      configuration: config,
      store: store,
      credentials: (_) => throw StateError('无 Key 请求不读取凭据'),
      tools: [],
      authorize: (_, _, _) => const ToolDecision.allow(),
    );
    final first = runtime(
      AgentConfiguration(
        profiles: [profile('main'), profile('summary')],
        defaultModelProfile: 'main',
        summaryModelProfile: 'summary',
        context: policy,
      ),
    );
    final session = await first.createSession(id: 'snapshot-history');
    expect((await session.send('第一轮讨论')).reason, AgentStopReason.completed);
    await first.close();
    final restored = runtime(
      AgentConfiguration(
        profiles: [profile('other')],
        defaultModelProfile: 'other',
        summaryModelProfile: 'other',
        context: policy,
      ),
    );
    addTearDown(restored.close);
    final reopened = await restored.openSession('snapshot-history');
    expect((await reopened.send('第二轮讨论')).reason, AgentStopReason.completed);
    expect(await reopened.compact(), isNotNull);
    expect(paths, ['/main', '/main', '/summary']);
    final specs = (await reopened.readRecords()).where(
      (r) => r.type == 'request_spec_saved',
    );
    expect(
      specs.map((r) => (r.data['profile'] as Map)['id']),
      containsAll(['main', 'summary']),
    );
    expect(reopened.modelProfileId, 'main');
    expect(reopened.summaryProfileId, 'summary');
  });
}
