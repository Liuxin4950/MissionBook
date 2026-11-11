import 'dart:convert';

import '../content_block.dart';
import '../message.dart';
import '../model.dart';
import '../models/configuration.dart';
import '../models/wire_codec.dart';

/// 请求输入的本地估算入口；不含未来输出额度或累计用量。
/// 宿主可以注入对应模型的精确 tokenizer。
abstract interface class TokenEstimator {
  int estimate(ModelProfile profile, ModelRequest request);
}

/// 按文本字符估算并预留余量；图片独立计数，base64 不参与文本 token 估算。
final class ApproximateTokenEstimator implements TokenEstimator {
  const ApproximateTokenEstimator();
  static final Map<String, int> _strings = <String, int>{};
  static var _cachedCharacters = 0;

  // JSON 字符串转义与权重按原文缓存；压缩试算复用旧消息时不反复遍历正文。
  static int _stringWeight(String value) {
    final cached = _strings.remove(value);
    if (cached != null) {
      _strings[value] = cached;
      return cached;
    }
    var weight = 0;
    for (final rune in jsonEncode(value).runes) {
      weight += rune < 128
          ? 4
          : rune >= 0x3400 && rune <= 0x9fff
          ? 8
          : rune > 0xffff
          ? 30
          : 15;
    }
    if (value.length <= 8192) {
      while (_strings.isNotEmpty &&
          (_strings.length >= 256 ||
              _cachedCharacters + value.length > 65536)) {
        final first = _strings.keys.first;
        _cachedCharacters -= first.length;
        _strings.remove(first);
      }
      _strings[value] = weight;
      _cachedCharacters += value.length;
    }
    return weight;
  }

  static int _jsonWeight(Object? value) {
    if (value is String) return _stringWeight(value);
    if (value is List) {
      return 8 +
          (value.isEmpty ? 0 : (value.length - 1) * 4) +
          value.fold<int>(0, (sum, item) => sum + _jsonWeight(item));
    }
    if (value is Map<String, Object?>) {
      return 8 +
          (value.isEmpty ? 0 : (value.length - 1) * 4) +
          value.entries.fold<int>(
            0,
            (sum, entry) =>
                sum + _stringWeight(entry.key) + 4 + _jsonWeight(entry.value),
          );
    }
    return jsonEncode(value).length * 4;
  }

  @override
  int estimate(ModelProfile profile, ModelRequest request) {
    var imageTokens = 0;
    final messages = <AgentMessage>[];
    for (final message in request.messages) {
      if (message is! UserMessage) {
        messages.add(message);
        continue;
      }
      final content = <ContentBlock>[];
      for (final block in message.content) {
        if (block is ImageBlock) {
          // DeepSeek 公布每张最多 1024 tokens；其他供应商采用可替换的保守估算。
          imageTokens += profile.provider == 'deepseek'
              ? DeepSeekFlash.maxImageTokens
              : 4096;
          content.add(const TextBlock(text: '[image]'));
        } else {
          content.add(block);
        }
      }
      messages.add(UserMessage.withContent(id: message.id, content: content));
    }
    final textRequest = ModelRequest(
      systemPrompt: request.systemPrompt,
      messages: messages,
      tools: request.tools,
      maxOutputTokens: request.maxOutputTokens,
      reasoningEffort: request.reasoningEffort,
      jsonOutput: request.jsonOutput,
      purpose: request.purpose,
    );
    final body = encodeModelRequest(profile, textRequest, stream: false);
    // 只估算模型实际接收的输入：系统提示、消息和工具定义。
    // max_tokens、stream、temperature 等控制参数不占输入 token。
    final weight = _jsonWeight({
      for (final key in ['system', 'messages', 'tools'])
        if (body.containsKey(key)) key: body[key],
    });
    // 使用十分之一 token 的整数权重，避免多次累加浮点误差。
    return (weight + 9) ~/ 10 + imageTokens + messages.length * 8;
  }
}
