import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:agent_core/src/sessions/message_codec.dart';
import 'package:agent_core/src/message.dart' show validateConversation;
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
  for (final automatic in [false, true]) {
    test('记忆工具投影失效后${automatic ? '自动' : '手动'}压缩、重开与导入不回流', () async {
      final store = MemorySessionStore();
      final summaries = <ModelRequest>[];
      final requests = <ModelRequest>[];
      var queried = false;
      final runtime = testRuntime(
        store: store,
        configuration: testConfiguration(
          window: automatic ? 2600 : 24000,
          context: ContextPolicy(
            enabled: automatic,
            headroomTokens: 64,
            summaryMaxTokens: 128,
            keepRecentMessages: 2,
          ),
        ),
        tools: [
          AgentTool(
            definition: ToolDefinition(
              name: 'getMemory',
              description: '查询记忆',
              inputSchema: {'type': 'object'},
            ),
            readOnly: true,
            execute: (_, _) => ToolOutput.success('旧记忆：42路公交'),
          ),
        ],
        main: (request, _) {
          requests.add(request);
          if (!queried) {
            queried = true;
            return toolReply('memory-call', name: 'getMemory');
          }
          if (request.messages.last is ToolResultMessage) {
            return textReply('记住了42路公交');
          }
          return textReply('无关业务已完成');
        },
        summary: (request, _) {
          summaries.add(request);
          return textReply(
            request.messages.any((m) => m.text.contains('42路'))
                ? '查询事实：42路公交'
                : '保留用户迁移约束与无关业务',
          );
        },
      );
      addTearDown(runtime.close);
      final session = await runtime.createSession(id: 'memory-projection');
      // 先模拟尚未接入刷新接口的旧会话，生成确实引用工具结果的摘要。
      await session.send('用户原话：迁移时禁止删除业务');
      await session.send('资料${'背景。' * 500}');
      await session.send('继续');
      await session.compact();
      expect(
        session.contextMessages.whereType<ContextSummaryMessage>().any(
          (m) => m.text.contains('42路'),
        ),
        isTrue,
      );
      await session.invalidateToolResults(toolNames: {'getMemory'});
      expect(
        session.transcript.whereType<ToolResultMessage>().single.text,
        contains('42路'),
      );
      expect(
        session.contextMessages.map((m) => m.text).join(),
        isNot(contains('42路')),
      );
      expect(
        session.contextMessages.whereType<UserMessage>().map((m) => m.text),
        contains('用户原话：迁移时禁止删除业务'),
      );
      validateConversation(session.contextMessages);
      summaries.clear();
      for (var i = 0; i < 3; i++) {
        await session.send('忘记之后$i${'新资料。' * 240}');
      }
      if (!automatic) await session.compact();
      expect(summaries, isNotEmpty);
      for (final request in summaries) {
        expect(
          request.messages.map((m) => m.text).join(),
          isNot(contains('42路')),
        );
      }
      await session.close();
      final reopened = await runtime.openSession('memory-projection');
      await reopened.send('重开后确认');
      expect(
        requests.last.messages.map((m) => m.text).join(),
        isNot(contains('42路')),
      );
      validateConversation(requests.last.messages);
      final imported = await runtime.importSession(
        await reopened.export(),
        id: 'imported',
      );
      expect(
        imported.contextMessages.map((m) => m.text).join(),
        isNot(contains('42路')),
      );
      expect(
        imported.transcript.whereType<ToolResultMessage>().single.text,
        contains('42路'),
      );
    });
  }

  test('未知结果核对通知保留来源并可进入摘要，不永久占用上下文', () async {
    var called = false;
    final summaries = <ModelRequest>[];
    final runtime = testRuntime(
      configuration: testConfiguration(
        context: ContextPolicy(
          enabled: false,
          headroomTokens: 64,
          keepRecentMessages: 2,
          summaryMaxTokens: 128,
        ),
      ),
      tools: [
        AgentTool(
          definition: ToolDefinition(
            name: 'write',
            description: '业务写入',
            inputSchema: {'type': 'object'},
          ),
          execute: (_, _) => throw StateError('响应丢失'),
        ),
      ],
      main: (_, _) {
        if (!called) {
          called = true;
          return toolReply('unknown-write', name: 'write');
        }
        return textReply('继续业务');
      },
      summary: (request, _) {
        summaries.add(request);
        return textReply('来源：业务回查；unknown-write 已核对成功，继续业务。');
      },
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession();
    await session.send('执行业务写入');
    expect(session.needsOutcomeResolution, isTrue);
    await session.resolveToolOutcome(
      'unknown-write',
      ToolOutput.success('已成功'),
      source: '业务回查',
    );
    final notice = session.contextMessages.whereType<ContextMessage>().single;
    expect(notice.isPinned, isFalse);
    await session.send('后续${'业务资料。' * 400}');
    await session.send('收尾');
    final result = await session.compact();
    expect(result, isNotNull);
    expect(result!.summary.summarizedMessageIds, contains(notice.id));
    expect(
      result.contextMessages.any((message) => message.id == notice.id),
      isFalse,
    );
    expect(
      summaries
          .expand((request) => request.messages)
          .whereType<ContextMessage>()
          .single
          .source,
      '业务回查',
    );
    final id = session.id;
    await session.close();
    final reopened = await runtime.openSession(id);
    expect(
      reopened.contextMessages.whereType<ContextSummaryMessage>().single.isSafe,
      isTrue,
    );
    expect(
      reopened.transcript.whereType<ContextMessage>().single.source,
      '业务回查',
    );
  });

  test('读取会话记录必须声明格式版本', () {
    final data = {
      'sequence': 0,
      'timestamp': DateTime.utc(2026).toIso8601String(),
      'type': 'message_added',
      'data': <String, Object?>{},
    };
    expect(() => SessionRecord.fromJson(data), throwsFormatException);
    expect(SessionRecord.fromJson({...data, 'version': 1}).version, 1);
  });
  test('批准参数先入日志，未知结果重开后保留，模型原调用不改写', () async {
    final store = MemorySessionStore();
    Map<String, Object?>? written;
    final tool = AgentTool(
      definition: ToolDefinition(
        name: 'write',
        description: '写入',
        inputSchema: {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
          },
          'required': ['title'],
        },
      ),
      execute: (input, _) {
        written = input;
        throw StateError('模拟提交后断开');
      },
    );
    final runtime = AgentRuntime(
      configuration: testConfiguration(),
      store: store,
      credentials: (_) => null,
      tools: [tool],
      authorize: (_, _, _) => ToolDecision.allowWithInput({'title': '用户批准值'}),
      modelOverrides: {
        'main': CallbackModel(
          (_, _) => toolReply(
            'approved-call',
            name: 'write',
            input: {'title': '模型原值'},
          ),
        ),
      },
    );
    final session = await runtime.createSession(id: 'approved-session');
    await session.send('请修改');
    expect(written?['title'], '用户批准值');
    expect(session.needsOutcomeResolution, isTrue);
    expect(session.executedCalls['approved-call']?.input['title'], '用户批准值');
    expect(
      session.transcript
          .whereType<AssistantMessage>()
          .single
          .toolCalls
          .single
          .input['title'],
      '模型原值',
    );
    final started = (await session.readRecords()).singleWhere(
      (record) => record.type == 'tool_execution_started',
    );
    expect((started.data['input'] as Map)['title'], '用户批准值');
    await runtime.close();
    final restoredRuntime = testRuntime(store: store);
    final restored = await restoredRuntime.openSession('approved-session');
    expect(restored.needsOutcomeResolution, isTrue);
    expect(restored.executedCalls['approved-call']?.input['title'], '用户批准值');
    await restoredRuntime.close();
  });

  test('会话持有多轮历史，关闭重开后继续，配置变化和来源均保留', () async {
    final store = MemorySessionStore();
    final runtime = testRuntime(
      store: store,
      main: (request, token) {
        expect(request.systemPrompt, contains('新的系统提示'));
        expect(request.messages.first, isA<ContextMessage>());
        return textReply(
          '已有 ${request.messages.whereType<UserMessage>().length} 次用户输入',
        );
      },
    );
    final session = await runtime.createSession(id: 'conversation');
    await session.setSystemPrompt('新的系统提示：区分事实和推测');
    await session.injectContext(source: '用户配置的资料', text: '背景内容');
    expect((await session.send('第一句')).answer, '已有 1 次用户输入');
    final stableIds = session.transcript.map((message) => message.id).toList();
    await session.close();
    final reopened = await runtime.openSession('conversation');
    expect(reopened.transcript.map((message) => message.id), stableIds);
    expect((await reopened.send('第二句')).answer, '已有 2 次用户输入');
    await reopened.selectModels(conversation: 'summary', summary: 'main');
    expect(reopened.modelProfileId, 'summary');
    expect(reopened.summaryProfileId, 'main');
    expect(await runtime.listSessionIds(), ['conversation']);
    await runtime.close();
  });

  test('自动压缩后原文仍可按编号读取，重开和导出导入保持相同投影', () async {
    final store = MemorySessionStore();
    final runtime = testRuntime(
      store: store,
      configuration: testConfiguration(
        window: 3000,
        context: ContextPolicy(
          headroomTokens: 64,
          summaryMaxTokens: 128,
          keepRecentMessages: 1,
        ),
      ),
    );
    final session = await runtime.createSession(id: 'compressed');
    await session.send('早期资料：${'用户明确约束' * 480}');
    final first = session.transcript.first;
    final result = await session.send('当前要求：我还有两小时，请继续。');
    expect(result.reason, AgentStopReason.completed);
    expect(result.compactions, 1);
    expect(session.messageById(first.id)?.text, first.text);
    expect(session.transcript, hasLength(4));
    final projectionIds = session.contextMessages
        .map((message) => message.id)
        .toList();
    final exported = await session.export();
    final imported = await runtime.importSession(exported, id: 'copy');
    expect(
      imported.contextMessages.map((message) => message.id),
      projectionIds,
    );
    expect(imported.messageById(first.id)?.text, first.text);
    await session.close();
    final reopened = await runtime.openSession('compressed');
    expect(
      reopened.contextMessages.map((message) => message.id),
      projectionIds,
    );
    expect(
      reopened.transcript.map((message) => message.id),
      imported.transcript.map((message) => message.id),
    );
    await runtime.close();
  });

  for (final automatic in [false, true]) {
    test('${automatic ? '自动' : '手动'}压缩保留当前记忆，重开后可见且替换与遗忘不复活旧块', () async {
      final requests = <ModelRequest>[];
      final summaries = <ModelRequest>[];
      final runtime = testRuntime(
        configuration: testConfiguration(
          window: 3000,
          context: ContextPolicy(
            enabled: automatic,
            headroomTokens: 64,
            summaryMaxTokens: 128,
            keepRecentMessages: 1,
          ),
        ),
        main: (request, token) {
          requests.add(request);
          return textReply('收到');
        },
        summary: (request, token) {
          summaries.add(request);
          return textReply('旧对话已压缩。');
        },
      );
      addTearDown(runtime.close);
      final session = await runtime.createSession();
      final compactions = <ContextCompaction>[];
      final subscription = session.events.listen((event) {
        if (event is ContextCompacted) compactions.add(event.compaction);
      });
      addTearDown(subscription.cancel);
      Iterable<ContextMessage> memory(Iterable<AgentMessage> messages) =>
          messages.whereType<ContextMessage>().where(
            (message) => message.source == 'mission_book_memory',
          );
      await session.replaceContext(
        source: 'mission_book_memory',
        text: '当前有效记忆：用户每天早上七点起床',
      );
      final current = memory(session.transcript).single;
      await session.send('早期资料：${'用户明确约束' * 480}');
      final turn = await session.send('当前要求：请继续整理。');
      expect(turn.reason, AgentStopReason.completed);
      ContextCompaction compaction;
      if (automatic) {
        expect(turn.compactions, 1);
        await Future<void>.delayed(Duration.zero);
        compaction = compactions.single;
      } else {
        expect(turn.compactions, 0);
        final result = await session.compact();
        expect(result, isNotNull);
        compaction = result!;
      }
      final memoryMessages = memory(session.transcript).toList();
      expect(memoryMessages, isNotEmpty);
      expect(memoryMessages.last.id, current.id);
      expect(memory(compaction.contextMessages).single.id, current.id);
      expect(memory(session.contextMessages).single.id, current.id);
      expect(
        compaction.summary.summarizedMessageIds,
        isNot(contains(current.id)),
      );
      final saved = (await session.readRecords()).singleWhere(
        (record) => record.type == 'context_compacted',
      );
      expect(saved.data['supplyExcluded'], isTrue);
      expect(saved.data['contextMessageIds'] as List, contains(current.id));
      final ids = session.contextMessages.map((message) => message.id).toList();
      final imported = await runtime.importSession(await session.export());
      expect(imported.contextMessages.map((message) => message.id), ids);
      expect(memory(imported.transcript).single.id, current.id);
      await imported.close();
      await session.close();
      var reopened = await runtime.openSession(session.id);
      expect(reopened.contextMessages.map((message) => message.id), ids);
      expect(memory(reopened.transcript).single.id, current.id);
      await reopened.send('压缩后继续');
      expect(memory(requests.last.messages).single.id, current.id);
      await reopened.replaceContext(
        source: 'mission_book_memory',
        text: '当前有效记忆：用户每天早上八点起床',
      );
      await reopened.send('采用更正后的记忆');
      expect(memory(requests.last.messages).single.text, contains('八点'));
      expect(
        memory(requests.last.messages).map((m) => m.id),
        isNot(contains(current.id)),
      );
      await reopened.send('新增资料：${'后续对话' * 480}');
      final second = await reopened.compact();
      expect(second, isNotNull);
      expect(memory(second!.contextMessages).single.text, contains('八点'));
      expect(
        second.contextMessages.whereType<ContextSummaryMessage>().single.id,
        isNot(compaction.summary.id),
      );
      await reopened.replaceContext(source: 'mission_book_memory', text: null);
      await reopened.close();
      reopened = await runtime.openSession(session.id);
      expect(memory(reopened.contextMessages), isEmpty);
      expect(memory(reopened.transcript), hasLength(2));
      await reopened.send('忘记后继续');
      expect(memory(requests.last.messages), isEmpty);
      for (final request in summaries) {
        expect(request.messages.whereType<ContextMessage>(), isEmpty);
        expect(
          request.messages.whereType<ContextSummaryMessage>().every(
            (summary) => summary.isSafe,
          ),
          isTrue,
        );
        expect(
          request.messages.map((message) => message.text).join('\n'),
          isNot(anyOf(contains('七点'), contains('八点'))),
        );
      }
    });
  }

  test('分支可以选择已完成消息边界，导入后的分支仍可再次分支', () async {
    final runtime = testRuntime();
    final session = await runtime.createSession(id: 'source');
    await session.send('第一句');
    final boundary = session.transcript.last.id;
    await session.send('第二句');
    final branch = await session.fork(throughMessageId: boundary);
    expect(branch.transcript, hasLength(2));
    final nextBranch = await branch.fork(throughMessageId: boundary);
    expect(nextBranch.transcript, hasLength(2));
    await nextBranch.send('分支的新输入');
    expect(session.transcript, hasLength(4));
    expect(branch.transcript, hasLength(2));
    await runtime.close();
  });

  test('中断的模型请求可以继续，用户输入不会追加第二次', () async {
    final store = MemorySessionStore();
    final firstRuntime = testRuntime(store: store);
    final initial = await firstRuntime.createSession(id: 'interrupted-model');
    await initial.close();
    final handle = await store.open('interrupted-model');
    await handle.append('turn_started', {'turnId': 'lost', 'resume': false});
    await handle.append('message_added', {
      'message': encodeMessage(UserMessage(text: '已接收但未回答')),
    });
    await handle.close();
    final reopened = await firstRuntime.openSession('interrupted-model');
    final result = await reopened.resume();
    expect(result.reason, AgentStopReason.completed);
    expect(reopened.transcript.whereType<UserMessage>(), hasLength(1));
    expect(
      (await reopened.readRecords())
          .where((record) => record.type == 'turn_ended')
          .first
          .data['reason'],
      'interrupted',
    );
    await firstRuntime.close();
  });

  for (final started in [false, true]) {
    test('恢复${started ? '已开始' : '未开始'}工具：不自动重放，未知结果必须先核对', () async {
      final store = MemorySessionStore();
      var executions = 0;
      final runtime = testRuntime(
        store: store,
        tools: [
          readTool((input, context) {
            executions++;
            return const ToolOutput.success('真实结果');
          }),
        ],
      );
      final initial = await runtime.createSession(id: 'recovery-$started');
      await initial.close();
      final handle = await store.open('recovery-$started');
      await handle.append('turn_started', {'turnId': 'lost'});
      await handle.append('message_added', {
        'message': encodeMessage(UserMessage(text: '查询')),
      });
      await handle.append('message_added', {
        'message': encodeMessage(toolReply('a').message),
      });
      if (started) {
        await handle.append('tool_execution_started', {'callId': 'a'});
      }
      await handle.close();
      final recovered = await runtime.openSession('recovery-$started');
      expect(executions, 0);
      expect(recovered.needsOutcomeResolution, started);
      if (started) {
        await expectLater(recovered.send('继续'), throwsStateError);
        await recovered.resolveToolOutcome(
          'a',
          const ToolOutput.success('已从实际来源确认'),
          source: '宿主查询',
        );
        expect(recovered.needsOutcomeResolution, isFalse);
        expect(recovered.transcript.last, isA<ContextMessage>());
      }
      expect((await recovered.resume()).reason, AgentStopReason.completed);
      expect(executions, 0);
      await runtime.close();
    });
  }

  test('工具未预期异常也需要核对，不能直接开启下一轮', () async {
    final runtime = testRuntime(
      main: (request, token) => toolReply('broken'),
      tools: [readTool((input, context) => throw StateError('写后异常'))],
    );
    final session = await runtime.createSession();
    final result = await session.send('修改');
    expect(result.failure?.code, 'tool_outcome_unknown');
    expect(session.needsOutcomeResolution, isTrue);
    await expectLater(session.send('重试'), throwsStateError);
    expect(
      (await session.readRecords()).where(
        (record) => record.type == 'tool_execution_started',
      ),
      hasLength(1),
    );
    await runtime.close();
  });

  test('工具开始记录保存失败时绝不执行；结果保存失败时保留进程中的真实结果', () async {
    for (final afterExecution in [false, true]) {
      final inner = MemorySessionStore();
      final store = _FailingStore(
        inner,
        (type, data) => afterExecution
            ? type == 'message_added' &&
                  (data['message'] as Map<String, Object?>)['role'] == 'tool'
            : type == 'tool_execution_started',
      );
      var executed = 0;
      final runtime = testRuntime(
        store: store,
        main: (request, token) => toolReply('write'),
        tools: [
          readTool((input, context) {
            executed++;
            return const ToolOutput.success('确实已经提交');
          }),
        ],
      );
      final session = await runtime.createSession(id: 'failed-write');
      final result = await session.send('操作');
      expect(result.failure?.code, 'persistence_failed');
      expect(executed, afterExecution ? 1 : 0);
      if (afterExecution) {
        expect(
          result.messages.whereType<ToolResultMessage>().single.text,
          '确实已经提交',
        );
      }
      await expectLater(session.send('继续'), throwsStateError);
      await runtime.close();
      final readerRuntime = testRuntime(store: inner);
      final recovered = await readerRuntime.openSession('failed-write');
      expect(recovered.needsOutcomeResolution, afterExecution);
      await readerRuntime.close();
    }
  });

  test('取消收尾的存储失败也返回失败，不假报已保存的取消', () async {
    final entered = Completer<void>();
    final runtime = testRuntime(
      store: _FailingStore(
        MemorySessionStore(),
        (type, data) => type == 'turn_ended',
      ),
      main: (request, token) {
        entered.complete();
        return Completer<ModelResponse>().future;
      },
    );
    final session = await runtime.createSession();
    final pending = session.send('等待');
    await entered.future;
    session.cancel();
    expect((await pending).failure?.code, 'persistence_failed');
    await runtime.close();
  });

  test('旧摘要不再进入模型可见上下文', () async {
    final store = MemorySessionStore();
    final now = DateTime.now().toUtc();
    final handle = await store.create(
      'legacy-summary',
      initialRecords: [
        SessionRecord(
          sequence: 0,
          timestamp: now,
          type: 'session_created',
          data: {
            'id': 'legacy-summary',
            'title': '旧会话',
            'createdAt': now.toIso8601String(),
            'systemPrompt': '系统说明',
            'modelProfileId': 'main',
            'summaryProfileId': 'summary',
          },
        ),
        SessionRecord(
          sequence: 1,
          timestamp: now,
          type: 'turn_started',
          data: {'turnId': 't1'},
        ),
        SessionRecord(
          sequence: 2,
          timestamp: now,
          type: 'message_added',
          data: {
            'message': {
              'id': 'user',
              'role': 'user',
              'content': [
                {'type': 'text', 'text': '我喜欢什么？'},
              ],
            },
          },
        ),
        SessionRecord(
          sequence: 3,
          timestamp: now,
          type: 'message_added',
          data: {
            'message': {
              'id': 'assistant',
              'role': 'assistant',
              'provider': 'test',
              'model': 'scripted',
              'content': [
                {'type': 'text', 'text': '你早上跑步。'},
              ],
            },
          },
        ),
        SessionRecord(
          sequence: 4,
          timestamp: now,
          type: 'turn_ended',
          data: {'turnId': 't1', 'reason': 'completed'},
        ),
        SessionRecord(
          sequence: 5,
          timestamp: now,
          type: 'message_added',
          data: {
            'message': {
              'id': 'old-memory',
              'role': 'context',
              'source': '记忆',
              'content': [
                {'type': 'text', 'text': '用户对花生过敏'},
              ],
            },
          },
        ),
        SessionRecord(
          sequence: 6,
          timestamp: now,
          type: 'context_compacted',
          data: {
            'summary': {
              'id': 'summary',
              'role': 'summary',
              'summarizedMessageIds': ['user', 'assistant', 'old-memory'],
              'content': [
                {'type': 'text', 'text': '旧摘要：用户对花生过敏'},
              ],
            },
            'contextMessageIds': ['summary', 'assistant'],
          },
        ),
      ],
    );
    await handle.close();
    final runtime = testRuntime(store: store);
    final session = await runtime.openSession('legacy-summary');
    final visible = session.contextMessages
        .map((message) => message.text)
        .join('\n');
    expect(visible, isNot(contains('花生过敏')));
    expect(session.contextMessages.whereType<ContextSummaryMessage>(), isEmpty);
    expect(session.contextMessages.whereType<ContextMessage>(), isEmpty);
    expect(session.transcript.whereType<ContextMessage>(), isNotEmpty);
    await runtime.close();
  });

  for (final safeCompaction in [false, true]) {
    test('旧压缩之后的请求可回放，${safeCompaction ? '新安全投影' : '新供给块'}重开后仍保留', () async {
      final store = MemorySessionStore();
      final runtime = testRuntime(store: store);
      addTearDown(runtime.close);
      final session = await runtime.createSession();
      await session.replaceContext(
        source: 'mission_book_memory',
        text: '过期记忆：42路',
      );
      await session.send('早期对话');
      final oldMemory = session.transcript.whereType<ContextMessage>().single;
      final oldUser = session.transcript.whereType<UserMessage>().single;
      final oldAssistant = session.transcript
          .whereType<AssistantMessage>()
          .single;
      await session.close();
      final handle = await store.open(session.id);
      final legacy = ContextSummaryMessage(
        text: '旧摘要污染：42路',
        summarizedMessageIds: [oldUser.id, oldMemory.id],
      );
      await handle.append('context_compacted', {
        'summary': encodeMessage(legacy),
        'contextMessageIds': [legacy.id, oldAssistant.id],
      });
      final fresh = ContextMessage(
        source: 'mission_book_memory',
        text: '当前有效记忆：七点起床',
      );
      await handle.append('context_message_replaced', {
        'source': fresh.source,
        'previousIds': <String>[],
        'message': encodeMessage(fresh),
      });
      final user = UserMessage(text: '压缩后的下一轮');
      final assistant = textReply('已收到').message;
      await handle.append('turn_started', {'turnId': 'after-legacy'});
      await handle.append('message_added', {'message': encodeMessage(user)});
      await handle.append('request_prepared', {
        'purpose': 'conversation',
        'messageIds': [legacy.id, oldAssistant.id, fresh.id, user.id],
      });
      await handle.append('message_added', {
        'message': encodeMessage(assistant),
      });
      await handle.append('turn_ended', {
        'turnId': 'after-legacy',
        'reason': 'completed',
      });
      final safe = ContextSummaryMessage(
        text: '新的安全摘要',
        summarizedMessageIds: [user.id],
      );
      if (safeCompaction) {
        await handle.append('context_compacted', {
          'supplyExcluded': true,
          'summary': encodeMessage(safe),
          'contextMessageIds': [safe.id, fresh.id, assistant.id],
        });
      } else {
        await handle.append('turn_started', {'turnId': 'interrupted-legacy'});
        await handle.append('message_added', {
          'message': encodeMessage(UserMessage(text: '中断前的问题')),
        });
        await handle.append('message_added', {
          'message': encodeMessage(toolReply('pending-read').message),
        });
      }
      await handle.close();
      var reopened = await runtime.openSession(session.id);
      expect(
        (await reopened.readRecords()).where(
          (record) => record.type == 'context_projection_reset',
        ),
        hasLength(safeCompaction ? 0 : 1),
      );
      expect(
        reopened.transcript.whereType<ContextMessage>().map(
          (message) => message.id,
        ),
        [oldMemory.id, fresh.id],
      );
      expect(
        reopened.contextMessages.whereType<ContextMessage>().single.id,
        fresh.id,
      );
      expect(
        reopened.contextMessages.map((message) => message.text).join('\n'),
        isNot(contains('42路')),
      );
      expect(
        reopened.contextMessages.whereType<ContextSummaryMessage>().map(
          (m) => m.id,
        ),
        safeCompaction ? [safe.id] : isEmpty,
      );
      final ids = reopened.contextMessages
          .map((message) => message.id)
          .toList();
      final imported = await runtime.importSession(await reopened.export());
      expect(imported.contextMessages.map((message) => message.id), ids);
      await imported.close();
      expect((await reopened.send('继续')).reason, AgentStopReason.completed);
      await reopened.replaceContext(source: fresh.source, text: null);
      await reopened.close();
      reopened = await runtime.openSession(session.id);
      expect(reopened.contextMessages.whereType<ContextMessage>(), isEmpty);
      expect((await reopened.send('遗忘后继续')).reason, AgentStopReason.completed);
    });
  }

  test('运行中的轮次拒绝替换上下文', () async {
    final store = MemorySessionStore();
    final now = DateTime.now().toUtc();
    Map<String, Object?> contextMessage(String id, String text) => {
      'id': id,
      'role': 'context',
      'source': '记忆',
      'content': [
        {'type': 'text', 'text': text},
      ],
    };
    final handle = await store.create(
      'open-turn',
      initialRecords: [
        SessionRecord(
          sequence: 0,
          timestamp: now,
          type: 'session_created',
          data: {
            'id': 'open-turn',
            'title': '测试',
            'createdAt': now.toIso8601String(),
            'systemPrompt': '系统说明',
            'modelProfileId': 'main',
            'summaryProfileId': 'summary',
          },
        ),
        SessionRecord(
          sequence: 1,
          timestamp: now,
          type: 'turn_started',
          data: {'turnId': 't1'},
        ),
        SessionRecord(
          sequence: 2,
          timestamp: now,
          type: 'message_added',
          data: {'message': contextMessage('old', '旧块')},
        ),
        SessionRecord(
          sequence: 3,
          timestamp: now,
          type: 'context_message_replaced',
          data: {
            'source': '记忆',
            'previousIds': ['old'],
            'message': contextMessage('new', '新块'),
          },
        ),
      ],
    );
    await handle.close();
    final runtime = testRuntime(store: store);
    await expectLater(
      runtime.openSession('open-turn'),
      throwsA(isA<FormatException>()),
    );
    await runtime.close();
  });

  test('供给上下文不进入摘要，忘记后移除即不再出现在模型输入', () async {
    final summaries = <ModelRequest>[];
    final conversation = <ModelRequest>[];
    final runtime = testRuntime(
      configuration: testConfiguration(
        window: 3000,
        context: ContextPolicy(
          headroomTokens: 64,
          summaryMaxTokens: 128,
          keepRecentMessages: 1,
        ),
      ),
      main: (request, token) {
        conversation.add(request);
        return textReply('已回答');
      },
      summary: (request, token) {
        summaries.add(request);
        return textReply('摘要。');
      },
    );
    final session = await runtime.createSession();
    await session.replaceContext(source: '记忆', text: '用户对花生过敏');
    await session.send('早期资料：${'用户明确约束' * 480}');
    await session.replaceContext(source: '记忆', text: null);
    final result = await session.send('当前要求：我还有两小时，请继续。');
    expect(result.compactions, 1);
    expect(summaries, isNotEmpty);
    for (final request in [...summaries, conversation.last]) {
      expect(
        request.messages.map((message) => message.text).join('\n'),
        isNot(contains('花生过敏')),
      );
    }
    expect(
      session.contextMessages.whereType<ContextMessage>().where(
        (message) => message.source == '记忆',
      ),
      isEmpty,
    );
    await runtime.close();
  });

  test('同来源上下文只保留最新一份，移除后重开仍不注入', () async {
    final requests = <ModelRequest>[];
    final runtime = testRuntime(
      main: (request, token) {
        requests.add(request);
        return textReply('收到');
      },
    );
    final session = await runtime.createSession();
    List<String> memory(ModelRequest request) => request.messages
        .whereType<ContextMessage>()
        .where((message) => message.source == '记忆')
        .map((message) => message.text)
        .toList();
    await session.replaceContext(source: '记忆', text: '旧记忆');
    await session.send('第一句');
    expect(memory(requests.last), ['旧记忆']);
    await session.replaceContext(source: '记忆', text: '旧记忆');
    expect(
      (await session.readRecords()).where(
        (record) => record.type == 'context_message_replaced',
      ),
      hasLength(1),
    );
    await session.replaceContext(source: '记忆', text: '新记忆');
    await session.send('第二句');
    expect(memory(requests.last), ['新记忆']);
    expect(
      session.transcript
          .whereType<ContextMessage>()
          .where((message) => message.source == '记忆')
          .map((message) => message.text),
      ['旧记忆', '新记忆'],
    );
    await session.replaceContext(source: '记忆', text: null);
    await session.send('第三句');
    expect(memory(requests.last), isEmpty);
    await session.close();
    final reopened = await runtime.openSession(session.id);
    expect(
      reopened.contextMessages.whereType<ContextMessage>().where(
        (message) => message.source == '记忆',
      ),
      isEmpty,
    );
    await runtime.close();
  });

  test('元数据修改与运行不能并发，不同会话可独立工作', () async {
    final runtime = testRuntime();
    final first = await runtime.createSession();
    final second = await runtime.createSession();
    final change = first.injectContext(source: '资料', text: '背景');
    await expectLater(first.send('并发输入'), throwsStateError);
    await change;
    final results = await Future.wait([first.send('A'), second.send('B')]);
    expect(
      results.every((result) => result.reason == AgentStopReason.completed),
      isTrue,
    );
    expect(first.transcript.whereType<UserMessage>().single.text, 'A');
    expect(second.transcript.whereType<UserMessage>().single.text, 'B');
    await runtime.close();
  });

  test('非法导出版本或损坏记录在创建新会话前被拒绝', () async {
    final runtime = testRuntime();
    await expectLater(
      runtime.importSession({
        'format': 'agent_core_export',
        'version': 99,
        'records': [],
      }),
      throwsFormatException,
    );
    await expectLater(
      runtime.importSession({
        'format': 'agent_core_export',
        'version': 1,
        'records': [],
      }),
      throwsA(anyOf(isA<FormatException>(), isA<StateError>())),
    );
    expect(await runtime.listSessionIds(), isEmpty);
    await runtime.close();
  });

  test('导入不能通过重新编号掩盖日志缺口或请求输入不一致', () async {
    final runtime = testRuntime();
    final session = await runtime.createSession(id: 'source');
    await session.send('原始输入');
    final records = ((await session.export())['records'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final wrongSequence = [
      records.first,
      {...records[1], 'sequence': 9},
      ...records.skip(2),
    ];
    final wrongRequest = records.map((record) {
      if (record['type'] != 'request_prepared') return record;
      return {
        ...record,
        'data': {
          ...(record['data'] as Map<String, Object?>),
          'messageIds': ['not-in-the-log'],
        },
      };
    }).toList();
    for (final corrupted in [wrongSequence, wrongRequest]) {
      await expectLater(
        runtime.importSession({
          'format': 'agent_core_export',
          'version': 1,
          'records': corrupted,
        }),
        throwsFormatException,
      );
    }
    expect(await runtime.listSessionIds(), ['source']);
    await runtime.close();
  });
}

typedef _FailurePredicate =
    bool Function(String type, Map<String, Object?> data);

final class _FailingStore implements SessionStore {
  _FailingStore(this.inner, this.shouldFail);
  final SessionStore inner;
  final _FailurePredicate shouldFail;
  @override
  Future<SessionHandle> create(
    String id, {
    List<SessionRecord> initialRecords = const [],
  }) async => _FailingHandle(
    await inner.create(id, initialRecords: initialRecords),
    shouldFail,
  );
  @override
  Future<SessionHandle> open(String id, {bool readOnly = false}) async =>
      _FailingHandle(await inner.open(id, readOnly: readOnly), shouldFail);
  @override
  Future<List<String>> listSessionIds() => inner.listSessionIds();
  @override
  Future<void> delete(String id) => inner.delete(id);
}

final class _FailingHandle implements SessionHandle {
  _FailingHandle(this.inner, this.shouldFail);
  final SessionHandle inner;
  final _FailurePredicate shouldFail;
  @override
  String get id => inner.id;
  @override
  int get recordCount => inner.recordCount;
  @override
  bool get readOnly => inner.readOnly;
  @override
  Future<List<SessionRecord>> readRecords({int start = 0, int? limit}) =>
      inner.readRecords(start: start, limit: limit);
  @override
  Future<void> close() => inner.close();
  @override
  Future<SessionRecord> append(String type, Map<String, Object?> data) {
    if (shouldFail(type, data)) {
      throw const AgentPersistenceException('模拟磁盘保存失败');
    }
    return inner.append(type, data);
  }
}
