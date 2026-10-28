import '../agent_result.dart';
import '../content_block.dart';
import '../message.dart';
import '../models/configuration.dart';
import 'message_codec.dart';
import 'session_store.dart';

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
  String? openTurnId;
  AgentStopReason? lastStopReason;
  int _nextSequence = 0;
  final List<AgentMessage> _transcript = [];
  final List<AgentMessage> _context = [];
  final Map<String, AgentMessage> _knownMessages = {};
  final Map<String, ToolCallBlock> _pending = {};
  final Set<String> _started = {};
  final Set<String> _usedCallIds = {};
  final Map<String, ToolResultMessage> _unknown = {};
  List<AgentMessage> get transcript => List.unmodifiable(_transcript);
  List<AgentMessage> get contextMessages => List.unmodifiable(_context);
  Map<String, ToolCallBlock> get pendingCalls => Map.unmodifiable(_pending);
  Set<String> get startedCallIds => Set.unmodifiable(_started);
  Map<String, ToolResultMessage> get unknownOutcomes =>
      Map.unmodifiable(_unknown);
  bool get needsOutcomeResolution => _unknown.isNotEmpty;
  AgentMessage? messageById(String id) => _knownMessages[id];

  void apply(SessionRecord record) {
    if (record.sequence != _nextSequence) {
      throw const FormatException('日志序号不连续');
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
        _context.addAll(original._context);
        _knownMessages.addAll(original._knownMessages);
        _pending.addAll(original._pending);
        _started.addAll(original._started);
        _usedCallIds.addAll(original._usedCallIds);
        _unknown.addAll(original._unknown);
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
          if (!_knownMessages.containsKey(sourceId)) {
            throw const FormatException('摘要引用了不存在的原始消息');
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
          final message = id == summary.id ? summary : _knownMessages[id];
          if (message == null) throw const FormatException('投影引用了不存在的消息');
          projection.add(message);
        }
        if (!seen.contains(summary.id)) throw const FormatException('投影缺少摘要');
        validateConversation(projection);
        _knownMessages[summary.id] = summary;
        _context
          ..clear()
          ..addAll(projection);
      case 'models_changed':
        if (openTurnId != null) throw const FormatException('运行中不能切换模型');
        modelProfileId = readString(data, 'modelProfileId');
        summaryProfileId = readString(data, 'summaryProfileId');
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
      case 'request_prepared':
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
          final messages = data['messages'];
          if (messages is! List<Object?> || messages.isEmpty) {
            throw const FormatException('摘要请求缺少可重建的输入');
          }
          validateConversation(
            messages.map((value) => decodeMessage(readObject(value))).toList(),
          );
        } else {
          throw const FormatException('未知模型请求用途');
        }
      case 'request_failed' || 'storage_tail_recovered':
        break;
      default:
        throw FormatException('不支持的会话记录类型：${record.type}');
    }
    _nextSequence++;
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
    return state;
  }
  SessionState({int seedDepth = 0}) : _seedDepth = seedDepth;

  /// 浅复制只读消息和集合，供下一条记录的预校验；不重放整份日志。
  SessionState copy() => SessionState(seedDepth: _seedDepth)
    .._id = _id
    ..title = title
    ..createdAt = createdAt
    ..systemPrompt = systemPrompt
    ..modelProfileId = modelProfileId
    ..summaryProfileId = summaryProfileId
    ..openTurnId = openTurnId
    ..lastStopReason = lastStopReason
    .._nextSequence = _nextSequence
    .._transcript.addAll(_transcript)
    .._context.addAll(_context)
    .._knownMessages.addAll(_knownMessages)
    .._pending.addAll(_pending)
    .._started.addAll(_started)
    .._usedCallIds.addAll(_usedCallIds)
    .._unknown.addAll(_unknown);
}
