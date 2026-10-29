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

  ToolOutput.failure(String code, String message)
    : isError = true,
      errorCode = code,
      text = jsonEncode({'ok': false, 'code': code, 'message': message});

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
    return result.errors.map((error) => error.toString()).join('; ');
  }
}

/// 一次调用的授权结果；需要确认时，应用先等用户选择再返回。
final class ToolDecision {
  const ToolDecision.allow() : allowed = true, reason = '', input = null;

  /// 宿主批准的最终参数；执行前重新校验并先持久化，不改写模型原消息。
  ToolDecision.allowWithInput(Map<String, Object?> value)
    : allowed = true,
      reason = '',
      input = freezeJsonObject(value);
  const ToolDecision.deny(this.reason) : allowed = false, input = null;

  final bool allowed;
  final String reason;
  final Map<String, Object?>? input;
}

typedef ToolAuthorizer =
    FutureOr<ToolDecision> Function(
      ToolDefinition tool,
      ToolCallBlock call,
      CancellationToken cancellation,
    );
