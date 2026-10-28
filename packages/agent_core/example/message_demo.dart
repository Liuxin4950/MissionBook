import 'package:agent_core/agent_core.dart';

void main() {
  // 调试入口暂时提供文字；接入页面后，文字将来自用户输入。
  const text = TextBlock(text: '我今天有两个小时，想学习 Flutter。');

  // 列表声明接收 ContentBlock，TextBlock 是其中一种具体内容。
  final content = <ContentBlock>[text];

  print('内容块数量：${content.length}');
  print('文字：${text.text}');
}
