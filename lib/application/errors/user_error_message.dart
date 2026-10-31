import 'package:agent_core/agent_core.dart';

import '../../domain/entities/evidence.dart';
import '../../domain/entities/execution_command.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/schedule_proposal.dart';

/// 保留业务拒绝的中文原因；平台、路径、响应正文和凭据使用操作级兜底文案。
String userErrorMessage(Object error, {required String fallback}) {
  final Object? detail = switch (error) {
    EvidenceConflict value => value.message,
    ExecutionConflict value => value.message,
    MissionEditConflict value => value.message,
    ScheduleConflictException value => value.toString(),
    ToolRejected value => value.message,
    ArgumentError value => value.message,
    StateError value => value.message,
    FormatException value => value.message,
    _ => null,
  };
  if (detail is! String) return fallback;
  final text = detail.trim();
  if (text.isEmpty ||
      text.runes.length > 240 ||
      !RegExp(r'[\u4e00-\u9fff]').hasMatch(text) ||
      RegExp(
        r'(?:https?://|file://|[a-z]:[\\/]|\n|Exception|StackTrace|sk-[\w-]{8,}|tvly-[\w-]{8,}|(?:api.?key|token|密钥|密码)\s*[:：=])',
        caseSensitive: false,
      ).hasMatch(text)) {
    return fallback;
  }
  return text;
}
