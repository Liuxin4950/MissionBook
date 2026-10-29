import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agent_core/agent_core.dart';
import 'package:image/image.dart' as images;

/// 真实视觉验收：生成不含个人信息的测试图，验证双协议，再删除本次云端测试文件。
Future<void> main() async {
  final key = Platform.environment['DEEPSEEK_API_KEY'];
  if (key == null || key.trim().isEmpty) {
    stderr.writeln('请先设置 DEEPSEEK_API_KEY');
    exitCode = 2;
    return;
  }
  final canvas = images.Image(width: 320, height: 120);
  images.fill(canvas, color: images.ColorRgb8(255, 255, 255));
  images.drawString(
    canvas,
    'AGENT 42',
    font: images.arial48,
    x: 24,
    y: 28,
    color: images.ColorRgb8(0, 0, 0),
  );
  final image = ImageInput.fromBytes(
    Uint8List.fromList(images.encodePng(canvas)),
    name: 'agent-vision-check.png',
  );
  final files = DeepSeekFilesClient(credentials: (_) => key);
  UploadedImage? uploaded;
  try {
    uploaded = await files.upload(image, lifetime: const Duration(hours: 1));
    for (final profile in AgentConfiguration.deepSeek().profiles) {
      for (final effort in [ReasoningEffort.off, ReasoningEffort.low]) {
        final model = HttpAgentModel(profile: profile, credentials: (_) => key);
        try {
          final response = await model.complete(
            ModelRequest(
              systemPrompt: '准确识别图片文字，简短回答。',
              messages: [
                UserMessage.withContent(
                  content: [
                    const TextBlock(text: '图片上写了什么？只返回看到的英文和数字。'),
                    uploaded.block,
                  ],
                ),
              ],
              tools: [],
              reasoningEffort: effort,
              maxOutputTokens: 2048,
            ),
            CancellationToken(),
          );
          final answer = response.message.text;
          if (response.stopReason != ModelStopReason.completed ||
              !answer.toUpperCase().contains('AGENT') ||
              !answer.contains('42')) {
            throw StateError(
              '视觉验收未通过：${profile.protocol.name}/${effort.name}，${response.stopReason.name}，$answer',
            );
          }
          print(
            jsonEncode({
              'protocol': profile.protocol.name,
              'thinking': effort.name,
              'answer': answer,
              'input': response.usage.inputTokens,
              'output': response.usage.outputTokens,
            }),
          );
        } finally {
          model.close();
        }
      }
    }
  } finally {
    try {
      if (uploaded != null) {
        await files.delete(uploaded.id);
        print('本次云端测试图片已删除');
      }
    } finally {
      files.close();
    }
  }
}
