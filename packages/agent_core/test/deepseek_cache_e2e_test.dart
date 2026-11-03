import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

const _system =
    'You are a terse coding assistant used in an automated cache test. '
    'Always follow instructions literally and exactly. When the user asks you to look '
    'something up, call the lookup tool with the requested key and wait for its result '
    'before answering. Never invent a value the tool has not returned. After the tool '
    'returns, answer with a single short sentence that repeats the returned value '
    'verbatim. Do not add explanations, do not use markdown, do not ask follow-up '
    'questions. If the user asks anything else, answer in one short sentence.';

void main() {
  final key = Platform.environment['DEEPSEEK_API_KEY'];
  test(
    '真实 DeepSeek 请求在首个请求后命中前缀缓存',
    () async {
      final base = AgentConfiguration.deepSeek();
      final profile = ModelProfile.fromJson({
        ...base.profile('deepseek-chat').toJson(),
        'maxOutputTokens': 512,
        'reasoningEffort': 'off',
        'temperature': 0,
        'retry': {'maxRetries': 0},
      });
      final runtime = AgentRuntime(
        configuration: AgentConfiguration(
          profiles: [profile],
          defaultModelProfile: profile.id,
          maxSteps: 4,
          maxRunDuration: const Duration(minutes: 4),
        ),
        store: MemorySessionStore(),
        credentials: (_) => key,
        tools: [
          AgentTool(
            definition: ToolDefinition(
              name: 'lookup',
              description: 'Look up the stored value for a key.',
              inputSchema: {
                'type': 'object',
                'properties': {
                  'key': {'type': 'string', 'description': 'Key to look up.'},
                },
                'required': ['key'],
                'additionalProperties': false,
              },
            ),
            execute: (input, context) =>
                ToolOutput.success('value(${input['key']}) = azure-falcon-42'),
          ),
        ],
        authorize: (tool, call, token) => const ToolDecision.allow(),
      );
      addTearDown(runtime.close);
      final session = await runtime.createSession(
        id: 'cache-e2e',
        systemPrompt: _system,
      );
      final first = await session.send(
        'Use the lookup tool with key "deploy-color" and tell me the value.',
      );
      expect(
        first.reason,
        AgentStopReason.completed,
        reason: first.failure?.message,
      );
      expect(first.answer, contains('azure-falcon-42'));
      final second = await session.send(
        'Thanks. Repeat that value one more time.',
      );
      expect(
        second.reason,
        AgentStopReason.completed,
        reason: second.failure?.message,
      );
      expect(second.answer, contains('azure-falcon-42'));

      final usages = (await session.readRecords())
          .where((record) => record.type == 'usage_reported')
          .where((record) => record.data['purpose'] == 'conversation')
          .where((record) => record.data['complete'] == true)
          .map(
            (record) => TokenUsage.fromJson(
              Map<String, Object?>.from(record.data['usage']! as Map),
            ),
          )
          .toList();
      expect(usages.length, greaterThanOrEqualTo(3));
      for (final usage in usages.skip(1)) {
        expect(usage.cachedInputTokens, greaterThan(0), reason: '后续请求应命中前缀缓存');
      }
      expect(session.sessionUsage.cacheComplete, isTrue);
      expect(session.sessionUsage.cacheHitRate, greaterThan(0));
    },
    skip: key == null || key.isEmpty ? '需要 DEEPSEEK_API_KEY' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
