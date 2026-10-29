import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  test('直接回答只请求一次，消息和请求都保留独立快照', () async {
    final requests = <ModelRequest>[];
    final agent = _agent((request, token) {
      requests.add(request);
      return _reply('你好');
    });
    final result = await agent.run(input: '你好');
    expect(result.reason, AgentStopReason.completed);
    expect(result.answer, '你好');
    expect(result.modelSteps, 1);
    expect(result.messages, hasLength(2));
    expect(requests.single.messages, hasLength(1));
    expect(() => result.messages.clear(), throwsUnsupportedError);
    await agent.close();
  });

  test('同批工具顺序执行，多轮调用把真实结果交回模型，事件保持顺序', () async {
    final executed = <int>[];
    final requests = <ModelRequest>[];
    final agent = _agent(
      (request, token) {
        requests.add(request);
        if (requests.length == 1) return _calls([_call('a', 1), _call('b', 2)]);
        if (requests.length == 2) {
          expect(
            request.messages.whereType<ToolResultMessage>().map((m) => m.text),
            ['结果1', '结果2'],
          );
          return _calls([_call('c', 3)]);
        }
        return _reply('根据三次结果回答');
      },
      tools: [
        _tool((input, context) async {
          executed.add(input['n']! as int);
          await Future<void>.delayed(Duration.zero);
          return ToolOutput.success('结果${input['n']}');
        }),
      ],
    );
    final events = <AgentEvent>[];
    final subscription = agent.events.listen(events.add);
    final result = await agent.run(input: '分步查询');
    await agent.close();
    await subscription.cancel();
    expect(executed, [1, 2, 3]);
    expect(result.modelSteps, 3);
    expect(result.messages, hasLength(7));
    expect(requests.first.messages, hasLength(1));
    expect(events.map((event) => event.runtimeType.toString()), [
      'UserMessageAccepted',
      'ModelRequestStarted',
      'ModelAttemptStarted',
      'ModelUsageReported',
      'AssistantReceived',
      'ToolCallStarted',
      'ToolExecutionStarted',
      'ToolCallFinished',
      'ToolCallStarted',
      'ToolExecutionStarted',
      'ToolCallFinished',
      'ModelRequestStarted',
      'ModelAttemptStarted',
      'ModelUsageReported',
      'AssistantReceived',
      'ToolCallStarted',
      'ToolExecutionStarted',
      'ToolCallFinished',
      'ModelRequestStarted',
      'ModelAttemptStarted',
      'ModelUsageReported',
      'AssistantReceived',
      'AgentRunFinished',
    ]);
    expect(result.answer, '根据三次结果回答');
  });

  for (final input in <Map<String, Object?>>[
    {},
    {'n': '1'},
    {'n': 0},
    {'n': 1, 'extra': true},
  ]) {
    test('参数 $input 不符合 Schema 时，不授权、不执行，并回传错误', () async {
      var executed = false;
      var authorized = false;
      var step = 0;
      final agent = _agent(
        (request, token) {
          if (++step == 1) {
            return _calls([
              ToolCallBlock(id: 'bad', name: 'query', input: input),
            ]);
          }
          expect(_errorCode(request.messages.last), 'invalid_arguments');
          return _reply('请修正参数');
        },
        tools: [
          _tool((input, context) {
            executed = true;
            return const ToolOutput.success('不应执行');
          }),
        ],
        authorize: (tool, call, token) {
          authorized = true;
          return const ToolDecision.allow();
        },
      );
      final result = await agent.run(input: '查询');
      expect(result.reason, AgentStopReason.completed);
      expect(executed, isFalse);
      expect(authorized, isFalse);
      await agent.close();
    });
  }

  test('拒绝授权变成明确工具结果，模型据此回答', () async {
    var step = 0;
    var executed = false;
    final agent = _agent(
      (request, token) {
        if (++step == 1) return _calls([_call('a', 1)]);
        expect(_errorCode(request.messages.last), 'permission_denied');
        return _reply('用户拒绝了操作');
      },
      tools: [
        _tool((input, context) {
          executed = true;
          return const ToolOutput.success('不应执行');
        }),
      ],
      authorize: (tool, call, token) => const ToolDecision.deny('用户拒绝'),
    );
    expect((await agent.run(input: '操作')).answer, '用户拒绝了操作');
    expect(executed, isFalse);
    await agent.close();
  });

  test('每次调用重新授权，同批第二次可以被撤销', () async {
    var step = 0;
    var checks = 0;
    var writes = 0;
    final agent = _agent(
      (request, token) {
        if (++step == 1) return _calls([_call('a', 1), _call('b', 2)]);
        return _reply('第二次被拒绝');
      },
      tools: [
        _tool((input, context) {
          writes++;
          return const ToolOutput.success('已保存');
        }),
      ],
      authorize: (tool, call, token) {
        if (++checks == 1) return const ToolDecision.allow();
        return const ToolDecision.deny('权限已撤销');
      },
    );
    final result = await agent.run(input: '两次修改');
    expect(writes, 1);
    expect(checks, 2);
    expect(
      _errorCode(result.messages.whereType<ToolResultMessage>().last),
      'permission_denied',
    );
    await agent.close();
  });

  test('未知工具和可预期的业务失败交回模型处理', () async {
    var step = 0;
    final agent = _agent(
      (request, token) {
        if (++step == 1) {
          return _calls([
            ToolCallBlock(id: 'a', name: 'missing', input: {}),
            _call('b', 1),
          ]);
        }
        final results = request.messages
            .whereType<ToolResultMessage>()
            .toList();
        expect(_errorCode(results[0]), 'unknown_tool');
        expect(_errorCode(results[1]), 'conflict');
        return _reply('说明冲突');
      },
      tools: [
        _tool((input, context) => ToolOutput.failure('conflict', '版本已变化')),
      ],
    );
    expect((await agent.run(input: '修改')).reason, AgentStopReason.completed);
    await agent.close();
  });

  test('工具发生未预期异常时停止，不让模型自动重试可能已经写入的操作', () async {
    var requests = 0;
    var writes = 0;
    final agent = _agent(
      (request, token) {
        requests++;
        return _calls([_call('a', 1), _call('b', 2)]);
      },
      tools: [
        _tool((input, context) {
          writes++;
          throw StateError('提交后故障');
        }),
      ],
    );
    final result = await agent.run(input: '修改');
    expect(result.reason, AgentStopReason.failed);
    expect(result.failure?.code, 'tool_outcome_unknown');
    expect(writes, 1);
    expect(requests, 1);
    final outputs = result.messages.whereType<ToolResultMessage>().toList();
    expect(_errorCode(outputs[0]), 'outcome_unknown');
    expect(_errorCode(outputs[1]), 'not_executed');
    await agent.close();
  });

  test('模型请求失败仍保留已成功的工具结果', () async {
    var step = 0;
    final agent = _agent((request, token) {
      if (++step == 1) return _calls([_call('a', 1)]);
      throw const ModelException('transport_error', '网络断开');
    }, tools: [_tool((input, context) => const ToolOutput.success('已提交'))]);
    final result = await agent.run(input: '修改');
    expect(result.failure?.code, 'transport_error');
    expect(result.messages.whereType<ToolResultMessage>().single.text, '已提交');
    expect(result.answer, isNull);
    expect(agent.isRunning, isFalse);
    await agent.close();
  });

  test('次数上限阻止最后一批工具执行，避免写入后没有请求额度生成回答', () async {
    var requests = 0;
    var writes = 0;
    final agent = _agent(
      (request, token) {
        requests++;
        return _calls([_call('call-$requests', requests)]);
      },
      tools: [
        _tool((input, context) {
          writes++;
          return const ToolOutput.success('已执行');
        }),
      ],
      maxSteps: 2,
    );
    final result = await agent.run(input: '一直调用');
    expect(result.reason, AgentStopReason.maxSteps);
    expect(result.modelSteps, 2);
    expect(writes, 1);
    expect(_errorCode(result.messages.last), 'step_limit');
    await agent.close();
  });

  test('输出截断不执行其中的工具，不冒充完整回答', () async {
    var writes = 0;
    final agent = _agent(
      (request, token) =>
          _calls([_call('a', 1)], reason: ModelStopReason.maxTokens),
      tools: [
        _tool((input, context) {
          writes++;
          return const ToolOutput.success('不应执行');
        }),
      ],
    );
    final result = await agent.run(input: '操作');
    expect(result.reason, AgentStopReason.maxTokens);
    expect(result.answer, isNull);
    expect(writes, 0);
    expect(_errorCode(result.messages.last), 'not_executed');
    await agent.close();
  });

  test('一批重复的调用编号在执行任何工具前被拒绝', () async {
    var writes = 0;
    final agent = _agent(
      (request, token) => _calls([_call('a', 1), _call('a', 2)]),
      tools: [
        _tool((input, context) {
          writes++;
          return const ToolOutput.success('不应执行');
        }),
      ],
    );
    final result = await agent.run(input: '操作');
    expect(result.failure?.code, 'invalid_response');
    expect(writes, 0);
    expect(result.messages, hasLength(1));
    await agent.close();
  });

  test('跨请求复用同一调用编号被拒绝，不执行第二次', () async {
    var writes = 0;
    final agent = _agent(
      (request, token) => _calls([_call('same', 1)]),
      tools: [
        _tool((input, context) {
          writes++;
          return const ToolOutput.success('已保存');
        }),
      ],
    );
    final result = await agent.run(input: '操作');
    expect(result.failure?.code, 'invalid_response');
    expect(writes, 1);
    await agent.close();
  });

  test('结束原因与内容不一致，或空回答，均不当作成功', () async {
    for (final response in [
      _calls([]),
      _calls([_call('a', 1)], reason: ModelStopReason.completed),
      _reply(''),
    ]) {
      final agent = _agent((request, token) => response);
      expect((await agent.run(input: '查询')).failure?.code, 'invalid_response');
      await agent.close();
    }
  });

  test('等待模型时取消，不等待不配合取消的模型，迟到响应不会加入结果', () async {
    final entered = Completer<void>();
    final lateResponse = Completer<ModelResponse>();
    final agent = _agent((request, token) {
      entered.complete();
      return lateResponse.future;
    });
    final running = agent.run(input: '查询');
    await entered.future;
    agent.cancel();
    final result = await running.timeout(const Duration(seconds: 1));
    expect(result.reason, AgentStopReason.cancelled);
    expect(result.messages, hasLength(1));
    lateResponse.complete(_reply('迟到回答'));
    await agent.close();
    expect(result.messages, hasLength(1));
  });

  test('等待用户授权时取消，稍后同意也不会执行工具', () async {
    final entered = Completer<void>();
    final decision = Completer<ToolDecision>();
    var writes = 0;
    final agent = _agent(
      (request, token) => _calls([_call('a', 1)]),
      tools: [
        _tool((input, context) {
          writes++;
          return const ToolOutput.success('不应执行');
        }),
      ],
      authorize: (tool, call, token) {
        entered.complete();
        return decision.future;
      },
    );
    final running = agent.run(input: '操作');
    await entered.future;
    agent.cancel();
    final result = await running;
    expect(result.reason, AgentStopReason.cancelled);
    expect(_errorCode(result.messages.last), 'cancelled');
    decision.complete(const ToolDecision.allow());
    await agent.close();
    expect(writes, 0);
  });

  test('工具执行期间取消，先保留已提交结果，再跳过其余工具', () async {
    final entered = Completer<void>();
    final committed = Completer<ToolOutput>();
    var writes = 0;
    final agent = _agent(
      (request, token) => _calls([_call('a', 1), _call('b', 2)]),
      tools: [
        _tool((input, context) {
          writes++;
          entered.complete();
          return committed.future;
        }),
      ],
    );
    final running = agent.run(input: '修改两项');
    await entered.future;
    agent.cancel();
    expect(agent.isRunning, isTrue);
    committed.complete(const ToolOutput.success('确实已提交'));
    final result = await running;
    final results = result.messages.whereType<ToolResultMessage>().toList();
    expect(result.reason, AgentStopReason.cancelled);
    expect(results[0].text, '确实已提交');
    expect(results[0].isError, isFalse);
    expect(_errorCode(results[1]), 'cancelled');
    expect(writes, 1);
    await agent.close();
  });

  test('预先取消不发请求；上一轮结果可用于后续对话', () async {
    var requests = 0;
    final agent = _agent((request, token) {
      requests++;
      if (requests == 2) expect(request.messages, hasLength(3));
      return _reply('回答$requests');
    });
    final cancelled = CancellationToken()..cancel();
    expect(
      (await agent.run(input: '取消', cancellation: cancelled)).modelSteps,
      0,
    );
    final first = await agent.run(input: '第一句');
    final second = await agent.run(input: '第二句', history: first.messages);
    expect(second.messages, hasLength(4));
    expect(second.answer, '回答2');
    expect(first.messages, hasLength(2));
    await agent.close();
  });

  test('有悬空调用的历史不能发给模型', () async {
    var requests = 0;
    final agent = _agent((request, token) {
      requests++;
      return _reply('不应请求');
    });
    final result = await agent.run(
      input: '继续',
      history: [
        UserMessage(text: '先前请求'),
        _calls([_call('old', 1)]).message,
      ],
    );
    expect(result.failure?.code, 'invalid_history');
    expect(requests, 0);
    await agent.close();
  });

  test('同一循环禁止并发运行，关闭会取消等待并拒绝新请求', () async {
    final entered = Completer<void>();
    final agent = _agent((request, token) {
      entered.complete();
      return Completer<ModelResponse>().future;
    });
    final running = agent.run(input: '第一轮');
    await entered.future;
    await expectLater(agent.run(input: '同时开始'), throwsStateError);
    await agent.close();
    expect((await running).reason, AgentStopReason.cancelled);
    expect(agent.isRunning, isFalse);
    await expectLater(agent.run(input: '关闭后开始'), throwsStateError);
  });

  test('工具参数和 Schema 深度复制并冻结，授权时看到的值不能再被改动', () {
    final nested = <String, Object?>{
      'items': <Object?>[1],
    };
    final call = ToolCallBlock(id: 'a', name: 'query', input: nested);
    (nested['items']! as List<Object?>).add(2);
    expect(call.input['items'], [1]);
    expect(
      () => (call.input['items']! as List<Object?>).add(3),
      throwsUnsupportedError,
    );
    expect(() => call.input['new'] = true, throwsUnsupportedError);
  });
}

typedef _Responder =
    FutureOr<ModelResponse> Function(ModelRequest, CancellationToken);

final class _Model implements AgentModel {
  _Model(this.respond);
  final _Responder respond;

  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    return respond(request, cancellation);
  }
}

AgentLoop _agent(
  _Responder respond, {
  List<AgentTool> tools = const [],
  ToolAuthorizer? authorize,
  int maxSteps = 8,
}) {
  return AgentLoop(
    model: _Model(respond),
    systemPrompt: '测试系统提示',
    tools: tools,
    authorize: authorize ?? (tool, call, token) => const ToolDecision.allow(),
    maxSteps: maxSteps,
  );
}

AgentTool _tool(ToolHandler handler) => AgentTool(
  definition: ToolDefinition(
    name: 'query',
    description: '测试工具',
    inputSchema: {
      'type': 'object',
      'properties': {
        'n': {'type': 'integer', 'minimum': 1},
      },
      'required': ['n'],
      'additionalProperties': false,
    },
  ),
  execute: handler,
);

ToolCallBlock _call(String id, int n) =>
    ToolCallBlock(id: id, name: 'query', input: {'n': n});

ModelResponse _calls(
  List<ToolCallBlock> calls, {
  ModelStopReason reason = ModelStopReason.toolUse,
}) {
  return ModelResponse(
    message: AssistantMessage(
      content: calls,
      provider: 'test',
      model: 'scripted',
    ),
    stopReason: reason,
  );
}

ModelResponse _reply(String text) => ModelResponse(
  message: AssistantMessage(
    content: [TextBlock(text: text)],
    provider: 'test',
    model: 'scripted',
  ),
  stopReason: ModelStopReason.completed,
);

String _errorCode(AgentMessage message) {
  final result = message as ToolResultMessage;
  expect(result.isError, isTrue);
  return (jsonDecode(result.text) as Map<String, dynamic>)['code'] as String;
}
