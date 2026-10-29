import 'dart:convert';

import '../model.dart';
import 'configuration.dart';
import 'sse_reader.dart';
import 'wire_codec.dart';

/// Messages 的块可以交错到达；先按编号组装，收到 message_stop 才交付完整响应。
Stream<ModelStreamEvent> decodeMessagesStream(
  ModelProfile profile,
  Stream<ServerSentEvent> frames,
) async* {
  final blocks = <int, _MessageBlock>{};
  Map<String, Object?>? header;
  final usage = <String, Object?>{};
  Object? stopReason;
  await for (final frame in frames) {
    final event = readObject(jsonDecode(frame.data));
    final type = readString(event, 'type');
    if (frame.name != null && frame.name != type) {
      throw const FormatException('SSE 事件名称不一致');
    }
    if (type == 'ping') continue;
    if (type == 'error') throw streamError(event['error']);
    if (type == 'message_start') {
      if (header != null) throw const FormatException('重复 message_start');
      header = readObject(event['message']);
      if (header['role'] != 'assistant' || header['type'] != 'message') {
        throw const FormatException('无效流开始');
      }
      if (header['usage'] != null) {
        usage.addAll(readObject(header['usage']));
        yield ModelUsageSnapshot(decodeUsage(profile.protocol, usage));
      }
      continue;
    }
    if (header == null) throw const FormatException('流在 message_start 前包含内容');
    if (type == 'content_block_start') {
      final index = _index(event);
      if (blocks.containsKey(index) || stopReason != null) {
        throw const FormatException('重复或过晚的内容块');
      }
      final block = _MessageBlock(readObject(event['content_block']));
      blocks[index] = block;
      if (block.type == 'text' && block.text.isNotEmpty) {
        yield ModelTextDelta(index, block.text.toString());
      }
      if (block.type == 'thinking' && block.text.isNotEmpty) {
        yield ModelThinkingDelta(index, block.text.toString());
      }
      if (block.type == 'tool_use') {
        yield ModelToolCallDelta(
          index,
          id: readString(block.initial, 'id'),
          name: readString(block.initial, 'name'),
        );
      }
    } else if (type == 'content_block_delta') {
      final index = _index(event);
      final block = blocks[index];
      if (block == null || block.closed) {
        throw const FormatException('未打开的块收到增量');
      }
      final delta = readObject(event['delta']);
      switch (delta['type']) {
        case 'text_delta':
          if (block.type != 'text') throw const FormatException('文字增量的块类型错误');
          final text = readString(delta, 'text');
          block.text.write(text);
          yield ModelTextDelta(index, text);
        case 'thinking_delta':
          if (block.type != 'thinking') {
            throw const FormatException('思考增量的块类型错误');
          }
          final text = readString(delta, 'thinking');
          block.text.write(text);
          yield ModelThinkingDelta(index, text);
        case 'signature_delta':
          if (block.type != 'thinking') {
            throw const FormatException('签名对应的块类型错误');
          }
          block.signature.write(readString(delta, 'signature'));
        case 'input_json_delta':
          if (block.type != 'tool_use') {
            throw const FormatException('工具参数对应的块类型错误');
          }
          final partial = readString(delta, 'partial_json');
          block.arguments.write(partial);
          yield ModelToolCallDelta(index, argumentsDelta: partial);
        default:
          throw const FormatException('未知内容增量');
      }
    } else if (type == 'content_block_stop') {
      final block = blocks[_index(event)];
      if (block == null || block.closed) {
        throw const FormatException('重复或未打开的块结束');
      }
      block.closed = true;
    } else if (type == 'message_delta') {
      final delta = readObject(event['delta']);
      if (delta['stop_reason'] != null) stopReason = delta['stop_reason'];
      if (event['usage'] != null) {
        usage.addAll(readObject(event['usage']));
        yield ModelUsageSnapshot(decodeUsage(profile.protocol, usage));
      }
    } else if (type == 'message_stop') {
      if (stopReason == null || blocks.values.any((block) => !block.closed)) {
        throw const FormatException('流未完整结束');
      }
      final ordered = blocks.keys.toList()..sort();
      final content = <Map<String, Object?>>[];
      for (final index in ordered) {
        try {
          content.add(blocks[index]!.finish());
        } on FormatException {
          if (stopReason != 'max_tokens') rethrow;
        }
      }
      yield ModelCompleted(
        decodeModelResponse(profile, {
          ...header,
          'content': content,
          'stop_reason': stopReason,
          'usage': usage,
        }),
      );
      return;
    }
  }
  throw const ModelException(
    'stream_interrupted',
    '模型流在完整结束前断开',
    retryable: true,
  );
}

/// Chat Completions 按 tool_calls[index] 拼接参数，等待 finish_reason 和 [DONE]。
Stream<ModelStreamEvent> decodeChatStream(
  ModelProfile profile,
  Stream<ServerSentEvent> frames,
) async* {
  final text = StringBuffer();
  final thinking = StringBuffer();
  final tools = <int, _ChatTool>{};
  Object? reason;
  Object? usage;
  String? model;
  await for (final frame in frames) {
    if (frame.data == '[DONE]') {
      if (reason == null || model == null) {
        throw const FormatException('流缺少结束原因或模型');
      }
      final calls = <Map<String, Object?>>[];
      final indexes = tools.keys.toList()..sort();
      for (final index in indexes) {
        final tool = tools[index]!;
        calls.add({
          'id': tool.id,
          'type': 'function',
          'function': {
            'name': tool.name,
            'arguments': tool.arguments.toString(),
          },
        });
      }
      yield ModelCompleted(
        decodeModelResponse(profile, {
          'model': model,
          'usage': usage,
          'choices': [
            {
              'finish_reason': reason,
              'message': {
                'role': 'assistant',
                'content': text.toString(),
                'reasoning_content': thinking.toString(),
                if (calls.isNotEmpty) 'tool_calls': calls,
              },
            },
          ],
        }),
      );
      return;
    }
    final event = readObject(jsonDecode(frame.data));
    if (event['error'] != null) throw streamError(event['error']);
    if (event['model'] != null) model = readString(event, 'model');
    if (event['usage'] != null) {
      usage = event['usage'];
      yield ModelUsageSnapshot(decodeUsage(profile.protocol, usage));
    }
    final choices = event['choices'];
    if (choices is! List<Object?> || choices.length > 1) {
      throw const FormatException('无效流选择');
    }
    if (choices.isEmpty) continue; // 最后的 usage 帧可能没有 choice。
    final choice = readObject(choices.single);
    if (choice['index'] != 0) throw const FormatException('只接受第一个模型选择');
    final delta = readObject(choice['delta']);
    if (reason != null && delta.isNotEmpty) {
      throw const FormatException('结束后又收到模型内容');
    }
    final nextText = delta['content'];
    if (nextText != null) {
      if (nextText is! String) throw const FormatException('无效文字增量');
      text.write(nextText);
      if (nextText.isNotEmpty) yield ModelTextDelta(0, nextText);
    }
    final nextThinking = delta['reasoning_content'];
    if (nextThinking != null) {
      if (nextThinking is! String) throw const FormatException('无效思考增量');
      thinking.write(nextThinking);
      if (nextThinking.isNotEmpty) yield ModelThinkingDelta(0, nextThinking);
    }
    final nextTools = delta['tool_calls'];
    if (nextTools != null) {
      if (nextTools is! List<Object?>) throw const FormatException('无效工具增量');
      for (final raw in nextTools) {
        final update = readObject(raw);
        final index = _index(update);
        final tool = tools.putIfAbsent(index, _ChatTool.new);
        if (update['id'] != null) {
          if (tool.id != null && tool.id != update['id']) {
            throw const FormatException('同一工具索引的编号发生变化');
          }
          tool.id = readString(update, 'id');
        }
        final function = update['function'] == null
            ? <String, Object?>{}
            : readObject(update['function']);
        if (function['name'] != null) {
          if (tool.name != null && tool.name != function['name']) {
            throw const FormatException('同一工具索引的名称发生变化');
          }
          tool.name = readString(function, 'name');
        }
        final arguments = function['arguments'] == null
            ? ''
            : readString(function, 'arguments');
        tool.arguments.write(arguments);
        yield ModelToolCallDelta(
          index,
          id: tool.id,
          name: tool.name,
          argumentsDelta: arguments,
        );
      }
    }
    if (choice['finish_reason'] != null) {
      if (reason != null) throw const FormatException('重复结束原因');
      reason = choice['finish_reason'];
    }
  }
  throw const ModelException(
    'stream_interrupted',
    '模型流在 [DONE] 前断开',
    retryable: true,
  );
}

ModelException streamError(Object? raw) {
  final error = readObject(raw);
  final kind = error['code'] ?? error['type'];
  if ([
    'context_length_exceeded',
    'context_window_exceeded',
    'prompt_too_long',
  ].contains(kind)) {
    return const ModelException('context_overflow', '模型报告上下文超出限制');
  }
  final temporary = [
    'overloaded_error',
    'rate_limit_error',
    'server_error',
    'api_error',
  ].contains(kind);
  return ModelException(
    temporary ? 'server_error' : 'provider_error',
    '模型服务返回错误',
    retryable: temporary,
  );
}

int _index(Map<String, Object?> event) {
  final value = event['index'];
  if (value is! int || value < 0) throw const FormatException('无效内容编号');
  return value;
}

final class _MessageBlock {
  _MessageBlock(this.initial) : type = readString(initial, 'type') {
    if (type == 'text') {
      text.write(readString(initial, 'text'));
    } else if (type == 'thinking') {
      text.write(readString(initial, 'thinking'));
      if (initial['signature'] != null) {
        signature.write(readString(initial, 'signature'));
      }
    } else if (type != 'tool_use') {
      throw const FormatException('未知流内容块');
    }
  }
  final Map<String, Object?> initial;
  final String type;
  final text = StringBuffer();
  final arguments = StringBuffer();
  final signature = StringBuffer();
  bool closed = false;

  Map<String, Object?> finish() => switch (type) {
    'text' => {'type': type, 'text': text.toString()},
    'thinking' => {
      'type': type,
      'thinking': text.toString(),
      if (signature.isNotEmpty) 'signature': signature.toString(),
    },
    'tool_use' => {
      ...initial,
      'input': arguments.isEmpty
          ? readObject(initial['input'])
          : readObject(jsonDecode(arguments.toString())),
    },
    _ => throw const FormatException('无效内容块'),
  };
}

final class _ChatTool {
  String? id;
  String? name;
  final arguments = StringBuffer();
}
