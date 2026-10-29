import 'dart:io';
import 'dart:convert';
import 'package:agent_core/agent_core.dart';

/// 用合成历史验证思考后继续，以及 Chat 的 JSON 对象输出，不读取 App 资料。
Future<void> main() async {
  final key = Platform.environment['DEEPSEEK_API_KEY'];
  if (key == null || key.trim().isEmpty) {
    stderr.writeln('请先设置 DEEPSEEK_API_KEY');
    exitCode = 2;
    return;
  }
  final config = AgentConfiguration.deepSeek();
  for (final profile in config.profiles) {
    final model = HttpAgentModel(profile: profile, credentials: (_) => key);
    try {
      final result = await model.complete(
        ModelRequest(
          systemPrompt: '简短回答用户问题。',
          messages: [
            UserMessage(text: '1+1等于多少？'),
            AssistantMessage(
              provider: profile.provider,
              model: profile.model,
              content: [const ThinkingBlock(text: '先计算加法。')],
            ),
          ],
          tools: [],
          maxOutputTokens: 128,
        ),
        CancellationToken(),
      );
      if (result.stopReason != ModelStopReason.completed ||
          !result.message.text.contains('2')) {
        throw StateError('思考后继续未完成');
      }
      print('${profile.protocol.name} reasoning-only replay PASS');
    } finally {
      model.close();
    }
  }
  final model = HttpAgentModel(
    profile: config.profile('deepseek-chat'),
    credentials: (_) => key,
  );
  try {
    final result = await model.complete(
      ModelRequest(
        systemPrompt: '返回 JSON 对象，ok 为 true。',
        messages: [UserMessage(text: '验证 JSON 输出')],
        tools: [],
        jsonOutput: true,
        maxOutputTokens: 128,
      ),
      CancellationToken(),
    );
    if (result.stopReason != ModelStopReason.completed ||
        jsonDecode(result.message.text)['ok'] != true) {
      throw StateError('JSON 输出未通过');
    }
    print('Chat JSON output PASS');
  } finally {
    model.close();
  }
}
