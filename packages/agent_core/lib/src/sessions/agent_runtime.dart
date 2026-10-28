import 'dart:async';

import 'package:uuid/uuid.dart';

import '../agent_event.dart';
import '../agent_loop.dart';
import '../agent_result.dart';
import '../cancellation.dart';
import '../content_block.dart';
import '../context/context_compactor.dart';
import '../message.dart';
import '../model.dart';
import '../models/configuration.dart';
import '../models/http_agent_model.dart';
import '../models/model_registry.dart';
import '../tool.dart';
import 'message_codec.dart';
import 'session_state.dart';
import 'session_store.dart';

/// 组合模型、工具和存储，管理多个独立会话；不依赖 Flutter 或业务数据库。
final class AgentRuntime {
  AgentRuntime({
    required this.configuration,
    required this.store,
    required CredentialResolver credentials,
    required List<AgentTool> tools,
    required this.authorize,
    Map<String, AgentModel> modelOverrides = const {},
    this.tokenEstimator = const ConservativeTokenEstimator(),
  }) : tools = List.unmodifiable(tools),
       _models = ModelRegistry(
         configuration: configuration,
         credentials: credentials,
         overrides: modelOverrides,
       ) {
    final names = <String>{};
    for (final tool in tools) {
      if (!names.add(tool.definition.name)) {
        throw ArgumentError('重复工具：${tool.definition.name}');
      }
    }
  }

  final AgentConfiguration configuration;
  final SessionStore store;
  final List<AgentTool> tools;
  final ToolAuthorizer authorize;
  final TokenEstimator tokenEstimator;
  final ModelRegistry _models;
  final Map<String, AgentSession> _sessions = {};
  bool _closed = false;
  Future<void>? _closing;

  Future<AgentSession> createSession({
    String? id,
    String title = '新会话',
    String systemPrompt = '你是一个可靠的助理，依据真实工具结果回答，并区分事实与推测。',
    String? modelProfileId,
    String? summaryProfileId,
  }) async {
    _checkOpen();
    final selected = modelProfileId ?? configuration.defaultModelProfile;
    final summary = summaryProfileId ?? configuration.summaryModelProfile;
    configuration.profile(selected);
    configuration.profile(summary);
    final handle = await store.create(id ?? const Uuid().v4());
    try {
      await handle.append('session_created', {
        'id': handle.id,
        'title': title,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'systemPrompt': systemPrompt,
        'modelProfileId': selected,
        'summaryProfileId': summary,
        'modelProfile': configuration.profile(selected).toJson(),
        'summaryProfile': configuration.profile(summary).toJson(),
      });
      return await _attach(handle);
    } catch (error) {
      await handle.close();
      rethrow;
    }
  }

  Future<AgentSession> openSession(String id) async {
    _checkOpen();
    if (_sessions.containsKey(id)) throw StateError('这个会话已经打开');
    final handle = await store.open(id);
    try {
      return await _attach(handle);
    } catch (error) {
      await handle.close();
      rethrow;
    }
  }

  Future<AgentSession> _attach(SessionHandle handle) async {
    _checkOpen();
    final state = SessionState.fromRecords(handle.records);
    if (state.id != handle.id) throw const FormatException('会话内容与存储编号不匹配');
    configuration.profile(state.modelProfileId);
    configuration.profile(state.summaryProfileId);
    final session = AgentSession._(this, handle, state);
    await session._recoverInterruptedTurn();
    _checkOpen();
    _sessions[handle.id] = session;
    return session;
  }

  Future<List<String>> listSessionIds() {
    _checkOpen();
    return store.listSessionIds();
  }

  /// 导入先验证全部逻辑，再以单条种子记录提交，避免出现半份已接受历史。
  Future<AgentSession> importSession(
    Map<String, Object?> exported, {
    String? id,
    String? title,
  }) async {
    _checkOpen();
    if (exported['format'] != 'agent_core_export' || exported['version'] != 1) {
      throw const FormatException('不支持的会话导出格式');
    }
    final raw = exported['records'];
    if (raw is! List<Object?>) throw const FormatException('缺少导出记录');
    final supplied = raw
        .map((value) => SessionRecord.fromJson(readObject(value)))
        .toList();
    // 先校验原始序号，再展开种子；展开时重编号不能掩盖损坏的导出记录。
    final original = SessionState.fromRecords(supplied);
    final records = _flattenRecords(supplied);
    configuration.profile(original.modelProfileId);
    configuration.profile(original.summaryProfileId);
    final handle = await store.create(id ?? const Uuid().v4());
    try {
      await handle.append('session_imported', {
        'id': handle.id,
        'title': title ?? original.title,
        'records': records.map((record) => record.toJson()).toList(),
      });
      return await _attach(handle);
    } catch (error) {
      await handle.close();
      rethrow;
    }
  }

  void _checkOpen() {
    if (_closed) throw StateError('AgentRuntime 已关闭');
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    try {
      await Future.wait(
        _sessions.values.toList().map((session) => session.close()),
      );
    } finally {
      _models.close();
    }
  }
}

/// 对外的会话入口；用户输入、模型配置和压缩投影都由该会话持有。
final class AgentSession {
  AgentSession._(this._runtime, this._handle, this._state);
  final AgentRuntime _runtime;
  final SessionHandle _handle;
  SessionState _state;
  final _events = StreamController<AgentEvent>.broadcast();
  bool _closed = false;
  bool _unhealthy = false;
  bool _busy = false;
  CancellationToken? _cancellation;
  Completer<void>? _workDone;
  Future<void>? _closing;

  String get id => _state.id;
  String get title => _state.title;
  String get systemPrompt => _state.systemPrompt;
  String get modelProfileId => _state.modelProfileId;
  String get summaryProfileId => _state.summaryProfileId;
  bool get isRunning => _busy;
  bool get needsOutcomeResolution => _state.needsOutcomeResolution;
  Map<String, ToolResultMessage> get unknownOutcomes => _state.unknownOutcomes;
  List<AgentMessage> get transcript => _state.transcript;
  List<AgentMessage> get contextMessages => _state.contextMessages;
  List<SessionRecord> get records => _handle.records;
  Stream<AgentEvent> get events => _events.stream;

  Future<AgentRunResult> send(String input) => _run(UserMessage(text: input));
  Future<AgentRunResult> sendMessage(UserMessage message) => _run(message);

  Future<AgentRunResult> resume() {
    _checkIdle();
    if (_state.transcript.isEmpty ||
        _state.lastStopReason == AgentStopReason.completed ||
        _state.lastStopReason == AgentStopReason.refused) {
      throw StateError('当前没有待继续的中断轮次，请发送新的输入');
    }
    return _run(null);
  }

  Future<AgentRunResult> _run(UserMessage? input) async {
    _checkIdle();
    if (input != null &&
        input.text.trim().isEmpty &&
        !input.content.any((block) => block is! TextBlock)) {
      throw ArgumentError('用户输入不能为空');
    }
    if (needsOutcomeResolution) throw StateError('先核对结果未知的工具，再继续这个会话');
    final token = _beginWork();
    AgentLoop? loop;
    try {
      await _record('turn_started', {
        'turnId': const Uuid().v4(),
        'resume': input == null,
      });
      final profile = _runtime.configuration.profile(modelProfileId);
      loop = AgentLoop(
        model: _runtime._models.model(modelProfileId),
        systemPrompt: systemPrompt,
        tools: _runtime.tools,
        authorize: _runtime.authorize,
        maxSteps: _runtime.configuration.maxSteps,
        compactor: _compactor(),
        retry: profile.retry,
        sessionId: id,
      );
      final result = await loop.run(
        userMessage: input,
        history: transcript,
        contextHistory: contextMessages,
        cancellation: token,
        onEvent: _observe,
      );
      if (result.failure?.code == 'persistence_failed') {
        _unhealthy = true;
        _events.add(AgentRunFinished(result.modelSteps, result));
      }
      return result;
    } on AgentPersistenceException {
      _unhealthy = true;
      rethrow;
    } finally {
      await loop?.close();
      _endWork();
    }
  }

  ContextCompactor _compactor() => ContextCompactor(
    policy: _runtime.configuration.context,
    conversationProfile: _runtime.configuration.profile(modelProfileId),
    summaryProfile: _runtime.configuration.profile(summaryProfileId),
    summaryModel: _runtime._models.model(summaryProfileId),
    estimator: _runtime.tokenEstimator,
  );

  Future<ContextCompaction?> compact() async {
    _checkIdle();
    if (needsOutcomeResolution) throw StateError('先核对结果未知的工具');
    final token = _beginWork();
    try {
      final result = await _compactor().prepare(
        ModelRequest(
          systemPrompt: systemPrompt,
          messages: contextMessages,
          tools: _runtime.tools.map((tool) => tool.definition).toList(),
        ),
        token,
        trigger: CompactionTrigger.manual,
        onEvent: _observe,
      );
      if (result != null) await _observe(ContextCompacted(0, result));
      return result;
    } finally {
      _endWork();
    }
  }

  Future<void> injectContext({
    required String source,
    required String text,
  }) async {
    await _mutate(
      () => _record('message_added', {
        'message': encodeMessage(ContextMessage(source: source, text: text)),
      }),
    );
  }

  Future<void> selectModels({String? conversation, String? summary}) async {
    await _mutate(() async {
      final nextModel = conversation ?? modelProfileId;
      final nextSummary = summary ?? summaryProfileId;
      final model = _runtime.configuration.profile(nextModel);
      final summarizer = _runtime.configuration.profile(nextSummary);
      await _record('models_changed', {
        'modelProfileId': nextModel,
        'summaryProfileId': nextSummary,
        'modelProfile': model.toJson(),
        'summaryProfile': summarizer.toJson(),
      });
    });
  }

  Future<void> setSystemPrompt(String prompt) async {
    await _mutate(
      () => _record('system_prompt_changed', {'systemPrompt': prompt}),
    );
  }

  /// 宿主查询真实业务结果后调用；核对事实追加到日志，不删除原先的不确定记录。
  Future<void> resolveToolOutcome(
    String callId,
    ToolOutput actual, {
    required String source,
  }) async {
    await _mutate(() async {
      if (!unknownOutcomes.containsKey(callId)) {
        throw ArgumentError('没有该结果未知的调用');
      }
      if (actual.errorCode == 'outcome_unknown') {
        throw ArgumentError('核对必须给出已知结果');
      }
      final notice = ContextMessage(
        source: source,
        text:
            '工具调用 $callId 的执行结果已核对。isError=${actual.isError}；真实结果：${actual.text}',
      );
      await _record('tool_outcome_resolved', {
        'callId': callId,
        'notice': encodeMessage(notice),
      });
    });
  }

  AgentMessage? messageById(String messageId) => _state.messageById(messageId);

  Map<String, Object?> export() {
    _checkIdle();
    return {
      'format': 'agent_core_export',
      'version': 1,
      'records': _flattenRecords(
        records,
      ).map((record) => record.toJson()).toList(),
    };
  }

  Future<AgentSession> fork({String? throughMessageId, String? title}) async {
    _checkIdle();
    var prefix = _flattenRecords(records);
    if (throughMessageId != null) {
      final index = prefix.indexWhere(
        (record) =>
            record.type == 'message_added' &&
            readObject(record.data['message'])['id'] == throughMessageId,
      );
      if (index < 0) throw ArgumentError('找不到分支消息');
      prefix = prefix.take(index + 1).toList();
      final state = SessionState.fromRecords(prefix);
      if (state.pendingCalls.isNotEmpty) throw ArgumentError('分支不能切开工具调用与结果');
    }
    return _runtime.importSession({
      'format': 'agent_core_export',
      'version': 1,
      'records': prefix.map((record) => record.toJson()).toList(),
    }, title: title ?? '${this.title} · 分支');
  }

  Future<void> _observe(AgentEvent event) async {
    switch (event) {
      case UserMessageAccepted():
        await _record('message_added', {
          'message': encodeMessage(event.message),
        });
      case AssistantReceived():
        await _record('message_added', {
          'message': encodeMessage(event.message),
          'usage': event.usage.toJson(),
        });
      case ToolExecutionStarted():
        await _record('tool_execution_started', {'callId': event.call.id});
      case ToolCallFinished():
        await _record('message_added', {
          'message': encodeMessage(event.result),
        });
      case ModelAttemptStarted():
        final request = event.request;
        final profileId = request.purpose == ModelRequestPurpose.summary
            ? summaryProfileId
            : modelProfileId;
        await _record('request_prepared', {
          'step': event.step,
          'attempt': event.attempt,
          'purpose': request.purpose.name,
          'profile': _runtime.configuration.profile(profileId).toJson(),
          'systemPrompt': request.systemPrompt,
          'maxOutputTokens': request.maxOutputTokens,
          'tools': request.tools
              .map(
                (tool) => {
                  'name': tool.name,
                  'description': tool.description,
                  'inputSchema': tool.inputSchema,
                },
              )
              .toList(),
          if (request.purpose == ModelRequestPurpose.summary)
            'messages': request.messages.map(encodeMessage).toList()
          else
            'messageIds': request.messages
                .map((message) => message.id)
                .toList(),
        });
      case ModelAttemptFailed():
        await _record('request_failed', {
          'step': event.step,
          'attempt': event.attempt,
          'code': event.failure.code,
          'message': event.failure.message,
          'willRetry': event.willRetry,
          'partialText': event.partialText,
          'delayMs': event.delay.inMilliseconds,
        });
      case ContextCompacted():
        final compaction = event.compaction;
        await _record('context_compacted', {
          'summary': encodeMessage(compaction.summary),
          'contextMessageIds': compaction.contextMessages
              .map((message) => message.id)
              .toList(),
          'beforeTokens': compaction.beforeTokens,
          'afterTokens': compaction.afterTokens,
          'usage': compaction.usage.toJson(),
          'summaryRequests': compaction.summaryRequests,
        });
      case AgentRunFinished():
        await _record('turn_ended', {
          'turnId': _state.openTurnId,
          'reason': event.result.reason.name,
          'failureCode': event.result.failure?.code,
          'usage': event.result.usage.toJson(),
          'modelSteps': event.result.modelSteps,
          'modelAttempts': event.result.modelAttempts,
        });
      case ModelRequestStarted() || ModelStreamUpdated() || ToolCallStarted():
        break;
    }
    _events.add(event);
  }

  Future<void> _record(String type, Map<String, Object?> data) async {
    try {
      final candidate = SessionRecord(
        sequence: records.length,
        timestamp: DateTime.now().toUtc(),
        type: type,
        data: data,
      );
      final nextState = _state.copy()..apply(candidate);
      await _handle.append(type, candidate.data);
      _state = nextState; // 持久化成功后再公布新状态；失败不污染已接受的历史。
    } catch (error) {
      _unhealthy = true;
      throw AgentPersistenceException(
        '会话保存失败，后续操作已停止；请关闭并重新打开核对结果',
        cause: error,
      );
    }
  }

  Future<void> _recoverInterruptedTurn() async {
    if (_handle.recoveredTailBytes > 0) {
      await _record('storage_tail_recovered', {
        'bytes': _handle.recoveredTailBytes,
      });
    }
    if (_state.openTurnId == null) return;
    for (final call in _state.pendingCalls.values.toList()) {
      final started = _state.startedCallIds.contains(call.id);
      final output = ToolOutput.failure(
        started ? 'outcome_unknown' : 'interrupted_not_executed',
        started ? '程序在工具执行期间中断，必须核对真实结果，未自动重放' : '程序中断，该工具尚未开始，未自动执行',
      );
      await _record('message_added', {
        'message': encodeMessage(
          ToolResultMessage(
            toolCallId: call.id,
            toolName: call.name,
            text: output.text,
            isError: true,
            errorCode: output.errorCode,
          ),
        ),
      });
    }
    await _record('turn_ended', {
      'turnId': _state.openTurnId,
      'reason': AgentStopReason.interrupted.name,
    });
  }

  CancellationToken _beginWork() {
    _busy = true;
    _workDone = Completer<void>();
    return _cancellation = CancellationToken();
  }

  Future<T> _mutate<T>(Future<T> Function() action) async {
    _checkIdle();
    _beginWork();
    try {
      return await action();
    } finally {
      _endWork();
    }
  }

  void _endWork() {
    _busy = false;
    _cancellation = null;
    _workDone?.complete();
    _workDone = null;
  }

  void _checkIdle() {
    if (_closed || _unhealthy) throw StateError('会话已关闭或存储失败，需要重新打开');
    if (_busy) throw StateError('会话正在运行，请先等待结束或取消');
  }

  void cancel() => _cancellation?.cancel();
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    cancel();
    await _workDone?.future;
    try {
      await _handle.close();
    } finally {
      _runtime._sessions.remove(id);
      await _events.close();
    }
  }
}

List<SessionRecord> _flattenRecords(
  List<SessionRecord> records, {
  int depth = 0,
}) {
  if (depth > 32 || records.isEmpty) throw const FormatException('会话种子嵌套过深或为空');
  var expanded = records;
  final first = records.first;
  if (first.type == 'session_imported') {
    final raw = first.data['records'];
    if (raw is! List<Object?>) throw const FormatException('会话种子无效');
    final seed = _flattenRecords(
      raw.map((value) => SessionRecord.fromJson(readObject(value))).toList(),
      depth: depth + 1,
    );
    expanded = [
      SessionRecord(
        sequence: 0,
        timestamp: first.timestamp,
        type: 'session_created',
        data: {
          ...seed.first.data,
          'id': first.data['id'],
          'title': first.data['title'],
          'createdAt': first.timestamp.toUtc().toIso8601String(),
          'importedFrom': seed.first.data['id'],
        },
      ),
      ...seed.skip(1),
      ...records.skip(1),
    ];
  }
  return [
    for (var index = 0; index < expanded.length; index++)
      SessionRecord(
        sequence: index,
        timestamp: expanded[index].timestamp,
        type: expanded[index].type,
        data: expanded[index].data,
      ),
  ];
}
