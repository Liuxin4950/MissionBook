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
  String path,
  String message,
) {
  final field = _fieldPath(path);
  final prefix = field.isEmpty ? '输入' : '参数 $field';
  final minimum = RegExp(
    r'^minimum violated \(([^)]*) < ([^)]*)\)$',
  ).firstMatch(message);
  if (minimum != null) {
    return '$prefix 不能小于 ${minimum[2]}（收到 ${minimum[1]}）';
  }
  final maximum = RegExp(
    r'^maximum violated \(([^)]*) > ([^)]*)\)$',
  ).firstMatch(message);
  if (maximum != null) {
    return '$prefix 不能大于 ${maximum[2]}（收到 ${maximum[1]}）';
  }
  final items = RegExp(
    r'^(minItems|maxItems) violated \(([^)]*) vs ([^)]*)\)$',
  ).firstMatch(message);
  if (items != null) {
    return items[1] == 'minItems'
        ? '$prefix 至少 ${items[3]} 项（收到 ${items[2]} 项）'
        : '$prefix 最多 ${items[3]} 项（收到 ${items[2]} 项）';
  }
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
    final name = missing[1]!;
    // 同一条缺失会同时落在父路径和属性路径上，统一成属性全名后再去重。
    if (field == name || field.endsWith('.$name') || field.endsWith('[$name]')) {
      return '缺少必填参数 $field';
    }
    return '缺少必填参数 ${field.isEmpty ? name : '$field.$name'}';
  }
  final additional = RegExp(
    r'^unallowed additional property (\w+)$',
  ).firstMatch(message);
  if (additional != null) {
    final name = additional[1]!;
    return '不支持参数 ${field.isEmpty ? name : '$field.$name'}';
  }
  return '$prefix 校验失败：$message';
}

String _fieldPath(String path) => path
    .split('/')
    .skip(1)
    .fold<String>(
      '',
      (acc, part) => int.tryParse(part) != null
          ? '$acc[$part]'
          : (acc.isEmpty ? part : '$acc.$part'),
    );

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
