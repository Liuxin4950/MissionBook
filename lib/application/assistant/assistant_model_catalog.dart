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
    // 已保存的 DeepSeek Messages 根路径也按官方 API 前缀补全。
    if (uri.host == 'api.deepseek.com' && path == '/anthropic') {
      path = '/anthropic/v1';
    }
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
    CancellationToken? cancellation,
  }) async {
    final base = _baseUri(address);
    final client = clientFactory();
    final token = cancellation ?? CancellationToken();
    try {
      return await token
          .wait(
            _fetchPages(
              client: client,
              endpoint: base.replace(path: '${base.path}/models'),
              protocol: protocol,
              credential: credential.trim(),
              cancellation: token,
            ),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw StateError('获取模型超时，请检查网络后重试');
    } finally {
      token.cancel();
      client.close();
    }
  }

  Future<List<String>> _fetchPages({
    required http.Client client,
    required Uri endpoint,
    required ModelProtocol protocol,
    required String credential,
    required CancellationToken cancellation,
  }) async {
    final ids = <String>{};
    final cursors = <String>{};
    var page = endpoint;
    for (var count = 0; count < 100; count++) {
      cancellation.throwIfCancelled();
      final request = http.Request('GET', page)..followRedirects = false;
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
      })();
      cancellation.throwIfCancelled();
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
      for (final row in rows) {
        final id = row is Map ? row['id'] : row;
        if (id is String && id.trim().isNotEmpty) ids.add(id.trim());
      }
      if (body is! Map || body['has_more'] != true) {
        if (ids.isEmpty) throw StateError('服务返回的模型列表为空，可重试或手动填写模型编号');
        return ids.toList()..sort();
      }
      final cursor = body['last_id'];
      if (cursor is! String || cursor.isEmpty || !cursors.add(cursor)) {
        throw const FormatException('模型列表分页游标缺失或重复，请重试或手动填写模型编号');
      }
      page = endpoint.replace(
        queryParameters: {
          protocol == ModelProtocol.messages ? 'after_id' : 'after': cursor,
        },
      );
    }
    throw StateError('模型列表分页超过 100 页，请缩小服务范围或手动填写模型编号');
  }
}
