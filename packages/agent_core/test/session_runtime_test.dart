import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:agent_core/src/sessions/message_codec.dart';
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
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
    await session.send('早期资料：${'用户明确约束' * 120}');
    final first = session.transcript.first;
    final result = await session.send('当前要求：我还有两小时，请继续。');
    expect(result.reason, AgentStopReason.completed);
    expect(result.compactions, 1);
    expect(session.messageById(first.id)?.text, first.text);
    expect(session.transcript, hasLength(4));
    final projectionIds = session.contextMessages
        .map((message) => message.id)
        .toList();
    final exported = session.export();
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
      reopened.records
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
      session.records.where(
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
    final records = (session.export()['records'] as List<Object?>)
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
  Future<SessionHandle> create(String id) async =>
      _FailingHandle(await inner.create(id), shouldFail);
  @override
  Future<SessionHandle> open(String id) async =>
      _FailingHandle(await inner.open(id), shouldFail);
  @override
  Future<List<String>> listSessionIds() => inner.listSessionIds();
}

final class _FailingHandle implements SessionHandle {
  _FailingHandle(this.inner, this.shouldFail);
  final SessionHandle inner;
  final _FailurePredicate shouldFail;
  @override
  String get id => inner.id;
  @override
  List<SessionRecord> get records => inner.records;
  @override
  int get recoveredTailBytes => inner.recoveredTailBytes;
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
