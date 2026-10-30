import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

bool isPublicAddress(InternetAddress address) {
  final b = address.rawAddress;
  if (b.length == 4) {
    return !(b[0] == 0 ||
        b[0] == 10 ||
        b[0] == 127 ||
        b[0] >= 224 ||
        b[0] == 169 && b[1] == 254 ||
        b[0] == 172 && b[1] >= 16 && b[1] <= 31 ||
        b[0] == 192 && (b[1] == 168 || b[1] == 0 || b[1] == 2) ||
        b[0] == 100 && b[1] >= 64 && b[1] <= 127 ||
        b[0] == 198 && (b[1] == 18 || b[1] == 19 || b[1] == 51) ||
        b[0] == 203 && b[1] == 0 && b[2] == 113);
  }
  // 仅全球单播 2000::/3，排除保留的文档和隧道前缀，拒绝映射私网地址。
  return b.length == 16 &&
      b[0] >= 0x20 &&
      b[0] <= 0x3f &&
      !(b[0] == 0x20 &&
          b[1] == 0x01 &&
          (b[2] == 0x0d && b[3] == 0xb8 || b[2] == 0 && b[3] == 0)) &&
      !(b[0] == 0x20 && b[1] == 0x02);
}

/// 代理 Fake-IP 不是可连接的公网地址；仅在此情形下用固定 HTTPS 公共 DNS 解析。
Future<List<InternetAddress>> _resolvePublicHost(String host) async {
  final addresses = await InternetAddress.lookup(host);
  bool fake(InternetAddress a) =>
      a.rawAddress.length == 4 &&
      a.rawAddress[0] == 198 &&
      [18, 19].contains(a.rawAddress[1]);
  if (addresses.isNotEmpty &&
      addresses.every(fake) &&
      InternetAddress.tryParse(host) == null) {
    final dns = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..findProxy = (_) => 'DIRECT';
    try {
      return await (() async {
        final request = await dns.getUrl(
          Uri.https('1.1.1.1', '/dns-query', {'name': host, 'type': 'A'}),
        );
        request.followRedirects = false;
        request.headers.set('Accept', 'application/dns-json');
        final response = await request.close();
        if (response.statusCode != 200) throw const SocketException('公开地址解析失败');
        final bytes = <int>[];
        await for (final part in response) {
          bytes.addAll(part);
          if (bytes.length > 65536) throw const SocketException('DNS响应过大');
        }
        return publicDnsAddresses(jsonDecode(utf8.decode(bytes)));
      })().timeout(const Duration(seconds: 8));
    } finally {
      dns.close(force: true);
    }
  }
  if (addresses.isEmpty || addresses.any((a) => !isPublicAddress(a))) {
    throw const SocketException('网页地址不是公开网络地址');
  }
  return addresses;
}

/// DNS 返回的地址仍需全部校验，不把保留地址、CNAME 文本或空响应当作公网 IP。
List<InternetAddress> publicDnsAddresses(Object? decoded) {
  if (decoded is! Map || decoded['Status'] != 0 || decoded['Answer'] is! List) {
    throw const SocketException('公开地址解析失败');
  }
  final result = <InternetAddress>[];
  for (final entry in decoded['Answer'] as List) {
    if (entry is! Map || entry['type'] != 1) continue;
    final address = InternetAddress.tryParse('${entry['data']}');
    if (address == null || !isPublicAddress(address)) {
      throw const SocketException('DNS包含非公网地址');
    }
    result.add(address);
  }
  if (result.isEmpty) throw const SocketException('未找到可验证的公网地址');
  return result;
}

/// DNS 校验与实际连接使用同一 IP，避免校验后再次解析而访问内网。
http.Client publicHttpClient() {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..findProxy = (_) => 'DIRECT';
  client.connectionFactory = (uri, proxyHost, proxyPort) async {
    final addresses = await _resolvePublicHost(uri.host);
    final task = await Socket.startConnect(addresses.first, uri.port);
    if (uri.scheme != 'https') return task;
    Socket? active;
    var cancelled = false;
    final secure = task.socket.then<Socket>((socket) async {
      active = socket;
      if (cancelled) {
        socket.destroy();
        throw const SocketException('连接已取消');
      }
      // 自定义连接工厂须显式启用 TLS；使用原域名验证证书和发送 SNI，IP 不再解析。
      final tls = await SecureSocket.secure(
        socket,
        host: uri.host,
      ).timeout(const Duration(seconds: 10));
      active = tls;
      if (cancelled) {
        tls.destroy();
        throw const SocketException('连接已取消');
      }
      return tls;
    });
    return ConnectionTask.fromSocket(secure, () {
      cancelled = true;
      active?.destroy();
      task.cancel();
    });
  };
  return IOClient(client);
}
