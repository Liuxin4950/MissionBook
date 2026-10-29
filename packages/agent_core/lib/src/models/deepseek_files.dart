import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../cancellation.dart';
import '../content_block.dart';
import '../model.dart';
import 'configuration.dart';
import 'http_agent_model.dart';
import 'image_input.dart';

/// DeepSeek 图片文件接口；上传一次后，后续会话只保存和回传文件编号。
final class DeepSeekFilesClient {
  DeepSeekFilesClient({
    required CredentialResolver credentials,
    this.credentialKey = 'DEEPSEEK_API_KEY',
    Uri? endpoint,
    http.Client? client,
  }) : endpoint = endpoint ?? Uri.parse('https://api.deepseek.com/files'),
       _credentials = credentials,
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final Uri endpoint;
  final String credentialKey;
  final CredentialResolver _credentials;
  final http.Client _client;
  final bool _ownsClient;
  bool _closed = false;

  Future<UploadedImage> upload(
    ImageInput image, {
    CancellationToken? cancellation,
    Duration? lifetime,
  }) async {
    if (lifetime != null &&
        (lifetime.inSeconds < 3600 || lifetime.inSeconds > 2592000)) {
      throw ArgumentError('图片保留时间需要在 1 小时到 30 天之间');
    }
    if (utf8.encode(image.name).length > 512) {
      throw ArgumentError('图片文件名超过 512 字节');
    }
    final json = await _request('POST', endpoint, cancellation, (abort) {
      return http.AbortableMultipartRequest(
          'POST',
          endpoint,
          abortTrigger: abort,
        )
        ..fields.addAll({
          'purpose': 'user_data',
          if (lifetime != null) ...{
            'expires_after[anchor]': 'created_at',
            'expires_after[seconds]': '${lifetime.inSeconds}',
          },
        })
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            image.bytes,
            filename: image.name,
            contentType: MediaType.parse(image.mediaType),
          ),
        );
    });
    final uploaded = UploadedImage.fromJson(json);
    if (uploaded.bytes != image.bytes.length) {
      throw const ModelException('invalid_response', '上传结果的图片大小不匹配');
    }
    return UploadedImage(
      id: uploaded.id,
      name: uploaded.name,
      bytes: uploaded.bytes,
      expiresAt: uploaded.expiresAt,
      width: image.width,
      height: image.height,
    );
  }

  Future<UploadedImage> retrieve(
    String id, {
    CancellationToken? cancellation,
  }) async =>
      UploadedImage.fromJson(await _request('GET', _fileUrl(id), cancellation));

  Future<List<UploadedImage>> list({
    String? after,
    int limit = 50,
    CancellationToken? cancellation,
  }) async {
    if (limit < 1 || limit > 1000) throw ArgumentError('文件分页大小需要在 1 到 1000 之间');
    final parameters = <String, String>{'limit': '$limit'};
    if (after != null) parameters['after'] = after;
    final uri = endpoint.replace(queryParameters: parameters);
    final json = await _request('GET', uri, cancellation);
    final data = json['data'];
    if (data is! List<Object?>) {
      throw const ModelException('invalid_response', '文件列表格式错误');
    }
    return data
        .map((item) => UploadedImage.fromJson(readObject(item)))
        .toList();
  }

  Future<void> delete(String id, {CancellationToken? cancellation}) async {
    final json = await _request('DELETE', _fileUrl(id), cancellation);
    if (json['id'] != id || json['deleted'] != true) {
      throw const ModelException('invalid_response', '未确认图片已删除');
    }
  }

  Uri _fileUrl(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(id)) {
      throw ArgumentError('图片文件编号无效');
    }
    return endpoint.replace(path: '${endpoint.path}/$id');
  }

  Future<Map<String, Object?>> _request(
    String method,
    Uri uri,
    CancellationToken? cancellation, [
    http.BaseRequest Function(Future<void> abort)? build,
  ]) async {
    if (_closed) throw StateError('文件客户端已关闭');
    final token = cancellation ?? CancellationToken();
    final abort = Completer<void>();
    final watch = Stopwatch()..start();
    const timeout = Duration(minutes: 10);
    Future<T> wait<T>(Future<T> operation) => token
        .wait(operation)
        .timeout(
          timeout - watch.elapsed,
          onTimeout: () {
            if (!abort.isCompleted) abort.complete();
            throw const ModelException('timeout', '图片文件请求超时');
          },
        );
    try {
      final key = await wait(Future.sync(() => _credentials(credentialKey)));
      if (key == null || key.trim().isEmpty) {
        throw ModelException('missing_credentials', '请配置凭据 $credentialKey');
      }
      final trigger = Future.any<void>([abort.future, token.whenCancelled]);
      final request =
          build?.call(trigger) ??
          http.AbortableRequest(method, uri, abortTrigger: trigger);
      request.followRedirects = false;
      request.headers['authorization'] = 'Bearer $key';
      final response = await wait(_client.send(request));
      final text = await wait(response.stream.bytesToString());
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ModelException(
          'files_http_error',
          '图片文件接口请求失败（HTTP ${response.statusCode}）',
          statusCode: response.statusCode,
        );
      }
      return readObject(jsonDecode(text));
    } on http.RequestAbortedException {
      token.throwIfCancelled();
      throw const ModelException('timeout', '图片文件请求已中止');
    } on http.ClientException {
      throw const ModelException('transport_error', '无法连接图片文件服务');
    } on FormatException {
      throw const ModelException('invalid_response', '图片文件接口返回格式错误');
    } finally {
      if (!abort.isCompleted) abort.complete();
      watch.stop();
    }
  }

  void close() {
    _closed = true;
    if (_ownsClient) _client.close();
  }
}

final class UploadedImage {
  const UploadedImage({
    required this.id,
    required this.name,
    required this.bytes,
    this.expiresAt,
    this.width,
    this.height,
  });
  final String id;
  final String name;
  final int bytes;
  final DateTime? expiresAt;
  final int? width;
  final int? height;
  factory UploadedImage.fromJson(Map<String, Object?> json) {
    final size = json['bytes'];
    final expiration = json['expires_at'];
    if (size is! int ||
        size <= 0 ||
        size > 64 * 1024 * 1024 ||
        expiration != null && (expiration is! int || expiration < 0)) {
      throw const ModelException('invalid_response', '图片文件元数据无效');
    }
    return UploadedImage(
      id: readString(json, 'id'),
      name: readString(json, 'filename'),
      bytes: size,
      expiresAt: expiration == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (expiration as int) * 1000,
              isUtc: true,
            ),
    );
  }
  ImageBlock get block => ImageBlock.file(
    id: id,
    label: name,
    width: width,
    height: height,
    byteLength: bytes,
  );
}
