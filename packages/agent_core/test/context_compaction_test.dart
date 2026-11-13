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
    UserMessage(text: '旧资料：${'学习记录和明确约束。' * 800}'),
    textReply('已记录这些资料。${'历史事实。' * 320}').message,
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

  test('连续压缩承接安全摘要的一次性目标约束，普通核对通知可压缩', () async {
    final inputs = <ModelRequest>[];
    final engine = compactor(
      summary: (request, _) {
        inputs.add(request);
        return textReply('目标：完成迁移；仅本次禁止删除记录；核对来源业务查询，操作已完成。');
      },
    );
    final notice = ContextMessage(source: '业务查询核对', text: '操作已完成');
    final first = await engine.prepare(
      request([
        UserMessage(text: '完成迁移，仅本次禁止删除记录。${'背景。' * 800}'),
        notice,
        textReply('收到').message,
        UserMessage(text: '继续'),
      ]),
      CancellationToken(),
      trigger: CompactionTrigger.manual,
    );
    expect(first, isNotNull);
    expect(first!.summary.isSafe, isTrue);
    expect(first.summary.summarizedMessageIds, contains(notice.id));
    expect(
      inputs.first.messages.whereType<ContextMessage>().single.source,
      '业务查询核对',
    );
    final second = await engine.prepare(
      request([
        ...first.contextMessages,
        UserMessage(text: '下一步${'资料。' * 800}'),
        textReply('继续执行').message,
        UserMessage(text: '收尾'),
      ]),
      CancellationToken(),
      trigger: CompactionTrigger.manual,
    );
    expect(second, isNotNull);
    expect(
      inputs.last.messages.whereType<ContextSummaryMessage>().single.id,
      first.summary.id,
    );
    expect(inputs.last.systemPrompt, contains('一次性'));
    expect(
      second!.summary.summarizedMessageIds,
      containsAll(first.summary.summarizedMessageIds),
    );
    expect(second.summary.text, contains('仅本次禁止删除记录'));
  });

  test('输入估算不受输出额度和非输入请求参数影响', () {
    const estimator = ApproximateTokenEstimator();
    final profile = testProfile('main', window: 20000);
    final messages = [UserMessage(text: '相同输入')];
    int estimate(int output, ReasoningEffort effort) => estimator.estimate(
      profile,
      ModelRequest(
        systemPrompt: '系统说明',
        messages: messages,
        tools: [],
        maxOutputTokens: output,
        reasoningEffort: effort,
      ),
    );
    expect(
      estimate(1, ReasoningEffort.off),
      estimate(10000, ReasoningEffort.high),
    );
  });

  test('自动触发比例基于扣除输出预留后的输入预算', () async {
    final profile = testProfile('main', window: 10000, output: 6000);
    final engine = ContextCompactor(
      policy: policy,
      conversationProfile: profile,
      summaryProfile: testProfile('summary'),
      summaryModel: CallbackModel((request, token) => textReply('旧记录摘要')),
    );
    // 约 3.4k 输入小于硬输入预算，但已越过其 80% 触发线。
    final history = [
      UserMessage(text: '旧' * 4200),
      textReply('已记录').message,
      UserMessage(text: '继续'),
    ];
    final result = await engine.prepare(request(history), CancellationToken());
    expect(result, isNotNull);
  });

  test('压缩校验使用本次请求的输出额度', () async {
    final engine = ContextCompactor(
      policy: policy,
      conversationProfile: testProfile('main', window: 3000),
      summaryProfile: testProfile('summary'),
      summaryModel: CallbackModel((request, token) => textReply('摘要')),
    );
    await expectLater(
      engine.prepare(
        ModelRequest(
          systemPrompt: '',
          messages: [
            UserMessage(text: '旧' * 2000),
            UserMessage(text: '新' * 900),
          ],
          tools: [],
          maxOutputTokens: 2400,
        ),
        CancellationToken(),
      ),
      throwsA(
        isA<ModelException>().having(
          (error) => error.code,
          'code',
          'compaction_insufficient',
        ),
      ),
    );
  });

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
    expect(result.usage.inputTokens, 10);
    expect(result.usage.outputTokens, 5);
  });

  test('只固定供给块，旧摘要失效且旧工具组仍可进入摘要', () async {
    final memory = ContextMessage(
      source: 'mission_book_memory',
      text: '当前有效记忆：用户每天早上七点起床',
    );
    final time = ContextMessage(source: 'mission_book_context', text: '今天是星期一');
    final legacy = ContextSummaryMessage(
      text: '旧摘要含已忘记的通勤路线：42路公交',
      summarizedMessageIds: const ['legacy-user'],
    );
    final call = toolReply('old-tool').message;
    final tool = ToolResultMessage(
      toolCallId: 'old-tool',
      toolName: 'read',
      text: '旧工具返回的真实事实',
    );
    final history = <AgentMessage>[
      legacy,
      memory,
      time,
      UserMessage(text: '早期资料：${'学习记录和明确约束。' * 800}'),
      call,
      tool,
      textReply('旧回答').message,
      UserMessage(text: '请继续当前问题'),
    ];
    final summaries = <ModelRequest>[];
    final result = await compactor(
      summary: (request, token) {
        summaries.add(request);
        return textReply('旧历史的工具事实已整理。');
      },
    ).prepare(request(history), CancellationToken());
    expect(result, isNotNull);
    expect(
      result!.contextMessages.whereType<ContextMessage>().map((m) => m.id),
      [memory.id, time.id],
    );
    expect(result.contextMessages, isNot(contains(legacy)));
    expect(result.contextMessages.whereType<ToolResultMessage>(), isEmpty);
    expect(
      result.summary.summarizedMessageIds,
      containsAll([call.id, tool.id]),
    );
    expect(
      result.summary.summarizedMessageIds,
      isNot(anyOf(contains(memory.id), contains(time.id), contains(legacy.id))),
    );
    expect(summaries, hasLength(1));
    final input = summaries.single.messages;
    expect(input.whereType<ContextMessage>(), isEmpty);
    expect(input.whereType<ContextSummaryMessage>(), isEmpty);
    expect(input, containsAllInOrder([call, tool]));
    expect(
      input.map((message) => message.text).join('\n'),
      isNot(anyOf(contains('七点'), contains('星期一'), contains('42路'))),
    );
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
      history.add(UserMessage(text: '资料$i：${'详细内容' * 200}'));
      history.add(textReply('已记录$i').message);
    }
    history.add(UserMessage(text: '保留当前要求'));
    final engine = compactor(
      summarizer: testProfile('summary', window: 2600),
      context: ContextPolicy(
        headroomTokens: 64,
        summaryMaxTokens: 128,
        keepRecentMessages: 2,
        maxSummaryCalls: 4,
      ),
      summary: (request, token) {
        calls++;
        return textReply('分块摘要$calls');
      },
    );
    final result = await engine.prepare(request(history), CancellationToken());
    expect(result, isNotNull);
    expect(calls, 4);
    expect(result!.summaryRequests, calls);
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
      (await session.readRecords()).where(
        (record) => record.type == 'context_compacted',
      ),
      hasLength(1),
    );
    await runtime.close();
  });
}
