import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
  test('事实版本相同保留回答，版本变化后清理派生答案与摘要并可重开导入', () async {
    final requests = <ModelRequest>[];
    final runtime = testRuntime(
      configuration: testConfiguration(
        context: ContextPolicy(keepRecentMessages: 2, headroomTokens: 64),
      ),
      main: (request, _) {
        requests.add(request);
        return textReply('旧偏好赤杉6814');
      },
      summary: (_, _) => textReply('旧偏好赤杉6814'),
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession(id: 'revision');
    await session.replaceContext(
      source: 'memory',
      text: '赤杉6814',
      sourceRevision: '0',
    );
    await session.send('请按已知个人信息回答');
    await session.replaceContext(
      source: 'memory',
      text: '本轮另一个话题，但事实未变',
      sourceRevision: '0',
    );
    expect(
      session.contextMessages.map((m) => m.text).join(),
      contains('赤杉6814'),
    );
    await session.send('背景${'资料。' * 1000}');
    await session.send('继续');
    expect(await session.compact(), isNotNull);
    await session.replaceContext(
      source: 'memory',
      text: '新的偏好',
      sourceRevision: '1',
    );
    expect(
      session.contextMessages.map((m) => m.text).join(),
      isNot(contains('赤杉6814')),
    );
    expect(session.transcript.map((m) => m.text).join(), contains('赤杉6814'));
    await session.close();
    final reopened = await runtime.openSession('revision');
    final imported = await runtime.importSession(
      await reopened.export(),
      id: 'imported-revision',
    );
    expect(
      imported.contextMessages.map((m) => m.text).join(),
      isNot(contains('赤杉6814')),
    );
    expect(
      imported.contextMessages.whereType<ContextMessage>().last.sourceRevision,
      '1',
    );
  });

  for (final name in [
    'getMemory',
    'saveMemory',
    'manageMemory',
    'getOperation',
  ]) {
    test('$name 的旧调用参数、结果和回答一起失效', () async {
      var called = false;
      final runtime = testRuntime(
        tools: [
          AgentTool(
            definition: ToolDefinition(
              name: name,
              description: '记忆验收',
              inputSchema: {'type': 'object'},
            ),
            execute: (_, _) => const ToolOutput.success('旧偏好赤杉6814'),
          ),
        ],
        main: (_, _) {
          if (!called) {
            called = true;
            return toolReply(
              'old-call',
              name: name,
              input: {'content': '赤杉6814'},
            );
          }
          return textReply('根据旧结果赤杉6814作答');
        },
      );
      addTearDown(runtime.close);
      final session = await runtime.createSession();
      await session.send('仅执行已授权的验收操作');
      await session.invalidateToolResults(toolNames: {name});
      final visible = session.contextMessages;
      expect(visible.map((m) => m.text).join(), isNot(contains('赤杉6814')));
      expect(
        visible
            .whereType<AssistantMessage>()
            .expand((m) => m.toolCalls)
            .single
            .input,
        isEmpty,
      );
      expect(
        session.transcript
            .whereType<AssistantMessage>()
            .expand((m) => m.toolCalls)
            .single
            .input['content'],
        '赤杉6814',
      );
      await session.close();
    });
  }

  test('未知写入核对的通知按原工具失效，原回执仍可恢复', () async {
    final runtime = testRuntime(
      main: (_, _) => toolReply(
        'unknown-save',
        name: 'saveMemory',
        input: {'content': '赤杉6814'},
      ),
      tools: [
        AgentTool(
          definition: ToolDefinition(
            name: 'saveMemory',
            description: '写入验收',
            inputSchema: {'type': 'object'},
          ),
          execute: (_, _) => throw StateError('模拟提交后连接中断'),
        ),
      ],
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession();
    await session.send('执行验收操作');
    expect(session.needsOutcomeResolution, isTrue);
    await session.resolveToolOutcome(
      'unknown-save',
      const ToolOutput.success('赤杉6814已保存'),
      source: 'recovery',
    );
    await session.invalidateToolResults(toolNames: {'saveMemory'});
    expect(
      session.contextMessages.map((m) => m.text).join(),
      isNot(contains('赤杉6814')),
    );
    expect(session.resolvedOutcomes['unknown-save']!.text, contains('赤杉6814'));
    await session.close();
  });

  test('超长成功和失败输出有 UTF-8 硬上限，保持状态、编号和合法 Unicode', () {
    for (final output in [
      ToolOutput.success(
        jsonEncode({
          'status': 'updated',
          'id': 'stable-id',
          'resultId': 'receipt',
          'content': '中😀\n"' * 30000,
        }),
      ),
      ToolOutput.failure('conflict', '中😀\n"' * 30000),
    ]) {
      final bounded = output.bounded();
      expect(
        utf8.encode(bounded.text).length,
        lessThanOrEqualTo(ToolOutput.maxTextBytes),
      );
      expect(bounded.isError, output.isError);
      expect(bounded.errorCode, output.errorCode);
      final value = jsonDecode(bounded.text) as Map;
      expect(value['truncated'], isTrue);
      expect(value['preview'], isNot(contains('\uFFFD')));
      if (!output.isError) {
        expect(value['status'], 'updated');
        expect(value['id'], 'stable-id');
        expect(value['resultId'], 'receipt');
      }
    }
  });

  test('写工具返回超长结果后只执行一次并持久化为成功', () async {
    var writes = 0;
    final runtime = testRuntime(
      main: (request, _) => request.messages.last is ToolResultMessage
          ? textReply('已确认成功')
          : toolReply('one-write', name: 'save'),
      tools: [
        AgentTool(
          definition: ToolDefinition(
            name: 'save',
            description: '长回执',
            inputSchema: {'type': 'object'},
          ),
          execute: (_, _) {
            writes++;
            return ToolOutput.success(
              jsonEncode({
                'status': 'updated',
                'id': 'one',
                'data': '长' * 40000,
              }),
            );
          },
        ),
      ],
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession();
    expect((await session.send('执行一次写入')).reason, AgentStopReason.completed);
    expect(writes, 1);
    expect(session.needsOutcomeResolution, isFalse);
    final result = session.transcript.whereType<ToolResultMessage>().single;
    expect(result.isError, isFalse);
    expect(
      utf8.encode(result.text).length,
      lessThanOrEqualTo(ToolOutput.maxTextBytes),
    );
    await session.close();
  });
}
