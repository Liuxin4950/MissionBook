import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
  test('默认配置两种协议可序列化，摘要模型选择可独立保存', () {
    final config = AgentConfiguration.deepSeek();
    expect(
      AgentConfiguration.fromJson(config.toJson()).toJson(),
      config.toJson(),
    );
    expect(config.profiles.map((profile) => profile.protocol), [
      ModelProtocol.messages,
      ModelProtocol.chatCompletions,
    ]);
    expect(config.summaryModelProfile, config.defaultModelProfile);
  });
  test('不允许未知字段、明文 Key 字段或未知协议静默生效', () {
    final json = AgentConfiguration.deepSeek().toJson();
    expect(
      () =>
          AgentConfiguration.fromJson({...json, 'apiKey': 'never-store-this'}),
      throwsFormatException,
    );
    final profile = testProfile('a').toJson();
    expect(
      () => ModelProfile.fromJson({...profile, 'protocol': 'misspelled'}),
      throwsFormatException,
    );
    expect(
      () => ModelProfile.fromJson({...profile, 'apiKey': 'never-store-this'}),
      throwsFormatException,
    );
    expect(
      () => ModelProfile.fromJson({
        ...profile,
        'credentialEnvironment': 'sk-do-not-store-a-key',
      }),
      throwsArgumentError,
    );
  });
  test('非法预算、地址、重复编号和缺失模型引用在启动时拒绝', () {
    final base = testProfile('a').toJson();
    for (final patch in <Map<String, Object?>>[
      {'maxOutputTokens': 0},
      {'contextWindowTokens': 1},
      {'temperature': 3},
      {'requestTimeoutMs': 0},
      {'endpoint': 'https://name:secret@example.com/path'},
      {'endpoint': 'https://example.com/path?key=secret'},
      {'endpoint': '/relative'},
    ]) {
      expect(
        () => ModelProfile.fromJson({...base, ...patch}),
        throwsArgumentError,
      );
    }
    expect(
      () => AgentConfiguration(
        profiles: [testProfile('a'), testProfile('a')],
        defaultModelProfile: 'a',
      ),
      throwsArgumentError,
    );
    expect(
      () => AgentConfiguration(
        profiles: [testProfile('a')],
        defaultModelProfile: 'missing',
      ),
      throwsArgumentError,
    );
    expect(
      () => AgentConfiguration(
        profiles: [testProfile('a')],
        defaultModelProfile: 'a',
        summaryModelProfile: 'missing',
      ),
      throwsArgumentError,
    );
    expect(
      () => ContextPolicy(targetRatio: 0.9, triggerRatio: 0.8),
      throwsArgumentError,
    );
  });
  test('模型注册表按配置复用对象，关闭后拒绝新请求', () {
    final registry = ModelRegistry(
      configuration: AgentConfiguration.deepSeek(),
      credentials: (_) => null,
    );
    expect(
      identical(registry.model('deepseek'), registry.model('deepseek')),
      isTrue,
    );
    expect(
      identical(registry.model('deepseek'), registry.model('deepseek-chat')),
      isFalse,
    );
    registry.close();
    expect(() => registry.model('deepseek'), throwsStateError);
  });
}
