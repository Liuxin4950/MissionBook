import 'dart:convert';

import '../model.dart';
import 'configuration.dart';
import 'http_agent_model.dart';

/// 使用已解析的模型快照取得客户端，按完整配置复用连接池。
final class ModelRegistry {
  ModelRegistry({
    required this.configuration,
    required CredentialResolver credentials,
    Map<String, AgentModel> overrides = const {},
  }) : _credentials = credentials,
       _overrides = Map.unmodifiable(overrides) {
    for (final id in overrides.keys) {
      configuration.profile(id); // 错写配置编号应在启动时立即失败。
    }
  }

  final AgentConfiguration configuration;
  final CredentialResolver _credentials;
  final Map<String, AgentModel> _overrides;
  final Map<String, HttpAgentModel> _clients = {};
  bool _closed = false;

  AgentModel model(ModelProfile profile) {
    if (_closed) throw StateError('模型注册表已关闭');
    return _overrides[profile.id] ??
        _clients.putIfAbsent(
          jsonEncode(profile.toJson()),
          () => HttpAgentModel(profile: profile, credentials: _credentials),
        );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
  }
}
