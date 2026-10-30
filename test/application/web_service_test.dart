import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:agent_core/agent_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/data/web/public_http_client_io.dart';

class _Settings implements WebSettingsStore {
  String? value = 'test-key';
  int cap = 2;
  @override
  Future<String?> key() async => value;
  @override
  Future<int> limit() async => cap;
  @override
  Future<void> save(String? key, int limit) async {
    if (key != null) value = key;
    cap = limit;
  }
}

class _Quota implements SearchQuotaStore {
  final values = <String, int>{};
  @override
  Future<bool> reserve(String month, int limit) async {
    if ((values[month] ?? 0) >= limit) return false;
    values[month] = (values[month] ?? 0) + 1;
    return true;
  }

  @override
  Future<int> used(String month) async => values[month] ?? 0;
  @override
  Future<void> exhaust(String month, int limit) async {
    values[month] = limit;
  }
}

void main() {
  late _Settings settings;
  late _Quota quota;
  late DateTime now;
  setUp(() {
    settings = _Settings();
    quota = _Quota();
    now = DateTime.utc(2026, 10, 30);
  });
  WebService service(Future<http.Response> Function(http.Request) handle) =>
      WebService(
        settings: settings,
        quota: quota,
        clock: () => now,
        searchClient: () => MockClient(handle),
        fetchClient: () => MockClient(handle),
      );
  test('未配置Key不出网、不预留额度', () async {
    settings.value = null;
    final web = service((_) async => throw StateError('不应出网'));
    expect((await web.search('实时资料'))['state'], 'not_configured');
    expect(quota.values, isEmpty);
  });
  test('基础请求固定低额度参数，返回来源及时间；到上限停止', () async {
    var requests = 0;
    final web = service((request) async {
      requests++;
      expect(request.headers['Authorization'], 'Bearer test-key');
      final body = jsonDecode(request.body) as Map;
      expect(body['search_depth'], 'basic');
      expect(body['max_results'], 5);
      expect(body['include_published_date'], true);
      expect(body['auto_parameters'], false);
      expect(body['include_answer'], false);
      expect(body['include_raw_content'], false);
      expect(body['include_domains'], ['example.com']);
      return http.Response(
        jsonEncode({
          'results': [
            {
              'title': '来源',
              'url': 'https://example.com/article',
              'content': '摘要',
              'published_date': '2026-10-29',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final result = await web.search('实时资料', domains: ['example.com']);
    expect((result['results'] as List).single['publishedAt'], '2026-10-29');
    expect(result['retrievedAt'], now.toIso8601String());
    await web.search('第二次', domains: ['example.com']);
    expect((await web.search('第三次'))['state'], 'quota_exhausted');
    expect(requests, 2);
  });
  test('取消、错误响应保留已预留额度，不自动付费或切换服务', () async {
    final pending = Completer<http.Response>();
    final web = service((_) => pending.future);
    final cancel = CancellationToken();
    final call = web.search('请求', cancellation: cancel);
    await Future<void>.delayed(Duration.zero);
    cancel.cancel();
    await expectLater(call, throwsA(isA<AgentCancelled>()));
    expect(await quota.used('2026-10'), 1);
    pending.complete(http.Response('{}', 500));
    final error = service((_) async => http.Response('bad key test-key', 401));
    expect((await error.search('请求'))['status'], 401);
    expect(
      jsonEncode(await error.configuration()),
      isNot(contains('test-key')),
    );
  });
  test('服务额度达到后停止当月搜索，下月重新计数', () async {
    var calls = 0;
    final web = service((_) async {
      calls++;
      return http.Response('{}', 432);
    });
    expect((await web.search('请求'))['state'], 'provider_limit');
    expect((await web.search('再次'))['state'], 'quota_exhausted');
    expect(calls, 1);
    now = DateTime.utc(2026, 11, 1);
    expect((await web.search('下月'))['state'], 'provider_limit');
    expect(calls, 2);
  });
  test('网页提取正文、移除脚本与导航、6000字分段保留URL', () async {
    final text = List.filled(7000, '文').join();
    final web = service(
      (_) async => http.Response(
        '<html><title>资料标题</title><script>恶意指令</script><nav>导航</nav><article>$text</article></html>',
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      ),
    );
    final first = await web.fetch('https://example.com/article');
    expect(first['title'], '资料标题');
    expect((first['text'] as String).length, 6000);
    expect(first['nextOffset'], 6000);
    expect(first['url'], 'https://example.com/article');
    expect(first['text'], isNot(contains('恶意指令')));
    final next = await web.fetch('https://example.com/article', offset: 6000);
    expect((next['text'] as String).length, 1000);
    expect(next['truncated'], false);
  });
  test('公开地址校验拒绝内网、特殊协议、凭据、端口及DNS保留地址', () {
    for (final url in [
      'file:///etc/passwd',
      'http://localhost/',
      'http://intranet/',
      'https://user:pass@example.com',
      'https://example.com:8080',
    ]) {
      expect(() => WebService.validateUrl(url), throwsArgumentError);
    }
    for (final ip in [
      '127.0.0.1',
      '10.1.1.1',
      '169.254.169.254',
      '172.16.1.1',
      '192.168.0.1',
      '100.64.0.1',
      '::1',
      '::ffff:127.0.0.1',
      'fe80::1',
      'fd00::1',
      '2001:db8::1',
    ]) {
      expect(isPublicAddress(InternetAddress(ip)), false, reason: ip);
    }
    expect(isPublicAddress(InternetAddress('8.8.8.8')), true);
    expect(isPublicAddress(InternetAddress('2606:4700:4700::1111')), true);
  });
  test('公共DNS兼容解析仍拒绝私网、空结果和非地址记录', () {
    expect(
      publicDnsAddresses({
        'Status': 0,
        'Answer': [
          {'type': 1, 'data': '1.1.1.1'},
        ],
      }).single.address,
      '1.1.1.1',
    );
    for (final response in [
      {
        'Status': 0,
        'Answer': [
          {'type': 1, 'data': '127.0.0.1'},
        ],
      },
      {
        'Status': 0,
        'Answer': [
          {'type': 5, 'data': 'example.com'},
        ],
      },
      {'Status': 3, 'Answer': []},
    ]) {
      expect(
        () => publicDnsAddresses(response),
        throwsA(isA<SocketException>()),
      );
    }
  });
  test('每次重定向重新校验，最多3次，不伪造登录或脚本页读取结果', () async {
    final redirect = service(
      (_) async =>
          http.Response('', 302, headers: {'location': 'http://localhost/'}),
    );
    await expectLater(
      redirect.fetch('https://example.com'),
      throwsArgumentError,
    );
    final loop = service(
      (_) async => http.Response('', 302, headers: {'location': '/again'}),
    );
    expect(
      (await loop.fetch('https://example.com'))['state'],
      'redirect_limit',
    );
    final login = service((_) async => http.Response('login', 401));
    expect((await login.fetch('https://example.com'))['state'], 'unavailable');
    final script = service(
      (_) async => http.Response(
        '<body><script>load()</script><div id="app"></div></body>',
        200,
        headers: {'content-type': 'text/html'},
      ),
    );
    expect(
      (await script.fetch('https://example.com'))['state'],
      'insufficient_content',
    );
    final binary = service(
      (_) async => http.Response(
        'pdf',
        200,
        headers: {'content-type': 'application/pdf'},
      ),
    );
    expect(
      (await binary.fetch('https://example.com'))['state'],
      'unsupported_format',
    );
  });
  test('超大正文拒绝，读取取消不会交回伪造文本', () async {
    final huge = service(
      (_) async => http.Response(
        'x' * (2 * 1024 * 1024 + 1),
        200,
        headers: {'content-type': 'text/plain'},
      ),
    );
    await expectLater(huge.fetch('https://example.com'), throwsStateError);
    final cancel = CancellationToken()..cancel();
    await expectLater(
      huge.fetch('https://example.com', cancellation: cancel),
      throwsA(isA<AgentCancelled>()),
    );
  });
}
