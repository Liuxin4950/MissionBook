import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:http/http.dart' as http;

/// 从自定义服务读取模型编号，地址可填服务根地址、API 前缀或完整请求地址。
class AssistantModelCatalog {
  const AssistantModelCatalog({this.clientFactory = http.Client.new});

  final http.Client Function() clientFactory;

  static Uri _baseUri(String address) {
    final uri = Uri.tryParse(address.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError('请填写完整 HTTP 服务地址，且不包含账号、查询参数或片段');
    }
    var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.isEmpty) path = '/v1';
    path = path.replaceFirst(
      RegExp(r'/(chat/completions|messages|models)$'),
      '',
    );
    return uri.replace(path: path);
  }

  /// 模型调用仍保存完整请求地址，已有完整地址按原值使用。
  static Uri requestEndpoint(String address, ModelProtocol protocol) {
    final base = _baseUri(address);
    final original = Uri.parse(address.trim());
    if (RegExp(r'/(chat/completions|messages)/?$').hasMatch(original.path)) {
      return original;
    }
    final suffix = protocol == ModelProtocol.messages
        ? 'messages'
        : 'chat/completions';
    return base.replace(path: '${base.path}/$suffix');
  }

  Future<List<String>> fetch({
    required String address,
    required ModelProtocol protocol,
    required String credential,
  }) async {
    final base = _baseUri(address);
    final client = clientFactory();
    try {
      final request = http.Request(
        'GET',
        base.replace(path: '${base.path}/models'),
      )..followRedirects = false;
      request.headers['Accept'] = 'application/json';
      if (credential.trim().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${credential.trim()}';
        if (protocol == ModelProtocol.messages) {
          request.headers['x-api-key'] = credential.trim();
        }
      }
      if (protocol == ModelProtocol.messages) {
        request.headers['anthropic-version'] = '2023-06-01';
      }
      final response = await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(const Duration(seconds: 20));
      switch (response.statusCode) {
        case 200:
          break;
        case 401 || 403:
          throw StateError('获取模型失败，请检查 API Key 和模型列表访问权限');
        case 404 || 405:
          throw StateError('此地址未提供模型列表，请检查服务地址或手动填写模型编号');
        default:
          throw StateError('获取模型失败（HTTP ${response.statusCode}），请稍后重试');
      }
      final Object? body;
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw const FormatException('模型列表格式无效，请检查服务地址');
      }
      final rows = body is Map ? body['data'] : body;
      if (rows is! List) {
        throw const FormatException('服务未返回有效模型列表，可手动填写模型编号');
      }
      final ids = <String>{};
      for (final row in rows) {
        final id = row is Map ? row['id'] : row;
        if (id is String && id.trim().isNotEmpty) ids.add(id.trim());
      }
      if (ids.isEmpty) throw StateError('服务返回的模型列表为空，可重试或手动填写模型编号');
      return ids.toList()..sort();
    } on TimeoutException {
      throw StateError('获取模型超时，请检查网络后重试');
    } finally {
      client.close();
    }
  }
}
