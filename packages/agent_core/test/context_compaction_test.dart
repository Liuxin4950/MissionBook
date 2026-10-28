import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
  final policy = ContextPolicy(
    headroomTokens: 64,
    summaryMaxTokens: 128,
    keepRecentMessages: 2,
  );
  final profile = testProfile('main', window: 3000);
  ModelRequest request(List<AgentMessage> history) =>
      ModelRequest(systemPrompt: '保留用户约束', messages: history, tools: []);
  List<AgentMessage> longHistory() => [
    UserMessage(text: '旧资料：${'学习记录和明确约束。' * 100}'),
    textReply('已记录这些资料。${'历史事实。' * 40}').message,
    UserMessage(text: '我现在只剩两小时，请保留这个要求。'),
  ];
  ContextCompactor compactor({
    ModelCallback? summary,
    ContextPolicy? context,
    ModelProfile? summarizer,
  }) => ContextCompactor(
    policy: context ?? policy,
    conversationProfile: profile,
    summaryProfile: summarizer ?? testProfile('summary'),
    summaryModel: CallbackModel(
      summary ?? (request, token) => textReply('早期学习资料已整理；事实和用户陈述分开，未执行额外操作。'),
    ),
  );

  test('自动压缩保留当前要求，原列表和原消息不被删除或修改', () async {
    final history = longHistory();
    final ids = history.map((message) => message.id).toList();
    final result = await compactor().prepare(
      request(history),
      CancellationToken(),
    );
    expect(result, isNotNull);
    expect(result!.afterTokens, lessThan(result.beforeTokens));
    expect(result.contextMessages.first, isA<ContextSummaryMessage>());
    expect(result.contextMessages.last.id, history.last.id);
    expect(result.summary.summarizedMessageIds, contains(history.first.id));
    expect(
      result.summary.summarizedMessageIds,
      isNot(contains(history.last.id)),
    );
    expect(history.map((message) => message.id), ids);
    expect(result.summaryRequests, 1);
  });

  test('预算充足不调用摘要；关闭自动压缩仍可手动调用', () async {
    var summaries = 0;
    final engine = compactor(
      summary: (request, token) {
        summaries++;
        return textReply('摘要');
      },
    );
    expect(
      await engine.prepare(
        request([UserMessage(text: '短问题')]),
        CancellationToken(),
      ),
      isNull,
    );
    expect(summaries, 0);
    final disabled = compactor(
      context: ContextPolicy(
        enabled: false,
        headroomTokens: 64,
        keepRecentMessages: 1,
      ),
      summary: (request, token) {
        summaries++;
        return textReply('摘要');
      },
    );
    expect(
      await disabled.prepare(request(longHistory()), CancellationToken()),
      isNull,
    );
    expect(
      await disabled.prepare(
        request(longHistory()),
        CancellationToken(),
        trigger: CompactionTrigger.manual,
      ),
      isNotNull,
    );
    expect(summaries, 1);
  });

  test('保留近期工具调用及全部结果，不能切开一组工具', () async {
    final call = toolReply('a').message;
    final history = [
      ...longHistory(),
      call,
      ToolResultMessage(toolCallId: 'a', toolName: 'read', text: '真实查询结果'),
    ];
    final result = await compactor().prepare(
      request(history),
      CancellationToken(),
    );
    expect(result, isNotNull);
    expect(
      result!.contextMessages.map((message) => message.id),
      contains(call.id),
    );
    expect(
      result.contextMessages.whereType<ToolResultMessage>().single.toolCallId,
      'a',
    );
    expect(
      result.contextMessages.whereType<UserMessage>().single.id,
      history[2].id,
    );
  });

  test('摘要失败或被截断时不返回替换投影', () async {
    final original = longHistory();
    final ids = original.map((message) => message.id).toList();
    await expectLater(
      compactor(
        summary: (request, token) => throw const ModelException('server', '失败'),
      ).prepare(request(original), CancellationToken()),
      throwsA(isA<ModelException>()),
    );
    await expectLater(
      compactor(
        summary: (request, token) => ModelResponse(
          message: textReply('半截').message,
          stopReason: ModelStopReason.maxTokens,
        ),
      ).prepare(request(original), CancellationToken()),
      throwsA(
        isA<ModelException>().having(
          (error) => error.code,
          'code',
          'compaction_failed',
        ),
      ),
    );
    expect(original.map((message) => message.id), ids);
  });

  test('取消摘要等待保留原始上下文', () async {
    final entered = Completer<void>();
    final token = CancellationToken();
    final original = longHistory();
    final result = compactor(
      summary: (request, token) {
        entered.complete();
        return Completer<ModelResponse>().future;
      },
    ).prepare(request(original), token);
    await entered.future;
    token.cancel();
    await expectLater(result, throwsA(isA<AgentCancelled>()));
    expect(original, hasLength(3));
  });

  test('摘要没有缩小上下文时拒绝提交', () async {
    final engine = compactor(
      summary: (request, token) => textReply('无效重复内容' * 1000),
    );
    await expectLater(
      engine.prepare(request(longHistory()), CancellationToken()),
      throwsA(
        isA<ModelException>().having(
          (error) => error.code,
          'code',
          'compaction_insufficient',
        ),
      ),
    );
  });

  test('单条过大的当前输入不可被静默截断', () async {
    await expectLater(
      compactor().prepare(
        request([UserMessage(text: '超长输入' * 1000)]),
        CancellationToken(),
      ),
      throwsA(
        isA<ModelException>().having(
          (error) => error.code,
          'code',
          'context_too_large',
        ),
      ),
    );
  });

  test('较小摘要窗口会分块后合并，受摘要总次数上限约束', () async {
    var calls = 0;
    final history = <AgentMessage>[];
    for (var i = 0; i < 7; i++) {
      history.add(UserMessage(text: '资料$i：${'详细内容' * 65}'));
      history.add(textReply('已记录$i').message);
    }
    history.add(UserMessage(text: '保留当前要求'));
    final engine = compactor(
      summarizer: testProfile('summary', window: 2600),
      summary: (request, token) {
        calls++;
        return textReply('分块摘要$calls');
      },
    );
    final result = await engine.prepare(request(history), CancellationToken());
    expect(result, isNotNull);
    expect(calls, greaterThan(1));
    final limited = compactor(
      summarizer: testProfile('summary', window: 2600),
      context: ContextPolicy(
        headroomTokens: 64,
        summaryMaxTokens: 128,
        keepRecentMessages: 1,
        maxSummaryCalls: 1,
      ),
    );
    await expectLater(
      limited.prepare(request(history), CancellationToken()),
      throwsA(
        isA<ModelException>().having(
          (error) => error.code,
          'code',
          'compaction_limit',
        ),
      ),
    );
  });

  test('确认溢出后压缩并重试该模型请求，不重新执行已完成的工具', () async {
    var requests = 0;
    var executions = 0;
    final runtime = testRuntime(
      configuration: testConfiguration(context: policy),
      tools: [
        readTool((input, context) {
          executions++;
          return const ToolOutput.success('已经执行的真实结果');
        }),
      ],
      main: (request, token) {
        requests++;
        if (requests == 2) return toolReply('only-once');
        if (requests == 3) {
          throw const ModelException('context_overflow', '供应商确认溢出');
        }
        return textReply('回答$requests');
      },
    );
    final session = await runtime.createSession();
    await session.send('先记录这些背景：${'学习记录' * 100}');
    final result = await session.send('继续回答当前问题');
    expect(result.reason, AgentStopReason.completed);
    expect(result.compactions, 1);
    expect(requests, 4);
    expect(executions, 1);
    expect(session.transcript.whereType<ToolResultMessage>(), hasLength(1));
    expect(
      session.records.where((record) => record.type == 'context_compacted'),
      hasLength(1),
    );
    await runtime.close();
  });
}
