import 'dart:async';
import 'dart:convert';

import 'package:json_schema/json_schema.dart';

import 'cancellation.dart';
import 'content_block.dart';
import 'json_value.dart';

/// 发给模型的工具说明，不包含执行函数或应用服务对象。
final class ToolDefinition {
  ToolDefinition({
    required this.name,
    required this.description,
    required Map<String, Object?> inputSchema,
  }) : inputSchema = freezeJsonObject(inputSchema) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name', '工具名只能包含字母、数字、下划线和连字符');
    }
    if (inputSchema['type'] != 'object') {
      throw ArgumentError('工具 Schema 的根类型必须是 object');
    }
  }

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
}

/// 一次真实工具执行的输出；可预期的业务失败也作为输出交回模型。
final class ToolOutput {
  const ToolOutput.success(this.text) : isError = false, errorCode = null;

  ToolOutput.failure(
    String code,
    String message, {
    Map<String, Object?> details = const {},
  }) : isError = true,
       errorCode = code,
       text = jsonEncode({
         ...details,
         'ok': false,
         'code': code,
         'message': message,
       });

  final String text; // 内容本身包含失败标记，不只依赖供应商的 is_error 字段。
  final bool isError;
  final String? errorCode;
}

/// 交给工具的执行上下文；应用据此关联调用与自己的业务命令。
final class ToolContext {
  const ToolContext({
    required this.callId,
    required this.cancellation,
    this.sessionId,
  });

  final String callId; // 模型调用编号；业务幂等命令仍由应用创建、保留和校验。
  final CancellationToken cancellation;
  final String? sessionId; // 会话入口运行时提供，独立循环可以不传。
  String get idempotencyKey => '${sessionId ?? 'standalone'}:$callId';
}

/// 工具明确保证本次没有提交副作用时，可用它报告业务拒绝或已确认的回滚。
final class ToolRejected implements Exception {
  const ToolRejected(this.code, this.message);
  final String code;
  final String message;
}

typedef ToolHandler =
    FutureOr<ToolOutput> Function(
      Map<String, Object?> input,
      ToolContext context,
    );

/// 应用注册的工具，包含说明、参数校验和实际执行函数。
final class AgentTool {
  AgentTool({
    required this.definition,
    required this.execute,
    this.readOnly = false,
  }) : _schema = JsonSchema.create(definition.inputSchema);

  final ToolDefinition definition;
  final ToolHandler execute; // 接入 App 时在这里调用已有 Service。
  final bool readOnly; // 只读工具的执行异常可安全回传；写工具的未知结果仍要核对。
  final JsonSchema _schema;

  String? validateInput(Map<String, Object?> input) {
    final result = _schema.validate(input);
    if (result.isValid) return null;
    final seen = <String>{};
    return result.errors
        .map(
          (error) => _describeValidationError(
            definition.inputSchema,
            input,
            error.instancePath,
            error.message,
          ),
        )
        .where(seen.add)
        .join('；');
  }
}

/// 一次调用的授权结果；需要确认时，应用先等用户选择再返回。
final class ToolDecision {
  const ToolDecision.allow()
    : allowed = true,
      reason = '',
      code = null,
      input = null;

  /// 宿主批准的最终参数；执行前重新校验并先持久化，不改写模型原消息。
  ToolDecision.allowWithInput(Map<String, Object?> value)
    : allowed = true,
      reason = '',
      code = null,
      input = freezeJsonObject(value);

  /// [code] 保留拒绝原因的分类；省略时按权限不足处理。
  const ToolDecision.deny(this.reason, {this.code})
    : allowed = false,
      input = null;

  final bool allowed;
  final String reason;
  final String? code;
  final Map<String, Object?>? input;
}

/// JSON Schema 的原始报错是英文；这里按字段路径和关键词给出可执行的中文提示。
String _describeValidationError(
  Map<String, Object?> schema,
  Map<String, Object?> input,
  String path,
  String message,
) {
  final prefix = _subject(input, path);
  // 上下限类报错用 violated/exceeded 区分，括号里是「收到值 符号 限制值」。
  final limit = RegExp(
    r'^(exclusiveMinimum|exclusiveMaximum|minimum|maximum) (?:violated|exceeded) \((.*) (<=|>=|<|>) (.*)\)$',
  ).firstMatch(message);
  if (limit != null) {
    final label = switch (limit[1]) {
      'minimum' => '不能小于',
      'exclusiveMinimum' => '必须大于',
      'maximum' => '不能大于',
      _ => '必须小于',
    };
    return '$prefix $label ${limit[4]}（收到 ${limit[2]}）';
  }
  // 长度、条数与格式类报错，括号里是「收到值 vs 限制值」。
  final ranged = RegExp(
    r'^(minLength|maxLength|minItems|maxItems|pattern) (?:violated|exceeded) \((.*) vs (.*)\)$',
  ).firstMatch(message);
  if (ranged != null) {
    final received = ranged[2]!;
    final bound = ranged[3]!;
    return switch (ranged[1]) {
      'minLength' => '$prefix 至少 $bound 个字符（收到 $received 个字符）',
      'maxLength' => '$prefix 最多 $bound 个字符（收到 $received 个字符）',
      'minItems' => '$prefix 至少 $bound 项（收到 $received 项）',
      'maxItems' => '$prefix 最多 $bound 项（收到 $received 项）',
      _ => '$prefix 格式不符合 $bound',
    };
  }
  final multiple = RegExp(
    r'^multipleOf violated \((.*) % (.*)\)$',
  ).firstMatch(message);
  if (multiple != null) {
    return '$prefix 必须是 ${multiple[2]} 的倍数（收到 ${multiple[1]}）';
  }
  if (message.startsWith('uniqueItems violated')) return '$prefix 不能有重复项';
  final type = RegExp(r'^type: wanted \[(.+)\] got (.*)$').firstMatch(message);
  if (type != null) return '$prefix 类型应为 ${type[1]}';
  final enumerated = RegExp(r'^enum violated (.+)$').firstMatch(message);
  if (enumerated != null) {
    final allowed = _subSchema(schema, path)?['enum'];
    if (allowed is List<Object?> && allowed.isNotEmpty) {
      return '$prefix 只能取 ${allowed.join('、')}';
    }
    return '$prefix 取值不支持：${enumerated[1]}';
  }
  final missing = RegExp(
    r'^required prop missing: (\w+) from ',
  ).firstMatch(message);
  if (missing != null) {
    return '缺少必填参数 ${_memberName(input, path, missing[1]!)}';
  }
  final additional = RegExp(
    r'^unallowed additional property (\w+)$',
  ).firstMatch(message);
  if (additional != null) {
    return '不支持参数 ${_memberName(input, path, additional[1]!)}';
  }
  return '$prefix 校验失败：$message';
}

/// 把实例路径拆成“所属条目 + 字段名”，不把内部数组下标直接暴露给用户。
({String? owner, String leaf}) _splitField(
  Map<String, Object?> input,
  String path,
) {
  final parts = path.split('/').skip(1).toList();
  final index = parts.lastIndexWhere((part) => int.tryParse(part) != null);
  if (index < 0) return (owner: null, leaf: parts.join('.'));
  Object? current = input;
  for (var position = 0; position <= index; position++) {
    final offset = int.tryParse(parts[position]);
    current = offset != null
        ? (current is List && offset < current.length
              ? current[offset]
              : null)
        : (current is Map<String, Object?> ? current[parts[position]] : null);
  }
  final id = current is Map ? current['itemId'] ?? current['id'] : null;
  final owner = id is String && id.trim().isNotEmpty
      ? '条目“$id”'
      : '第 ${int.parse(parts[index]) + 1} 项';
  return (owner: owner, leaf: parts.skip(index + 1).join('.'));
}

String _subject(Map<String, Object?> input, String path) {
  if (path.isEmpty) return '输入';
  final field = _splitField(input, path);
  if (field.owner == null) return '参数 ${field.leaf}';
  return field.leaf.isEmpty ? field.owner! : '${field.owner}的 ${field.leaf}';
}

String _memberName(
  Map<String, Object?> input,
  String path,
  String name,
) {
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  // 同一条缺失会同时报在父路径和属性路径上；两者都归一到属性自身的名字。
  if (parts.isNotEmpty && parts.last == name) {
    final subject = _subject(input, path);
    return subject.startsWith('参数 ') ? subject.substring(3) : subject;
  }
  if (path.isEmpty) return name;
  final parent = _subject(input, path);
  return parent.startsWith('参数 ')
      ? '${parent.substring(3)}.$name'
      : '$parent的 $name';
}

/// 按实例路径取子 Schema，用于把校验错误补成可执行的取值说明。
Map<String, Object?>? _subSchema(Map<String, Object?> schema, String path) {
  Object? current = schema;
  for (final part in path.split('/').skip(1)) {
    if (current is! Map<String, Object?>) return null;
    if (int.tryParse(part) != null) {
      current = current['items'];
      continue;
    }
    final properties = current['properties'];
    if (properties is! Map<String, Object?>) return null;
    current = properties[part];
  }
  return current is Map<String, Object?> ? current : null;
}

typedef ToolAuthorizer =
    FutureOr<ToolDecision> Function(
      ToolDefinition tool,
      ToolCallBlock call,
      CancellationToken cancellation,
    );
