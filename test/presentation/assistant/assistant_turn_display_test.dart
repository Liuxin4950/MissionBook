import 'package:agent_core/agent_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/presentation/assistant/shared/assistant_turn_display.dart';

void main() {
  test('同一消息的回答、思考和后续回答不被重排', () {
    final message = AssistantMessage(
      content: const [
        TextBlock(text: '先说明'),
        ThinkingBlock(text: '再核对'),
        TextBlock(text: '最后回答'),
      ],
      provider: 'test',
      model: 'test',
    );
    final sections = assistantTurnSections(message, 'request-1');
    expect(sections.map((section) => section.process), [false, true, false]);
    expect(
      sections.expand((section) => section.parts).map((part) => part.index),
      [0, 1, 2],
    );
  });
}
