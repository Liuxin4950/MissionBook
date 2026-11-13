import '../agent_result.dart';
import '../content_block.dart';
import '../message.dart';
import '../model.dart';
import '../models/configuration.dart';
import '../tool.dart';
import 'message_codec.dart';
import 'session_store.dart';
import 'session_usage.dart';
import 'copy_on_write.dart';

/// 从已提交日志推导会话；原始消息与发给模型的压缩投影分别维护。
final class SessionState {
  final int _seedDepth;
  String? _id;
  String get id => _id ?? (throw StateError('缺少 session_created'));
  late String title;
  late DateTime createdAt;
  late String systemPrompt;
  late String modelProfileId;
  late String summaryProfileId;
  int? outputTokens;
  ReasoningEffort? reasoningEffort;
  bool jsonOutput = false;
  String? openTurnId;
  AgentStopReason? lastStopReason;
  int _nextSequence = 0;
  SessionUsage _sessionUsage = const SessionUsage();
  SessionUsage get sessionUsage => _sessionUsage;
  CowList<InterruptedModelAttempt> _interruptedAttempts = CowList();
  List<InterruptedModelAttempt> get interruptedAttempts =>
      List.unmodifiable(_interruptedAttempts);
  CowList<AgentMessage> _transcript = CowList();
  CowList<AgentMessage> _context = CowList();
  CowMap<String, AgentMessage> _knownMessages = CowMap();
  CowMap<String, AgentMessage> _projectionOverrides = CowMap();
  CowSet<String> _refreshToolNames = CowSet();
  Set<String> get refreshToolNames => Set.unmodifiable(_refreshToolNames);
  CowMap<String, ToolCallBlock> _pending = CowMap();
  CowSet<String> _started = CowSet();
  CowMap<String, ToolCallBlock> _executedCalls = CowMap();
  Map<String, ToolCallBlock> get executedCalls =>
      Map.unmodifiable(_executedCalls);
  CowSet<String> _startedReadOnly = CowSet();
  CowSet<String> _usedCallIds = CowSet();
  CowMap<String, ToolResultMessage> _unknown = CowMap();
  CowMap<String, ToolOutput> _resolved = CowMap();
  CowSet<String> _requestSpecs = CowSet();
  bool _legacyCompaction = false;
  CowSet<String> _legacyContextIds = CowSet();
  Map<String, ToolOutput> get resolvedOutcomes => Map.unmodifiable(_resolved);
  bool hasRequestSpec(String id) => _requestSpecs.contains(id);
  List<AgentMessage> get transcript => List.unmodifiable(_transcript);
  int get transcriptLength => _transcript.length;
  String? get lastTranscriptMessageId =>
      _transcript.isEmpty ? null : _transcript.last.id;
  List<AgentMessage> get contextMessages => List.unmodifiable(_context);
  Map<String, ToolCallBlock> get pendingCalls => Map.unmodifiable(_pending);
  Set<String> get startedCallIds => Set.unmodifiable(_started);
  Set<String> get readOnlyCallIds => Set.unmodifiable(_startedReadOnly);
  Map<String, ToolResultMessage> get unknownOutcomes =>
      Map.unmodifiable(_unknown);
  bool get needsOutcomeResolution => _unknown.isNotEmpty;
  AgentMessage? messageById(String id) => _knownMessages[id];

  void apply(SessionRecord record) {
    if (record.sequence != _nextSequence) {
      throw const FormatException('日志序号不连续');
    }
    if (record.version != 1) {
      if (record.ignorable) {
        _nextSequence++;
        return;
      }
      throw FormatException('会话记录版本 ${record.version} 不受支持，请升级应用；原记录保留');
    }
    if (_id == null &&
        record.type != 'session_created' &&
        record.type != 'session_imported') {
      throw const FormatException('会话必须先创建');
    }
    final data = record.data;
    switch (record.type) {
      case 'session_imported':
        if (_id != null) throw const FormatException('不能向已有会话导入种子');
        final seed = data['records'];
        if (seed is! List<Object?>) throw const FormatException('导入缺少原始记录');
        final original = SessionState.fromRecords(
          seed.map((item) => SessionRecord.fromJson(readObject(item))).toList(),
          seedDepth: _seedDepth + 1,
        );
        _id = readString(data, 'id');
        title = readString(data, 'title');
        createdAt = record.timestamp;
        systemPrompt = original.systemPrompt;
        modelProfileId = original.modelProfileId;
        summaryProfileId = original.summaryProfileId;
        openTurnId = original.openTurnId;
        lastStopReason = original.lastStopReason;
        _transcript.addAll(original._transcript);
        _interruptedAttempts.addAll(original._interruptedAttempts);
        _context.addAll(original._context);
        _knownMessages.addAll(original._knownMessages);
        _projectionOverrides.addAll(original._projectionOverrides);
        _refreshToolNames.addAll(original._refreshToolNames);
        _pending.addAll(original._pending);
        _started.addAll(original._started);
        _executedCalls.addAll(original._executedCalls);
        _startedReadOnly.addAll(original._startedReadOnly);
        _usedCallIds.addAll(original._usedCallIds);
        _unknown.addAll(original._unknown);
        _resolved.addAll(original._resolved);
        _requestSpecs.addAll(original._requestSpecs);
        outputTokens = original.outputTokens;
        reasoningEffort = original.reasoningEffort;
        jsonOutput = original.jsonOutput;
        _sessionUsage = original._sessionUsage;
      case 'session_created':
        if (_id != null) throw const FormatException('会话重复创建');
        _id = readString(data, 'id');
        title = readString(data, 'title');
        createdAt = DateTime.parse(readString(data, 'createdAt'));
        systemPrompt = readString(data, 'systemPrompt');
        modelProfileId = readString(data, 'modelProfileId');
        summaryProfileId = readString(data, 'summaryProfileId');
      case 'turn_started':
        if (openTurnId != null || _pending.isNotEmpty || _unknown.isNotEmpty) {
          throw const FormatException('旧轮次或未知工具结果尚未处理');
        }
        openTurnId = readString(data, 'turnId');
      case 'message_added':
        _addMessage(decodeMessage(readObject(data['message'])));
      case 'tool_execution_started':
        final callId = readString(data, 'callId');
        if (!_pending.containsKey(callId) || !_started.add(callId)) {
          throw const FormatException('工具执行没有唯一的待处理调用');
        }
        final proposed = _pending[callId]!;
        _executedCalls[callId] = ToolCallBlock(
          id: callId,
          name: proposed.name,
          input: data['input'] == null
              ? proposed.input
              : readObject(data['input']),
        );
        if (data['readOnly'] == true) _startedReadOnly.add(callId);
      case 'turn_ended':
        if (openTurnId == null ||
            readString(data, 'turnId') != openTurnId ||
            _pending.isNotEmpty) {
          throw const FormatException('轮次结束不匹配或工具未结算');
        }
        lastStopReason = AgentStopReason.values.firstWhere(
          (reason) => reason.name == readString(data, 'reason'),
          orElse: () => throw const FormatException('未知的轮次结束原因'),
        );
        openTurnId = null;
      case 'context_compacted':
        if (_pending.isNotEmpty) throw const FormatException('不能压缩未结算的工具');
        final summary = decodeMessage(readObject(data['summary']));
        if (summary is! ContextSummaryMessage ||
            _knownMessages.containsKey(summary.id)) {
          throw const FormatException('无效摘要');
        }
        for (final sourceId in summary.summarizedMessageIds) {
          final source = _knownMessages[sourceId];
          if (source == null) {
            throw const FormatException('摘要引用了不存在的原始消息');
          }
          if (summary.isSafe &&
              (source is ContextMessage && source.isPinned ||
                  source is ContextSummaryMessage)) {
            throw const FormatException('安全摘要不能覆盖供给或嵌套摘要编号');
          }
        }
        final ids = data['contextMessageIds'];
        if (ids is! List<Object?> || ids.any((id) => id is! String)) {
          throw const FormatException('无效压缩投影');
        }
        final projection = <AgentMessage>[];
        final seen = <String>{};
        for (final id in ids.cast<String>()) {
          if (!seen.add(id)) throw const FormatException('投影消息重复');
          final message = id == summary.id
              ? summary
              : (_projectionOverrides[id] ?? _knownMessages[id]);
          if (message == null) throw const FormatException('投影引用了不存在的消息');
          projection.add(message);
        }
        if (!seen.contains(summary.id)) throw const FormatException('投影缺少摘要');
        validateConversation(projection);
        _knownMessages[summary.id] = summary;
        // 先恢复日志当时的投影，后续 request_prepared 仍须按原顺序严格校验。
        _context
          ..clear()
          ..addAll(projection);
        _legacyContextIds.clear();
        _legacyCompaction = data['supplyExcluded'] != true;
        if (_legacyCompaction) {
          // 旧压缩之前的供给可能已过期；之后新注入的块仍需保留。
          _legacyContextIds.addAll(
            _transcript.whereType<ContextMessage>().map(
              (message) => message.id,
            ),
          );
        }
      case 'context_projection_reset':
        // 旧投影失效必须有日志边界，否则下次回放无法校验重建后的请求。
        finishReplay();
        final ids = data['contextMessageIds'];
        if (ids is! List<Object?> || ids.length != _context.length) {
          throw const FormatException('无效上下文重建');
        }
        for (var index = 0; index < ids.length; index++) {
          if (ids[index] != _context[index].id) {
            throw const FormatException('上下文重建与原始记录不一致');
          }
        }
      case 'tool_results_invalidated':
        if (openTurnId != null || _pending.isNotEmpty) {
          throw const FormatException('运行中不能失效工具投影');
        }
        final names = data['toolNames'];
        if (names is! List<Object?> || names.any((name) => name is! String)) {
          throw const FormatException('无效工具名称');
        }
        _refreshToolNames.addAll(names.cast<String>());
        final replacements = staleToolProjections(_refreshToolNames);
        _projectionOverrides.addAll(replacements);
        final invalidSummaries = _context
            .whereType<ContextSummaryMessage>()
            .where(
              (summary) =>
                  !summary.isSafe ||
                  summary.summarizedMessageIds.any(replacements.containsKey),
            )
            .toList();
        final restoreIds = invalidSummaries
            .expand((summary) => summary.summarizedMessageIds)
            .toSet();
        final removedIds = invalidSummaries
            .map((summary) => summary.id)
            .toSet();
        final visibleIds = _context.map((message) => message.id).toSet()
          ..removeAll(removedIds);
        // 在被失效摘要的位置恢复其原始历史；用户原话及无关业务不丢弃。
        final restored = <AgentMessage>[];
        for (final item in _context) {
          if (removedIds.contains(item.id)) {
            for (final original in _transcript) {
              if (restoreIds.contains(original.id) &&
                  !(original is ContextMessage && original.isPinned) &&
                  visibleIds.add(original.id)) {
                restored.add(_projectionOverrides[original.id] ?? original);
              }
            }
          } else {
            restored.add(_projectionOverrides[item.id] ?? item);
          }
        }
        _context
          ..clear()
          ..addAll(restored);
        validateConversation(_context);
      case 'context_message_replaced':
        if (openTurnId != null || _pending.isNotEmpty) {
          throw const FormatException('运行中或工具未结算时不能替换上下文');
        }
        final source = readString(data, 'source');
        final ids = data['previousIds'];
        if (ids is! List<Object?> || ids.any((id) => id is! String)) {
          throw const FormatException('无效上下文替换');
        }
        final replaced = ids.cast<String>().toSet();
        for (final id in replaced) {
          final previous = _knownMessages[id];
          if (previous is! ContextMessage || previous.source != source) {
            throw const FormatException('上下文替换引用了不存在的来源');
          }
        }
        ContextMessage? message;
        if (data['message'] != null) {
          final decoded = decodeMessage(readObject(data['message']));
          if (decoded is! ContextMessage ||
              decoded.source != source ||
              _knownMessages.containsKey(decoded.id)) {
            throw const FormatException('无效上下文替换消息');
          }
          message = decoded;
        }
        // 先取出保留项再清空；级联参数在 clear 之后求值会丢掉全部历史。
        final retained = [
          for (final item in _context)
            if (!replaced.contains(item.id)) item,
        ];
        _context
          ..clear()
          ..addAll(retained);
        if (message != null) {
          // 被替换的旧块仍留在 transcript 与日志中，只退出模型可见投影。
          _knownMessages[message.id] = message;
          _transcript.add(message);
          _context.add(message);
        }
        validateConversation(_context);
      case 'models_changed':
        if (openTurnId != null) throw const FormatException('运行中不能切换模型');
        final nextModel = readString(data, 'modelProfileId');
        if (nextModel != modelProfileId) {
          outputTokens = null;
          reasoningEffort = null;
          jsonOutput = false;
        }
        modelProfileId = nextModel;
        summaryProfileId = readString(data, 'summaryProfileId');
      case 'title_changed':
        if (openTurnId != null) throw const FormatException('运行中不能改名');
        title = readString(data, 'title');
      case 'generation_changed':
        if (openTurnId != null) throw const FormatException('运行中不能修改生成设置');
        outputTokens = data['maxOutputTokens'] as int;
        reasoningEffort = ReasoningEffort.values.byName(
          readString(data, 'reasoningEffort'),
        );
        jsonOutput = data['jsonOutput'] as bool? ?? false;
      case 'system_prompt_changed':
        if (openTurnId != null) throw const FormatException('运行中不能更改系统提示');
        systemPrompt = readString(data, 'systemPrompt');
      case 'tool_outcome_resolved':
        final callId = readString(data, 'callId');
        if (_unknown.remove(callId) == null) {
          throw const FormatException('没有需要核对的工具结果');
        }
        final notice = decodeMessage(readObject(data['notice']));
        if (notice is! ContextMessage) {
          throw const FormatException('核对记录必须标明来源');
        }
        _addMessage(notice);
        if (data['actual'] != null) {
          final actual = readObject(data['actual']);
          _resolved[callId] = actual['isError'] == true
              ? ToolOutput.failure(
                  actual['errorCode'] as String? ?? 'tool_failed',
                  readString(actual, 'text'),
                )
              : ToolOutput.success(readString(actual, 'text'));
        }
      case 'request_spec_saved':
        if (!_requestSpecs.add(readString(data, 'id'))) {
          throw const FormatException('请求定义重复');
        }
      case 'request_prepared':
        if (data['specId'] != null && !_requestSpecs.contains(data['specId'])) {
          throw const FormatException('模型请求引用了不存在的定义');
        }
        final purpose = readString(data, 'purpose');
        if (purpose == 'conversation') {
          final ids = data['messageIds'];
          if (openTurnId == null ||
              ids is! List<Object?> ||
              ids.length != _context.length) {
            throw const FormatException('模型请求缺少当前轮次或完整上下文');
          }
          for (var index = 0; index < ids.length; index++) {
            if (ids[index] != _context[index].id) {
              throw const FormatException('模型请求与已保存上下文不一致');
            }
          }
        } else if (purpose == 'summary') {
          final ids = data['messageIds'];
          final extra = data['extraMessages'];
          if (ids is! List<Object?> || extra is! List<Object?>) {
            throw const FormatException('摘要请求缺少输入引用');
          }
          final available = <String, AgentMessage>{
            ..._knownMessages,
            ..._projectionOverrides,
          };
          for (final raw in extra) {
            final message = decodeMessage(readObject(raw));
            if (available.containsKey(message.id)) {
              throw const FormatException('摘要附加输入与原始消息编号重复');
            }
            available[message.id] = message;
          }
          final messages = <AgentMessage>[];
          for (final id in ids) {
            final message = available[id];
            if (message == null) throw const FormatException('摘要引用了不存在的消息');
            messages.add(message);
          }
          validateConversation(messages);
        } else {
          throw const FormatException('未知模型请求用途');
        }
      case 'usage_reported':
        _applyUsage(data);
      case 'request_failed':
        final text = data['partialText'] as String? ?? '';
        final thinking = data['partialThinking'] as String? ?? '';
        final user = _transcript.whereType<UserMessage>().lastOrNull;
        if (user != null &&
            (text.isNotEmpty || thinking.isNotEmpty) &&
            data['purpose'] == ModelRequestPurpose.conversation.name) {
          _interruptedAttempts.add(
            InterruptedModelAttempt(
              id: '$id:attempt:${record.sequence}',
              userMessageId: user.id,
              messageIndex: _transcript.reversed
                  .takeWhile((m) => m is! UserMessage)
                  .whereType<AssistantMessage>()
                  .length,
              text: text,
              thinking: thinking,
              message: data['message'] as String? ?? '本次输出未完成',
              willRetry: data['willRetry'] == true,
            ),
          );
        }
      case 'storage_tail_recovered':
        break;
      default:
        if (!record.ignorable) {
          throw FormatException('不支持的会话记录类型：${record.type}；请升级应用');
        }
    }
    _nextSequence++;
  }

  void _applyUsage(Map<String, Object?> data) {
    final conversation =
        data['purpose'] == ModelRequestPurpose.conversation.name;
    try {
      final usage = TokenUsage.fromJson(readObject(data['usage']));
      _sessionUsage = _sessionUsage.record(
        usage,
        complete: data['complete'] == true,
        conversation: conversation,
      );
    } on FormatException {
      // 用量是展示信息，坏记录不能阻止会话重新打开。
      _sessionUsage = _sessionUsage.recordMalformed(conversation: conversation);
    }
  }

  void _addMessage(AgentMessage message) {
    if (message is ContextSummaryMessage ||
        (openTurnId == null && message is! ContextMessage)) {
      throw const FormatException('对话消息必须属于轮次，摘要必须经压缩记录接受');
    }
    if (_knownMessages.containsKey(message.id)) {
      throw const FormatException('消息编号重复');
    }
    if (message is ToolResultMessage) {
      if (_pending[message.toolCallId]?.name != message.toolName) {
        throw const FormatException('工具结果没有对应调用');
      }
      _pending.remove(message.toolCallId);
      _started.remove(message.toolCallId);
      _startedReadOnly.remove(message.toolCallId);
      if (message.errorCode == 'outcome_unknown') {
        _unknown[message.toolCallId] = message;
      }
    } else {
      if (_pending.isNotEmpty) throw const FormatException('旧工具调用还未结算');
      if (message is AssistantMessage) {
        for (final call in message.toolCalls) {
          if (!_usedCallIds.add(call.id)) {
            throw const FormatException('重复工具调用编号');
          }
          _pending[call.id] = call;
        }
      }
    }
    _knownMessages[message.id] = message;
    _transcript.add(message);
    _context.add(message);
  }

  factory SessionState.fromRecords(
    List<SessionRecord> records, {
    int seedDepth = 0,
  }) {
    if (seedDepth > 32) throw const FormatException('会话种子嵌套过深');
    final state = SessionState(seedDepth: seedDepth);
    for (final record in records) {
      state.apply(record);
    }
    state.id;
    state.finishReplay();
    return state;
  }

  /// 仅变更模型投影；原日志、结果编号和工具配对始终保留。
  Map<String, AgentMessage> staleToolProjections(Set<String> names) {
    final replacements = <String, AgentMessage>{};
    var dependsOnResult = false;
    for (final message in _transcript) {
      if (message is UserMessage) dependsOnResult = false;
      if (message is ToolResultMessage && names.contains(message.toolName)) {
        dependsOnResult = true;
        if (!_projectionOverrides.containsKey(message.id)) {
          replacements[message.id] = ToolResultMessage(
            id: message.id,
            toolCallId: message.toolCallId,
            toolName: message.toolName,
            text: '[${message.toolName} 旧查询结果已失效；需要当前事实时请重新查询。]',
            isError: message.isError,
            errorCode: message.errorCode,
          );
        }
      } else if (message is AssistantMessage &&
          dependsOnResult &&
          !_projectionOverrides.containsKey(message.id)) {
        // 同轮回答可能复述旧记忆；保留后续工具调用而移除文字和思考投影。
        replacements[message.id] = AssistantMessage(
          id: message.id,
          provider: message.provider,
          model: message.model,
          content: [
            const TextBlock(text: '[基于旧查询的模型说明已失效，请重新查询。]'),
            ...message.toolCalls,
          ],
        );
      }
    }
    return replacements;
  }

  /// 回放结束后处理版本化失效：旧摘要的投影不带 supplyExcluded，需按原始对话重建。
  bool finishReplay() {
    if (!_legacyCompaction) return false;
    _legacyCompaction = false;
    final currentSupplyIds = _context
        .whereType<ContextMessage>()
        .map((message) => message.id)
        .where((id) => !_legacyContextIds.contains(id))
        .toSet();
    final rebuilt = [
      for (final message in _transcript)
        if (message is! ContextSummaryMessage &&
            (message is! ContextMessage ||
                currentSupplyIds.contains(message.id)))
          _projectionOverrides[message.id] ?? message,
    ];
    _context
      ..clear()
      ..addAll(rebuilt);
    _legacyContextIds.clear();
    validateConversation(_context);
    return true;
  }

  SessionState({int seedDepth = 0}) : _seedDepth = seedDepth;

  /// O(1) 创建预校验分支，集合首次写入才复制；保存失败仍不污染原状态。
  SessionState copy() => SessionState(seedDepth: _seedDepth)
    .._id = _id
    ..title = title
    ..createdAt = createdAt
    ..systemPrompt = systemPrompt
    ..modelProfileId = modelProfileId
    ..summaryProfileId = summaryProfileId
    ..outputTokens = outputTokens
    ..reasoningEffort = reasoningEffort
    ..jsonOutput = jsonOutput
    ..openTurnId = openTurnId
    ..lastStopReason = lastStopReason
    .._nextSequence = _nextSequence
    .._sessionUsage = _sessionUsage
    .._transcript = _transcript.fork()
    .._interruptedAttempts = _interruptedAttempts.fork()
    .._context = _context.fork()
    .._knownMessages = _knownMessages.fork()
    .._projectionOverrides = _projectionOverrides.fork()
    .._refreshToolNames = _refreshToolNames.fork()
    .._pending = _pending.fork()
    .._started = _started.fork()
    .._executedCalls = _executedCalls.fork()
    .._startedReadOnly = _startedReadOnly.fork()
    .._usedCallIds = _usedCallIds.fork()
    .._unknown = _unknown.fork()
    .._resolved = _resolved.fork()
    .._requestSpecs = _requestSpecs.fork()
    .._legacyCompaction = _legacyCompaction
    .._legacyContextIds = _legacyContextIds.fork();
}

/// 中断尝试仅用于回看，不作为已完成消息或后续模型输入。
final class InterruptedModelAttempt {
  const InterruptedModelAttempt({
    required this.id,
    required this.userMessageId,
    required this.messageIndex,
    required this.text,
    required this.thinking,
    required this.message,
    required this.willRetry,
  });
  final String id;
  final String userMessageId;
  final int messageIndex;
  final String text;
  final String thinking;
  final String message;
  final bool willRetry;
}
