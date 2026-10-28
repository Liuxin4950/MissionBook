import 'dart:convert';

/// 一帧完整 SSE 数据；只有空行结束的帧才会交给协议解析器。
final class ServerSentEvent {
  const ServerSentEvent(this.name, this.data);
  final String? name;
  final String data;
}

Stream<ServerSentEvent> readServerSentEvents(Stream<List<int>> bytes) async* {
  String? name;
  final data = <String>[];
  var firstLine = true;
  await for (var line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (firstLine) {
      line = line.replaceFirst(RegExp('^\uFEFF'), '');
      firstLine = false;
    }
    if (line.isEmpty) {
      if (data.isNotEmpty) yield ServerSentEvent(name, data.join('\n'));
      name = null;
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue; // 心跳不是模型内容。
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'event') name = value;
    if (field == 'data') data.add(value);
  }
  // 缺少终止空行的尾帧不交付；上层会据缺少终止事件报告断流。
}
