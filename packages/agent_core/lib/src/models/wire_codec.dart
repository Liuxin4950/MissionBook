import 'dart:convert';

import '../content_block.dart';
import '../message.dart';
import '../model.dart';
import 'configuration.dart';

/// 只在协议边界转换 JSON；循环和工具不依赖某家 API 的字段名。
Map<String, Object?> encodeModelRequest(
  ModelProfile profile,
  ModelRequest request, {
  required bool stream,
}) {
  validateConversation(request.messages);
  final outputLimit = request.maxOutputTokens ?? profile.maxOutputTokens;
  if (outputLimit < 1 || outputLimit > profile.maxOutputTokens) {
    throw const ModelException('invalid_request', '本次输出上限超出模型配置');
  }
  if (profile.protocol == ModelProtocol.messages) {
    final messages = <Map<String, Object?>>[];
    for (final message in request.messages) {
      final role = message is AssistantMessage ? 'assistant' : 'user';
      final content = _messagesContent(message, profile);
      if (messages.isNotEmpty && messages.last['role'] == role) {
        (messages.last['content']! as List<Map<String, Object?>>).addAll(
          content,
        );
      } else {
        messages.add({'role': role, 'content': content});
      }
    }
    return {
      'model': profile.model,
      'max_tokens': outputLimit,
      'stream': stream,
      'thinking': {
        'type': profile.reasoningEffort == ReasoningEffort.off
            ? 'disabled'
            : 'enabled',
      },
      if (profile.reasoningEffort != ReasoningEffort.off)
        'output_config': {'effort': profile.reasoningEffort.name},
      if (profile.temperature != null) 'temperature': profile.temperature,
      if (request.systemPrompt.isNotEmpty) 'system': request.systemPrompt,
      'messages': messages,
      if (request.tools.isNotEmpty)
        'tools': request.tools
            .map(
              (tool) => {
                'name': tool.name,
                'description': tool.description,
                'input_schema': tool.inputSchema,
              },
            )
            .toList(),
    };
  }
  return {
    'model': profile.model,
    'max_tokens': outputLimit,
    'stream': stream,
    if (stream) 'stream_options': {'include_usage': true},
    if (profile.provider == 'deepseek')
      'thinking': {
        'type': profile.reasoningEffort == ReasoningEffort.off
            ? 'disabled'
            : 'enabled',
      },
    if (profile.reasoningEffort != ReasoningEffort.off)
      'reasoning_effort': profile.reasoningEffort.name,
    if (profile.temperature != null) 'temperature': profile.temperature,
    'messages': [
      if (request.systemPrompt.isNotEmpty)
        {'role': 'system', 'content': request.systemPrompt},
      ...request.messages.map(_chatMessage),
    ],
    if (request.tools.isNotEmpty)
      'tools': request.tools
          .map(
            (tool) => {
              'type': 'function',
              'function': {
                'name': tool.name,
                'description': tool.description,
                'parameters': tool.inputSchema,
              },
            },
          )
          .toList(),
  };
}

List<Map<String, Object?>> _messagesContent(
  AgentMessage message,
  ModelProfile profile,
) {
  if (message is ToolResultMessage) {
    return [
      {
        'type': 'tool_result',
        'tool_use_id': message.toolCallId,
        'content': [
          {'type': 'text', 'text': message.text},
        ],
        'is_error': message.isError,
      },
    ];
  }
  if (message is ContextMessage || message is ContextSummaryMessage) {
    return [
      {'type': 'text', 'text': contextMessageText(message)},
    ];
  }
  final blocks = <Map<String, Object?>>[];
  for (final block in message.content) {
    switch (block) {
      case TextBlock():
        blocks.add({'type': 'text', 'text': block.text});
      case ImageBlock():
        if (block.url.startsWith('data:')) {
          final comma = block.url.indexOf(',');
          final semicolon = block.url.indexOf(';');
          blocks.add({
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': block.url.substring(5, semicolon),
              'data': block.url.substring(comma + 1),
            },
          });
        } else {
          blocks.add({
            'type': 'image',
            'source': {'type': 'url', 'url': block.url},
          });
        }
      case ThinkingBlock():
        if (message is AssistantMessage &&
            message.provider == profile.provider &&
            message.model == profile.model) {
          blocks.add({
            'type': 'thinking',
            'thinking': block.text,
            if (block.signature != null) 'signature': block.signature,
          });
        }
      case ToolCallBlock():
        blocks.add({
          'type': 'tool_use',
          'id': block.id,
          'name': block.name,
          'input': block.input,
        });
    }
  }
  return blocks;
}

Map<String, Object?> _chatMessage(AgentMessage message) {
  switch (message) {
    case ToolResultMessage():
      return {
        'role': 'tool',
        'tool_call_id': message.toolCallId,
        'content': message.text,
      };
    case ContextMessage() || ContextSummaryMessage():
      return {'role': 'user', 'content': contextMessageText(message)};
    case UserMessage():
      if (message.content.every((block) => block is TextBlock)) {
        return {'role': 'user', 'content': message.text};
      }
      return {
        'role': 'user',
        'content': message.content
            .map(
              (block) => switch (block) {
                TextBlock() => <String, Object?>{
                  'type': 'text',
                  'text': block.text,
                },
                ImageBlock() => <String, Object?>{
                  'type': 'image_url',
                  'image_url': {'url': block.url},
                },
                _ => throw const FormatException('用户消息出现无效内容'),
              },
            )
            .toList(),
      };
    case AssistantMessage():
      final reasoning = message.content
          .whereType<ThinkingBlock>()
          .map((block) => block.text)
          .join();
      return {
        'role': 'assistant',
        'content': message.text.isEmpty ? null : message.text,
        if (reasoning.isNotEmpty) 'reasoning_content': reasoning,
        if (message.toolCalls.isNotEmpty)
          'tool_calls': message.toolCalls
              .map(
                (call) => {
                  'id': call.id,
                  'type': 'function',
                  'function': {
                    'name': call.name,
                    'arguments': jsonEncode(call.input),
                  },
                },
              )
              .toList(),
      };
  }
}

String contextMessageText(AgentMessage message) {
  if (message is ContextMessage) {
    return '[背景资料；来源：${message.source}]\n${message.text}';
  }
  return '[较早对话的摘要；原始记录保留在会话日志中]\n${message.text}';
}

ModelResponse decodeModelResponse(
  ModelProfile profile,
  Map<String, Object?> body,
) {
  final blocks = <ContentBlock>[];
  final ModelStopReason reason;
  final String model;
  if (profile.protocol == ModelProtocol.messages) {
    if (body['role'] != 'assistant' || body['type'] != 'message') {
      throw const FormatException('需要模型消息');
    }
    model = readString(body, 'model');
    reason = messagesStopReason(body['stop_reason']);
    final content = body['content'];
    if (content is! List<Object?>) throw const FormatException('缺少 content');
    for (final raw in content) {
      final block = readObject(raw);
      switch (block['type']) {
        case 'text':
          blocks.add(TextBlock(text: readString(block, 'text')));
        case 'thinking':
          final signature = block['signature'];
          if (signature != null && signature is! String) {
            throw const FormatException('无效 signature');
          }
          blocks.add(
            ThinkingBlock(
              text: readString(block, 'thinking'),
              signature: signature as String?,
            ),
          );
        case 'tool_use':
          blocks.add(
            ToolCallBlock(
              id: readString(block, 'id'),
              name: readString(block, 'name'),
              input: readObject(block['input']),
            ),
          );
        default:
          throw const FormatException('未知模型内容块');
      }
    }
  } else {
    model = readString(body, 'model');
    final choices = body['choices'];
    if (choices is! List<Object?> || choices.length != 1) {
      throw const FormatException('需要一个模型选择');
    }
    final choice = readObject(choices.single);
    reason = chatStopReason(choice['finish_reason']);
    final message = readObject(choice['message']);
    if (message['role'] != 'assistant') {
      throw const FormatException('不是 assistant 消息');
    }
    final thinking = message['reasoning_content'];
    if (thinking is String && thinking.isNotEmpty) {
      blocks.add(ThinkingBlock(text: thinking));
    }
    final text = message['content'];
    if (text is String) {
      blocks.add(TextBlock(text: text));
    } else if (text != null) {
      throw const FormatException('无效模型文字');
    }
    final calls = message['tool_calls'];
    if (calls != null) {
      if (calls is! List<Object?>) throw const FormatException('无效工具调用列表');
      for (final rawCall in calls) {
        final call = readObject(rawCall);
        final function = readObject(call['function']);
        try {
          blocks.add(
            ToolCallBlock(
              id: readString(call, 'id'),
              name: readString(function, 'name'),
              input: readObject(jsonDecode(readString(function, 'arguments'))),
            ),
          );
        } on FormatException {
          if (reason != ModelStopReason.maxTokens) rethrow; // 截断的参数从不执行。
        }
      }
    }
  }
  return ModelResponse(
    message: AssistantMessage(
      content: blocks,
      provider: profile.provider,
      model: model,
    ),
    stopReason: reason,
    usage: decodeUsage(profile.protocol, body['usage']),
  );
}

ModelStopReason messagesStopReason(Object? value) => switch (value) {
  'end_turn' || 'stop_sequence' => ModelStopReason.completed,
  'tool_use' => ModelStopReason.toolUse,
  'max_tokens' => ModelStopReason.maxTokens,
  'refusal' => ModelStopReason.refused,
  _ => throw const FormatException('未知 Messages 结束原因'),
};

ModelStopReason chatStopReason(Object? value) => switch (value) {
  'stop' => ModelStopReason.completed,
  'tool_calls' => ModelStopReason.toolUse,
  'length' => ModelStopReason.maxTokens,
  'content_filter' => ModelStopReason.refused,
  _ => throw const FormatException('未知 Chat Completions 结束原因'),
};

TokenUsage decodeUsage(ModelProtocol protocol, Object? value) {
  if (value == null) return const TokenUsage();
  final json = readObject(value);
  int count(String key) {
    final number = json[key] ?? 0;
    if (number is! int || number < 0) {
      throw const FormatException('无效 token 使用量');
    }
    return number;
  }

  if (protocol == ModelProtocol.messages) {
    return TokenUsage(
      inputTokens: count('input_tokens'),
      outputTokens: count('output_tokens'),
      cachedInputTokens: count('cache_read_input_tokens'),
    );
  }
  return TokenUsage(
    inputTokens: count('prompt_tokens'),
    outputTokens: count('completion_tokens'),
    cachedInputTokens: count('prompt_cache_hit_tokens'),
  );
}
