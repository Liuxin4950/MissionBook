import 'dart:convert';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/data/web/public_http_client.dart';
import 'dart:io';

/// 无 Key 的真实 HTTPS 读取检查，只输出状态、来源和正文长度，不输出正文或凭据。
Future<void> main(List<String> args) async {
  final service = WebService(
    settings: _NoSearch(),
    quota: _NoQuota(),
    fetchClient: publicHttpClient,
  );
  final result = await service.fetch(
    args.isEmpty
        ? 'https://api.dart.dev/dart-io/HttpClient/connectionFactory.html'
        : args.single,
  );
  stdout.writeln(
    jsonEncode({
      'state': result['state'],
      'url': result['url'],
      'title': result['title'],
      'characters': (result['text'] as String?)?.length,
      'retrievedAt': result['retrievedAt'],
    }),
  );
  if (result['state'] != 'ok') throw StateError('真实网页未读取成功');
}

class _NoSearch implements WebSettingsStore {
  @override
  Future<String?> key() async => null;
  @override
  Future<int> limit() async => 0;
  @override
  Future<void> save(String? key, int limit) async =>
      throw UnsupportedError('仅核验网页读取');
}

class _NoQuota implements SearchQuotaStore {
  @override
  Future<bool> reserve(String month, int limit) async => false;
  @override
  Future<int> used(String month) async => 0;
  @override
  Future<void> exhaust(String month, int limit) async {}
}
