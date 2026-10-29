import '../content_block.dart';
import '../message.dart';
import '../models/configuration.dart';

/// 会话存储和摘要输入共用的明确格式，不把 Dart 对象直接塞进文件。
Map<String, Object?> encodeMessage(AgentMessage message) => {
  'id': message.id,
  'content': message.content.map(encodeContentBlock).toList(),
  ...switch (message) {
    UserMessage() => {'role': 'user'},
    AssistantMessage() => {
      'role': 'assistant',
      'provider': message.provider,
      'model': message.model,
    },
    ToolResultMessage() => {
      'role': 'tool',
      'toolCallId': message.toolCallId,
      'toolName': message.toolName,
      'isError': message.isError,
      'errorCode': message.errorCode,
    },
    ContextMessage() => {'role': 'context', 'source': message.source},
    ContextSummaryMessage() => {
      'role': 'summary',
      'summarizedMessageIds': message.summarizedMessageIds,
    },
  },
};

AgentMessage decodeMessage(Map<String, Object?> json) {
  final id = readString(json, 'id');
  final rawBlocks = json['content'];
  if (id.isEmpty || rawBlocks is! List<Object?>) {
    throw const FormatException('无效消息编号或内容');
  }
  final blocks = rawBlocks
      .map((block) => decodeContentBlock(readObject(block)))
      .toList();
  String textOnly() {
    if (blocks.any((block) => block is! TextBlock)) {
      throw const FormatException('当前消息只接受文字');
    }
    return blocks.cast<TextBlock>().map((block) => block.text).join();
  }

  return switch (readString(json, 'role')) {
    'user' => UserMessage.withContent(id: id, content: blocks),
    'assistant' => AssistantMessage(
      id: id,
      content: blocks,
      provider: readString(json, 'provider'),
      model: readString(json, 'model'),
    ),
    'tool' => ToolResultMessage(
      id: id,
      text: textOnly(),
      toolCallId: readString(json, 'toolCallId'),
      toolName: readString(json, 'toolName'),
      isError: _bool(json['isError']),
      errorCode: _nullableString(json['errorCode']),
    ),
    'context' => ContextMessage(
      id: id,
      source: readString(json, 'source'),
      text: textOnly(),
    ),
    'summary' => ContextSummaryMessage(
      id: id,
      text: textOnly(),
      summarizedMessageIds: _strings(json['summarizedMessageIds']),
    ),
    _ => throw const FormatException('未知消息角色'),
  };
}

Map<String, Object?> encodeContentBlock(ContentBlock block) => switch (block) {
  TextBlock() => {'type': 'text', 'text': block.text},
  ImageBlock() => {
    'type': 'image',
    if (block.fileId != null) 'fileId': block.fileId else 'url': block.url,
    if (block.provider != null) 'provider': block.provider,
    'detail': block.detail.name,
    if (block.label != null) 'label': block.label,
    if (block.width != null) 'width': block.width,
    if (block.height != null) 'height': block.height,
    if (block.byteLength != null) 'byteLength': block.byteLength,
  },
  ThinkingBlock() => {
    'type': 'thinking',
    'text': block.text,
    'signature': block.signature,
  },
  ToolCallBlock() => {
    'type': 'tool-call',
    'id': block.id,
    'name': block.name,
    'input': block.input,
  },
};

ContentBlock decodeContentBlock(Map<String, Object?> json) =>
    switch (readString(json, 'type')) {
      'text' => TextBlock(text: readString(json, 'text')),
      'image' =>
        json['fileId'] != null
            ? ImageBlock.file(
                id: readString(json, 'fileId'),
                provider: json['provider'] as String? ?? 'deepseek',
                label: json['label'] as String?,
                width: json['width'] as int?,
                height: json['height'] as int?,
                byteLength: json['byteLength'] as int?,
              )
            : ImageBlock(
                url: readString(json, 'url'),
                detail: ImageDetail.values.byName(
                  json['detail'] as String? ?? 'auto',
                ),
                label: json['label'] as String?,
                width: json['width'] as int?,
                height: json['height'] as int?,
                byteLength: json['byteLength'] as int?,
              ),
      'thinking' => ThinkingBlock(
        text: readString(json, 'text'),
        signature: _nullableString(json['signature']),
      ),
      'tool-call' => ToolCallBlock(
        id: readString(json, 'id'),
        name: readString(json, 'name'),
        input: readObject(json['input']),
      ),
      _ => throw const FormatException('未知内容块'),
    };

bool _bool(Object? value) {
  if (value is! bool) throw const FormatException('需要布尔值');
  return value;
}

String? _nullableString(Object? value) {
  if (value != null && value is! String) {
    throw const FormatException('需要字符串或空值');
  }
  return value as String?;
}

List<String> _strings(Object? value) {
  if (value is! List<Object?> || value.any((item) => item is! String)) {
    throw const FormatException('需要字符串列表');
  }
  return value.cast<String>();
}
