import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cancellation.dart';
import '../model.dart';
import 'configuration.dart';
import 'sse_reader.dart';
import 'stream_decoder.dart';
import 'wire_codec.dart';

typedef CredentialResolver =
    FutureOr<String?> Function(String environmentVariable);

/// 按配置执行 HTTP 请求；协议转换、增量组装与循环控制各自分开。
class HttpAgentModel implements StreamingAgentModel {
  HttpAgentModel({
    required this.profile,
    required CredentialResolver credentials,
    http.Client? client,
  }) : _credentials = credentials,
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final ModelProfile profile;
  final CredentialResolver _credentials;
  final http.Client _client;
  final bool _ownsClient;
  bool _closed = false;

  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    await for (final event in stream(request, cancellation)) {
      if (event is ModelCompleted) return event.response;
    }
    throw const ModelException(
      'stream_interrupted',
      '模型未交付完整响应',
      retryable: true,
    );
  }

  @override
  Stream<ModelStreamEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (_closed) throw StateError('模型客户端已关闭');
    cancellation.throwIfCancelled();
    final Map<String, Object?> body;
    try {
      body = encodeModelRequest(
        profile,
        request,
        stream: profile.streamResponses,
      );
    } on FormatException catch (error) {
      throw ModelException('invalid_history', error.message);
    }
    try {
      final bytes = _requestBytes(body, cancellation);
      if (!profile.streamResponses) {
        final text = await cancellation.wait(utf8.decoder.bind(bytes).join());
        yield ModelCompleted(
          decodeModelResponse(profile, readObject(jsonDecode(text))),
        );
        return;
      }
      final frames = readServerSentEvents(bytes);
      final decoded = profile.protocol == ModelProtocol.messages
          ? decodeMessagesStream(profile, frames)
          : decodeChatStream(profile, frames);
      // await for 让协议错误进入下面的 catch；yield* 会直接把流错误转发给订阅者。
      await for (final event in decoded) {
        yield event;
      }
    } on AgentCancelled {
      rethrow;
    } on ModelException {
      rethrow;
    } on http.RequestAbortedException {
      cancellation.throwIfCancelled();
      throw const ModelException('timeout', '模型请求已中止', retryable: true);
    } on http.ClientException {
      throw const ModelException(
        'transport_error',
        '无法连接模型服务，请检查网络',
        retryable: true,
      );
    } on FormatException {
      throw const ModelException('invalid_response', '模型返回的数据不符合协议');
    } on ArgumentError {
      throw const ModelException('invalid_response', '模型返回了无效内容或工具参数');
    }
  }

  Stream<List<int>> _requestBytes(
    Map<String, Object?> body,
    CancellationToken token,
  ) async* {
    final abort = Completer<void>();
    StreamIterator<List<int>>? iterator;
    try {
      final key = await token.wait(
        Future.sync(() => _credentials(profile.credentialEnvironment)),
      );
      token.throwIfCancelled();
      if (key == null || key.trim().isEmpty) {
        throw ModelException(
          'missing_credentials',
          '请配置凭据环境变量 ${profile.credentialEnvironment}',
        );
      }
      final outgoing =
          http.AbortableRequest(
              'POST',
              profile.endpoint,
              abortTrigger: Future.any<void>([
                abort.future,
                token.whenCancelled,
              ]),
            )
            ..followRedirects = false
            ..headers.addAll({
              'content-type': 'application/json',
              'accept': profile.streamResponses
                  ? 'text/event-stream'
                  : 'application/json',
              if (profile.protocol == ModelProtocol.messages) ...{
                'x-api-key': key,
                'anthropic-version': '2023-06-01',
              } else
                'authorization': 'Bearer $key',
            })
            ..body = jsonEncode(body);
      final response = await _wait(_client.send(outgoing), token, abort);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorBody = await _wait(
          response.stream.bytesToString(),
          token,
          abort,
        );
        throw _httpFailure(response.statusCode, response.headers, errorBody);
      }
      iterator = StreamIterator(response.stream);
      while (await _wait(iterator.moveNext(), token, abort)) {
        yield iterator.current;
      }
    } finally {
      if (!abort.isCompleted) abort.complete();
      // 已发中止信号；不让不配合关闭的替身客户端拖住取消结果。
      final pendingIterator = iterator;
      if (pendingIterator != null) {
        unawaited(
          pendingIterator.cancel().catchError((Object error) {
            // 取消后的流异常已由本次请求的终止状态处理。
          }),
        );
      }
    }
  }

  Future<T> _wait<T>(
    Future<T> pending,
    CancellationToken token,
    Completer<void> abort,
  ) {
    return token
        .wait(pending)
        .timeout(
          profile.requestTimeout,
          onTimeout: () {
            if (!abort.isCompleted) abort.complete();
            throw const ModelException(
              'timeout',
              '等待模型响应超时，请稍后重试',
              retryable: true,
            );
          },
        );
  }

  ModelException _httpFailure(
    int status,
    Map<String, String> headers,
    String body,
  ) {
    try {
      final json = readObject(jsonDecode(body));
      if (json['error'] is Map<String, Object?>) {
        final structured = streamError(json['error']);
        if (structured.code == 'context_overflow') return structured;
      }
    } on FormatException {
      // 网关可能返回 HTML；HTTP 状态仍然有效，不显示原始响应或凭据。
    }
    final retrySeconds = int.tryParse(headers['retry-after'] ?? '');
    final retryAfter = retrySeconds == null || retrySeconds < 0
        ? null
        : Duration(seconds: retrySeconds);
    if (status == 401 || status == 403) {
      return ModelException('http_error', '模型凭据无效或无访问权限', statusCode: status);
    }
    if (status == 402) {
      return ModelException('http_error', '模型服务账户余额不足', statusCode: status);
    }
    if (status == 429) {
      return ModelException(
        'rate_limit',
        '模型请求过于频繁',
        statusCode: status,
        retryable: true,
        retryAfter: retryAfter,
      );
    }
    return ModelException(
      'http_error',
      '模型请求失败（HTTP $status）',
      statusCode: status,
      retryable: status == 408 || status >= 500,
      retryAfter: retryAfter,
    );
  }

  /// 注入的客户端属于调用者；只释放本对象创建的连接池。
  void close() {
    _closed = true;
    if (_ownsClient) _client.close();
  }
}
