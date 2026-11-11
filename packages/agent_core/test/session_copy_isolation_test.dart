import 'package:agent_core/agent_core.dart';
import 'package:agent_core/src/sessions/message_codec.dart';
import 'package:agent_core/src/sessions/session_state.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 11);
  SessionRecord record(int sequence, String type, Map<String, Object?> data) =>
      SessionRecord(sequence: sequence, timestamp: now, type: type, data: data);
  SessionState seed() => SessionState.fromRecords([
    record(0, 'session_created', {
      'id': 'test',
      'title': 'test',
      'createdAt': now.toIso8601String(),
      'systemPrompt': 'test',
      'modelProfileId': 'main',
      'summaryProfileId': 'summary',
    }),
  ]);
  test('预校验分支和已接受状态可分别写消息，两个方向都不污染', () {
    final accepted = seed();
    accepted.apply(record(1, 'turn_started', {'turnId': 'turn'}));
    final candidate = accepted.copy();
    candidate.apply(
      record(2, 'message_added', {
        'message': encodeMessage(UserMessage(id: 'candidate', text: '未持久化')),
      }),
    );
    expect(accepted.transcript, isEmpty);
    accepted.apply(
      record(2, 'message_added', {
        'message': encodeMessage(UserMessage(id: 'accepted', text: '已接受')),
      }),
    );
    expect(candidate.transcript.single.id, 'candidate');
    expect(accepted.transcript.single.id, 'accepted');
    expect(candidate.messageById('accepted'), isNull);
    expect(accepted.messageById('candidate'), isNull);
  });
  test('分支记录工具开始不修改原调用集合；坏分支丢弃后仍可继续', () {
    final accepted = seed();
    accepted.apply(record(1, 'turn_started', {'turnId': 'turn'}));
    accepted.apply(
      record(2, 'message_added', {
        'message': encodeMessage(
          AssistantMessage(
            id: 'assistant',
            provider: 'test',
            model: 'main',
            content: [
              ToolCallBlock(id: 'write', name: 'write', input: {'value': 1}),
            ],
          ),
        ),
      }),
    );
    final candidate = accepted.copy();
    candidate.apply(
      record(3, 'tool_execution_started', {
        'callId': 'write',
        'input': {'value': 2},
        'readOnly': false,
      }),
    );
    expect(accepted.startedCallIds, isEmpty);
    expect(accepted.executedCalls, isEmpty);
    expect(candidate.executedCalls['write']!.input['value'], 2);
    final failed = accepted.copy();
    expect(
      () => failed.apply(
        record(3, 'tool_execution_started', {'callId': 'missing'}),
      ),
      throwsFormatException,
    );
    expect(accepted.startedCallIds, isEmpty);
    accepted.apply(
      record(3, 'tool_execution_started', {
        'callId': 'write',
        'readOnly': true,
      }),
    );
    expect(accepted.readOnlyCallIds, contains('write'));
    expect(candidate.readOnlyCallIds, isEmpty);
  });
}
