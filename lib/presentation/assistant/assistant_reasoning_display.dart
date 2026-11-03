import 'package:agent_core/agent_core.dart';

String assistantReasoningLabel(ReasoningEffort effort) => switch (effort) {
  ReasoningEffort.off => '关闭',
  ReasoningEffort.low => '低',
  ReasoningEffort.high => '高',
  ReasoningEffort.max => '最高',
};
