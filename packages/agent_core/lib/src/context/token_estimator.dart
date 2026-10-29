import 'dart:convert';

import '../content_block.dart';
import '../message.dart';
import '../model.dart';
import '../models/configuration.dart';
import '../models/wire_codec.dart';

/// 请求前的本地估算入口；宿主可以注入对应模型的精确 tokenizer。
abstract interface class TokenEstimator {
  int estimate(ModelProfile profile, ModelRequest request);
}

/// 按文本字符估算并预留余量；图片独立计数，base64 不参与文本 token 估算。
final class ApproximateTokenEstimator implements TokenEstimator {
  const ApproximateTokenEstimator();

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
    final text = jsonEncode(
      encodeModelRequest(profile, textRequest, stream: false),
    );
    var estimated = 0.0;
    for (final rune in text.runes) {
      if (rune < 128) {
        estimated += 0.4; // 官方英文近似 0.3，再留本地余量。
      } else if (rune >= 0x3400 && rune <= 0x9fff) {
        estimated += 0.8; // 官方中文近似 0.6；不把三个 UTF-8 字节算成三个 token。
      } else {
        estimated += rune > 0xffff ? 3 : 1.5;
      }
    }
    return estimated.ceil() + imageTokens + messages.length * 8;
  }
}

@Deprecated('使用语义明确的 ApproximateTokenEstimator；它是估算，不是精确计数')
typedef ConservativeTokenEstimator = ApproximateTokenEstimator;
