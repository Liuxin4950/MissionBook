part of 'assistant_controller.dart';

/// 助手控制器的独立职责；状态和生命周期由主控制器持有。
class _AssistantOperations {
  _AssistantOperations(this._controller);
  final AssistantController _controller;

  bool get canContinueInterrupted => _controller.canContinueInterrupted;
  bool get initialized => _controller.initialized;
  bool get initializing => _controller.initializing;
  bool get isRunning => _controller.isRunning;
  bool get configuring => _controller.configuring;
  bool get isBusy => _controller.isBusy;
  int get contextWindowTokens => _controller.contextWindowTokens;
  int get estimatedContextTokens => _controller.estimatedContextTokens;
  bool get compacting => _controller.compacting;
  bool get hasCredential => _controller.hasCredential;
  ModelProfile? get customProfile => _controller.customProfile;
  bool get autoApproveWrites => _controller.autoApproveWrites;
  AssistantPermissionMode get permissionMode => _controller.permissionMode;
  AssistantSpeechSettings get speechSettings => _controller.speechSettings;
  AssistantPersona get persona => _controller.persona;

  bool get hasTranscriptionCredential => _controller.hasTranscriptionCredential;
  bool get supportsImages => _controller.supportsImages;
  String get modelProfileId => _controller.modelProfileId;
  String get sessionTitle => _controller.sessionTitle;
  String? get currentSessionId => _controller.currentSessionId;
  AssistantReference? get reference => _controller.reference;
  String? get errorMessage => _controller.errorMessage;
  String? get lastUserInput => _controller.lastUserInput;
  bool get localLoading => _controller.localLoading;
  String? get localScheduleDate => _controller.localScheduleDate;
  List<ScheduledMission>? get localSchedule => _controller.localSchedule;
  List<AssistantConversationSummary> get conversations =>
      _controller.conversations;
  List<AgentMessage> get transcript => _controller.transcript;
  SessionActivity get activity => _controller.activity;
  List<AssistantOperation> get operations => _controller.operations;
  bool get needsOutcomeResolution => _controller.needsOutcomeResolution;

  Future<void> resolveUnknownOutcome(String callId) async {
    final session = _controller._requireSession();
    final unknown = session.unknownOutcomes[callId];
    final operation = _controller._operations[callId];
    if (unknown == null || operation == null) return;
    try {
      final output = await _controller._tools.recoverOutcome(
        toolName: operation.toolName,
        idempotencyKey: '${session.id}:$callId',
        input: operation.input,
      );
      if (output == null) {
        _controller._setError('暂时没有查到可确认的结果，请打开原任务或目标人工核对');
        return;
      }
      await session.resolveToolOutcome(
        callId,
        output,
        source: 'mission_book_recovery',
      );
      _controller._errorMessage = null;
      _controller._refreshSnapshot();
    } catch (error) {
      _controller._setError(userErrorMessage(error, fallback: '结果核对失败，请重试'));
    }
  }

  String? updateProposal(String callId, Map<String, Object?> input) {
    final pending = _controller._pending[callId];
    if (pending == null || pending.decided) return '这份提案已失效，请重新检查';
    if (pending.operation.toolName == 'mission_plan') {
      final oldItems = {
        for (final item in AssistantScheduleService.rows(
          pending.prepared.input,
        ))
          item['itemId']: item,
      };
      if (input['items'] is! List) return '计划条目格式无效';
      for (final value in input['items'] as List) {
        if (value is! Map) return '计划条目格式无效';
        final old = oldItems[value['itemId']];
        if (old == null) return '不能在编辑时增加未确认的条目，请重新提出计划';
        for (final field in ['kind', 'missionId', 'goalId', 'goalNodeId']) {
          if (value[field] != old[field]) return '不能在编辑时更换任务或归属';
        }
        if (old['kind'] == 'RESCHEDULE' && value['title'] != old['title']) {
          return '批量改期保留原任务名称，请使用任务编辑修改名称';
        }
      }
    }
    for (final key in ['missionId', 'goalId', 'nodeId']) {
      if (input[key] != pending.prepared.input[key]) {
        return '不能在编辑提案时更换操作对象，请取消后重新提出';
      }
    }
    if (pending.operation.toolName == 'mission_complete_history' &&
        input['beforeDate'] != pending.prepared.input['beforeDate']) {
      return '日期范围变化后需要重新预览，请取消并重新提出';
    }
    final validation = _controller._tools.validate(
      pending.operation.toolName,
      input,
    );
    if (validation != null) return validation;
    pending.prepared.input = Map<String, Object?>.unmodifiable(input);
    pending.operation.input = pending.prepared.input;
    if (pending.operation.toolName == 'mission_plan') {
      pending.operation.planPreviewReady = false;
    }
    _controller._notifyListeners();
    return null;
  }

  /// 用户编辑后检查当前排期；旧检查返回时不能覆盖后来的一份预览。
  Future<String?> refreshPlanPreview(String callId) async {
    final pending = _controller._pending[callId];
    if (pending == null || pending.decided) return '这份计划已失效';
    final operation = pending.operation;
    final input = pending.prepared.input;
    operation
      ..planChecking = true
      ..planPreviewReady = false
      ..planPreviewError = null;
    _controller._notifyListeners();
    String? error;
    try {
      final conflicts = await _controller._tools.previewPlan(pending.prepared);
      if (_controller._pending[callId] == pending &&
          identical(input, pending.prepared.input)) {
        operation
          ..planConflicts = conflicts
          ..planPreviewReady = true;
      }
    } catch (failure) {
      error = '计划检查失败：$failure';
      operation.planPreviewError = error;
    } finally {
      operation.planChecking = false;
      _controller._notifyListeners();
    }
    return error;
  }

  String? confirmProposal(String callId) {
    final pending = _controller._pending[callId];
    if (pending == null || pending.decided) return '这份提案已失效，请重新检查';
    if (pending.operation.toolName == 'mission_plan' &&
        (!pending.operation.planPreviewReady ||
            pending.operation.planChecking ||
            pending.operation.planConflicts.isNotEmpty)) {
      return '请先完成计划检查并调整有冲突的安排';
    }
    final validation = _controller._tools.validate(
      pending.operation.toolName,
      pending.prepared.input,
    );
    if (validation != null) return validation;
    pending.decided = true;
    pending.operation.status = AssistantOperationStatus.running;
    pending.completer.complete(
      ToolDecision.allowWithInput(pending.prepared.input),
    );
    _controller._notifyListeners();
    return null;
  }

  void cancelProposal(String callId) {
    final pending = _controller._pending[callId];
    if (pending == null || pending.decided) return;
    pending.decided = true;
    pending.operation.status = AssistantOperationStatus.cancelled;
    pending.completer.complete(const ToolDecision.deny('用户取消了这份操作提案'));
    _controller._notifyListeners();
  }

  Future<ToolDecision> _authorize(
    ToolDefinition tool,
    ToolCallBlock call,
    CancellationToken cancellation,
  ) async {
    final toolName = AssistantTools.legacyName(tool.name);
    final isWrite = AssistantTools.writeToolNames.contains(toolName);
    if (!isWrite &&
        !_controller._settings.permissionMode.requiresConfirmation(
          isWrite: false,
        )) {
      return const ToolDecision.allow();
    }
    final PreparedToolCall prepared;
    try {
      prepared = await _controller._tools.prepare(tool.name, call.input);
    } on ToolRejected catch (error) {
      return ToolDecision.deny(error.message);
    }
    _controller._preparedCalls[call.id] = prepared;
    final operation = _operationFor(call);
    operation
      ..input = prepared.input
      ..targetTitle = prepared.snapshot['targetTitle'] as String?
      ..historyMissions =
          prepared.snapshot['historyMissions'] as List<MissionDetail>? ??
          const []
      ..historySkippedCount =
          prepared.snapshot['historySkippedCount'] as int? ?? 0
      ..missionBefore = prepared.snapshot['detail'] as MissionDetail?
      ..status = AssistantOperationStatus.waitingConfirmation;
    if (toolName == 'mission_plan') {
      operation
        ..planConflicts =
            prepared.snapshot['planConflicts'] as List<ScheduleConflict>
        ..planOriginals =
            prepared.snapshot['planOriginals'] as Map<String, MissionDetail>
        ..planPreviewReady = true;
    }
    if (!_controller._settings.permissionMode.requiresConfirmation(
      isWrite: isWrite,
    )) {
      operation.status = AssistantOperationStatus.running;
      return ToolDecision.allowWithInput(prepared.input);
    }
    final pending = _PendingAuthorization(prepared, operation);
    _controller._pending[call.id] = pending;
    _refreshOperations();
    try {
      return await cancellation.wait(pending.completer.future);
    } finally {
      _controller._pending.remove(call.id);
      if (!pending.decided) {
        pending.operation.status = AssistantOperationStatus.cancelled;
      }
      _refreshOperations();
    }
  }

  PreparedToolCall _resolveCall(String callId) {
    final prepared = _controller._preparedCalls[callId];
    if (prepared == null) throw StateError('找不到这次操作的固定提案');
    return prepared;
  }

  AssistantOperation _operationFor(ToolCallBlock call) =>
      _controller._operations[call.id] ??= AssistantOperation(
        callId: call.id,
        toolName: AssistantTools.legacyName(call.name),
        input: call.input,
      );

  void _refreshOperations() {
    for (final message in _controller._transcript) {
      if (message is AssistantMessage) {
        for (final call in message.toolCalls) {
          final operation = _operationFor(call);
          if (operation.output == null &&
              !_controller._pending.containsKey(call.id)) {
            operation.input =
                _controller._session?.executedCalls[call.id]?.input ??
                call.input;
          }
        }
      } else if (message is ToolResultMessage) {
        final operation = _controller._operations[message.toolCallId];
        if (operation == null) continue;
        final resolved =
            _controller._session?.resolvedOutcomes[message.toolCallId];
        operation.output = resolved?.text ?? message.text;
        operation.error =
            resolved?.errorCode ??
            (resolved == null ? message.errorCode : null);
        operation.status = switch (operation.error) {
          'outcome_unknown' => AssistantOperationStatus.unknown,
          'permission_denied' => AssistantOperationStatus.cancelled,
          null =>
            (resolved?.isError ?? message.isError)
                ? AssistantOperationStatus.failed
                : AssistantOperationStatus.succeeded,
          _ => AssistantOperationStatus.failed,
        };
      }
    }
    for (final entry in _controller._pending.entries) {
      final operation = _controller._operations[entry.key];
      if (operation != null) {
        operation
          ..input = entry.value.prepared.input
          ..status = AssistantOperationStatus.waitingConfirmation;
      }
    }
    _controller._notifyListeners();
  }
}
