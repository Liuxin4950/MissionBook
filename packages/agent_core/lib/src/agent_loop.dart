import 'dart:async';
import 'dart:convert';

import 'agent_event.dart';
import 'agent_result.dart';
import 'cancellation.dart';
import 'content_block.dart';
import 'context/context_compactor.dart';
import 'message.dart';
import 'model.dart';
import 'models/configuration.dart';
import 'models/request_runner.dart';
import 'tool.dart';

/// 一轮工作的控制器：准备上下文、请求模型、执行工具、保存结果再继续。
final class AgentLoop {
  AgentLoop({
    required this.model,
    required this.systemPrompt,
    required List<AgentTool> tools,
    required this.authorize,
    this.maxSteps = 8,
    this.compactor,
    this.sessionId,
    this.maxOutputTokens,
    this.reasoningEffort,
    this.jsonOutput = false,
    this.maxRunDuration = const Duration(minutes: 15),
    RetryPolicy? retry,
  }) : _tools = _indexTools(tools),
       _requests = ModelRequestRunner(
         model: model,
         retry: retry ?? RetryPolicy(),
       ) {
    if (maxSteps < 1) throw ArgumentError.value(maxSteps, 'maxSteps');
    if (maxRunDuration <= Duration.zero) throw ArgumentError('整轮时长必须大于零');
  }

  final AgentModel model;
  final String systemPrompt;
  final ToolAuthorizer authorize;
  final int maxSteps;
  final ContextCompactor? compactor;
  final String? sessionId;
  final int? maxOutputTokens;
  final ReasoningEffort? reasoningEffort;
  final bool jsonOutput;
  String get _requestSystemPrompt =>
      jsonOutput ? '$systemPrompt\n请将最终回答输出为一个有效 JSON 对象。' : systemPrompt;
  final Duration maxRunDuration;
  final Map<String, AgentTool> _tools;
  final ModelRequestRunner _requests;
  final _events = StreamController<AgentEvent>.broadcast();
  CancellationToken? _active;
  Completer<void>? _runDone;
  bool _closed = false;

  Stream<AgentEvent> get events => _events.stream;
  bool get isRunning => _active != null;

  /// 输入为空时继续已有对话；会话层用它恢复中断，不重复追加用户输入。
  Future<AgentRunResult> run({
    String? input,
    UserMessage? userMessage,
    List<AgentMessage> history = const [],
    List<AgentMessage>? contextHistory,
    CancellationToken? cancellation,
    AgentEventSink? onEvent,
  }) async {
    if (_closed) throw StateError('AgentLoop 已关闭');
    if (isRunning) throw StateError('同一个 AgentLoop 不能同时运行两轮');
    if (input != null && userMessage != null) {
      throw ArgumentError('input 和 userMessage 只能提供一个');
    }
    if (input != null && input.trim().isEmpty) throw ArgumentError('用户输入不能为空');
    if (input == null && userMessage == null && history.isEmpty) {
      throw ArgumentError('继续运行需要已有历史');
    }
    final token = cancellation ?? CancellationToken();
    _active = token;
    final done = Completer<void>();
    _runDone = done;
    // 复制会话的历史：messages 留完整记录，context 用于下一次模型请求。
    final messages = List<AgentMessage>.of(history);
    var context = List<AgentMessage>.of(contextHistory ?? history);
    final pending = <ToolCallBlock>[];
    var step = 0;
    var attempts = 0;
    var compactions = 0;
    var usage = const TokenUsage();
    var usageIncomplete = false;
    final elapsed = Stopwatch()..start();
    var timedOut = false;
    final deadline = Timer(maxRunDuration, () {
      timedOut = true;
      token.cancel(deadlineExceeded: true);
    });

    Future<void> publish(AgentEvent event) async {
      if (event is ModelUsageReported) {
        usage = usage + event.usage;
        usageIncomplete = usageIncomplete || !event.complete;
      }
      await onEvent?.call(event); // 会话先保存关键事实，再向观察者发布。
      if (event is ModelAttemptStarted &&
          event.request.purpose == ModelRequestPurpose.conversation) {
        attempts++;
      }
      _events.add(event);
    }

    void appendMessage(AgentMessage message) {
      messages.add(message);
      context.add(message);
    }

    Future<void> appendResult(ToolCallBlock call, ToolOutput output) async {
      final result = ToolResultMessage(
        toolCallId: call.id,
        toolName: call.name,
        text: output.text,
        isError: output.isError,
        errorCode: output.errorCode,
      );
      appendMessage(result); // 先保留进程中的真实结果，即使之后磁盘保存失败也不谎称未执行。
      pending.remove(call);
      await publish(ToolCallFinished(step, call, result));
    }

    Future<void> settlePending(String code, String description) async {
      for (final call in List<ToolCallBlock>.of(pending)) {
        await appendResult(call, ToolOutput.failure(code, description));
      }
    }

    AgentRunResult snapshot(AgentStopReason reason, AgentFailure? failure) =>
        AgentRunResult(
          reason: reason,
          messages: messages,
          contextMessages: context,
          modelSteps: step,
          failure: failure,
          usage: usage,
          modelAttempts: attempts,
          compactions: compactions,
          usageIncomplete: usageIncomplete,
        );

    Future<AgentRunResult> finish(
      AgentStopReason reason, [
      AgentFailure? failure,
    ]) async {
      final result = snapshot(reason, failure);
      await publish(AgentRunFinished(step, result));
      return result;
    }

    Future<bool> compact(CompactionTrigger trigger) async {
      final next = await compactor?.prepare(
        ModelRequest(
          systemPrompt: _requestSystemPrompt,
          messages: context,
          tools: _definitions,
          maxOutputTokens: maxOutputTokens,
          reasoningEffort: reasoningEffort,
          jsonOutput: jsonOutput,
        ),
        token,
        trigger: trigger,
        onEvent: publish,
      );
      if (next == null) return false;
      await publish(ContextCompacted(step, next));
      context = List.of(next.contextMessages);
      compactions++;
      return true;
    }

    try {
      try {
        final Set<String> usedCallIds;
        try {
          usedCallIds = validateConversation(messages);
          validateConversation(context);
        } on FormatException catch (error) {
          return await finish(
            AgentStopReason.failed,
            AgentFailure('invalid_history', error.message, cause: error),
          );
        }
        // send 带来新消息；resume 可能没有新消息，避免重复添加用户输入。
        final newInput =
            userMessage ?? (input == null ? null : UserMessage(text: input));
        if (newInput != null) {
          await publish(UserMessageAccepted(0, newInput));
          appendMessage(newInput);
        }
        // 一步是一次对话模型请求；执行工具后回到这里继续，maxSteps 限制总步数。
        for (var nextStep = 1; nextStep <= maxSteps; nextStep++) {
          token.throwIfCancelled();
          step = nextStep;
          // 发送前检查上下文预算；需要时压缩旧内容，原始记录仍保留。
          await compact(CompactionTrigger.automatic);
          await publish(ModelRequestStarted(step));
          ModelResponse response;
          try {
            // 把系统提示、上下文和工具说明交给请求执行器；下一站是 request_runner.dart。
            response = await _requests.run(
              ModelRequest(
                systemPrompt: _requestSystemPrompt,
                messages: context,
                tools: _definitions,
                maxOutputTokens: maxOutputTokens,
                reasoningEffort: reasoningEffort,
                jsonOutput: jsonOutput,
              ),
              token,
              step: step,
              onEvent: publish,
            );
          } on ModelException catch (error) {
            if (error.code != 'context_overflow' ||
                !await compact(CompactionTrigger.overflow)) {
              rethrow;
            }
            // 只在该请求尚未执行任何新工具时压缩并恢复一次，不重放业务操作。
            response = await _requests.run(
              ModelRequest(
                systemPrompt: _requestSystemPrompt,
                messages: context,
                tools: _definitions,
                maxOutputTokens: maxOutputTokens,
                reasoningEffort: reasoningEffort,
                jsonOutput: jsonOutput,
              ),
              token,
              step: step,
              onEvent: publish,
            );
          }
          token.throwIfCancelled();
          _validateResponse(response, usedCallIds, messages);
          await publish(
            AssistantReceived(step, response.message, usage: response.usage),
          );
          appendMessage(response.message);
          if (response.stopReason == ModelStopReason.completed &&
              response.message.text.trim().isEmpty) {
            // 思考和用量已保存，留给宿主展示并允许 resume，不把空正文当作完成。
            return await finish(
              AgentStopReason.failed,
              const AgentFailure('empty_answer', '模型尚未生成正文，可以继续请求或调整输出预算'),
            );
          }
          // 模型返回的工具调用只是请求，到这里工具还没有执行。
          final calls = response.message.toolCalls;
          pending.addAll(calls);
          if (response.stopReason == ModelStopReason.maxTokens) {
            await settlePending('not_executed', '模型输出被截断，未执行其中的工具调用');
            return await finish(AgentStopReason.maxTokens);
          }
          if (response.stopReason == ModelStopReason.refused) {
            await settlePending('not_executed', '模型拒绝了请求，未执行工具');
            return await finish(AgentStopReason.refused);
          }
          // 没有工具调用就结束；有调用则执行并保存结果，下次请求交回模型。
          if (calls.isEmpty) return await finish(AgentStopReason.completed);
          if (step == maxSteps) {
            await settlePending('step_limit', '请求次数已到上限，未执行本批工具');
            return await finish(AgentStopReason.maxSteps);
          }
          for (final call in calls) {
            token.throwIfCancelled();
            await publish(ToolCallStarted(step, call));
            final output = await _executeTool(
              call,
              token,
              step,
              publish,
              elapsed,
            );
            await appendResult(call, output);
          }
        }
        throw StateError('请求次数边界处理遗漏');
      } on AgentPersistenceException {
        rethrow;
      } on AgentCancelled {
        await settlePending('cancelled', '运行已取消，此调用未执行或由工具协作取消');
        if (timedOut || token.deadlineExceeded) {
          return await finish(
            AgentStopReason.failed,
            const AgentFailure('turn_timeout', '本轮已达到总时长上限'),
          );
        }
        return await finish(AgentStopReason.cancelled);
      } on _ToolOutcomeUnknown catch (error) {
        for (final call in List<ToolCallBlock>.of(pending)) {
          await appendResult(
            call,
            ToolOutput.failure(
              call.id == error.call.id ? 'outcome_unknown' : 'not_executed',
              call.id == error.call.id
                  ? error.failure.message
                  : '前一工具异常，未执行本调用',
            ),
          );
        }
        return await finish(AgentStopReason.failed, error.failure);
      } on ModelException catch (error) {
        await settlePending('not_executed', '模型请求失败，未执行本调用');
        return await finish(
          AgentStopReason.failed,
          AgentFailure(error.code, error.message, cause: error),
        );
      } catch (error) {
        await settlePending('not_executed', '运行异常，未执行本调用');
        return await finish(
          AgentStopReason.failed,
          AgentFailure('runtime_error', 'Agent 运行异常，已停止后续操作', cause: error),
        );
      }
    } on AgentPersistenceException catch (error) {
      // 连取消和错误收尾的保存失败也在这里终止，不能再次补写同一个坏日志。
      final result = snapshot(
        AgentStopReason.failed,
        AgentFailure(error.code, error.message, cause: error),
      );
      _events.add(AgentRunFinished(step, result));
      return result;
    } finally {
      deadline.cancel();
      elapsed.stop();
      _active = null;
      _runDone = null;
      done.complete();
    }
  }

  List<ToolDefinition> get _definitions =>
      _tools.values.map((tool) => tool.definition).toList();

  Future<ToolOutput> _executeTool(
    ToolCallBlock call,
    CancellationToken token,
    int step,
    AgentEventSink publish,
    Stopwatch elapsed,
  ) async {
    // 按模型给出的名字查找工具，随后检查参数并请求宿主授权。
    final tool = _tools[call.name];
    if (tool == null) {
      return ToolOutput.failure('unknown_tool', '未注册工具：${call.name}');
    }
    final inputError = tool.validateInput(call.input);
    if (inputError != null) {
      return ToolOutput.failure('invalid_arguments', inputError);
    }
    final decision = await token.wait(
      Future.sync(() => authorize(tool.definition, call, token)),
    );
    if (elapsed.elapsed >= maxRunDuration) {
      token.cancel(deadlineExceeded: true);
    }
    token.throwIfCancelled();
    if (!decision.allowed) {
      return ToolOutput.failure('permission_denied', decision.reason);
    }
    final executionCall = decision.input == null
        ? call
        : ToolCallBlock(id: call.id, name: call.name, input: decision.input!);
    final approvedError = tool.validateInput(executionCall.input);
    if (approvedError != null) {
      return ToolOutput.failure('invalid_arguments', approvedError);
    }
    await publish(
      ToolExecutionStarted(step, executionCall, readOnly: tool.readOnly),
    ); // 保存失败时绝不执行工具。
    try {
      token.throwIfCancelled();
      // 通过检查和授权才执行实际函数；时间工具见 example/demo_tools.dart。
      return await Future.sync(
        () => tool.execute(
          executionCall.input,
          ToolContext(
            callId: call.id,
            cancellation: token,
            sessionId: sessionId,
          ),
        ),
      ).timeout(maxRunDuration - elapsed.elapsed);
    } on ToolRejected catch (error) {
      return ToolOutput.failure(error.code, error.message);
    } on AgentCancelled {
      if (tool.readOnly) return ToolOutput.failure('cancelled', '只读操作已取消');
      throw _ToolOutcomeUnknown(
        call,
        const AgentFailure('tool_outcome_unknown', '工具已开始后取消，必须核对是否已提交'),
      );
    } catch (error) {
      if (tool.readOnly) {
        return ToolOutput.failure('tool_failed', '只读工具执行失败，请稍后重试或调整输入');
      }
      throw _ToolOutcomeUnknown(
        call,
        AgentFailure(
          'tool_outcome_unknown',
          '工具 ${call.name} 执行异常，结果需要核对，已停止后续操作',
          cause: error,
        ),
      );
    }
  }

  void cancel() => _active?.cancel();
  Future<void> close() async {
    _closed = true;
    cancel();
    await _runDone?.future;
    await _events.close();
  }

  static Map<String, AgentTool> _indexTools(List<AgentTool> tools) {
    final indexed = <String, AgentTool>{};
    for (final tool in tools) {
      if (indexed.containsKey(tool.definition.name)) {
        throw ArgumentError('工具名称重复：${tool.definition.name}');
      }
      indexed[tool.definition.name] = tool;
    }
    return Map.unmodifiable(indexed);
  }

  void _validateResponse(
    ModelResponse response,
    Set<String> usedCallIds,
    List<AgentMessage> messages,
  ) {
    final message = response.message;
    if (messages.any((previous) => previous.id == message.id)) {
      throw const ModelException('invalid_response', '模型消息编号重复');
    }
    final batchIds = <String>{};
    for (final call in message.toolCalls) {
      if (usedCallIds.contains(call.id) || !batchIds.add(call.id)) {
        throw const ModelException('invalid_response', '模型返回了重复的工具调用编号');
      }
    }
    if (response.stopReason == ModelStopReason.toolUse &&
            message.toolCalls.isEmpty ||
        response.stopReason == ModelStopReason.completed &&
            message.toolCalls.isNotEmpty) {
      throw const ModelException('invalid_response', '模型结束原因与工具调用不一致');
    }
    if (response.stopReason == ModelStopReason.completed &&
        message.text.trim().isEmpty &&
        !message.content.whereType<ThinkingBlock>().any(
          (block) => block.text.trim().isNotEmpty,
        )) {
      throw const ModelException('invalid_response', '模型没有返回回答或思考内容');
    }
    if (jsonOutput &&
        response.stopReason == ModelStopReason.completed &&
        message.text.trim().isNotEmpty) {
      try {
        if (jsonDecode(message.text) is! Map<String, Object?>) {
          throw const FormatException();
        }
      } on FormatException {
        throw const ModelException('invalid_json', '模型未返回有效 JSON 对象，可继续请求');
      }
    }
    usedCallIds.addAll(batchIds);
  }
}

final class _ToolOutcomeUnknown implements Exception {
  const _ToolOutcomeUnknown(this.call, this.failure);
  final ToolCallBlock call;
  final AgentFailure failure;
}
