part of 'assistant_controller.dart';

/// 助手控制器的独立职责；状态和生命周期由主控制器持有。
class _AssistantSessions {
  _AssistantSessions(this._controller);
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
  String get _effectiveSystemPrompt => _controller._effectiveSystemPrompt;
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
  AgentConfiguration get _configuration => _controller._configuration;

  Future<void> openMissionReference(String missionId) async {
    final detail = await _controller._missions.findDetail(missionId: missionId);
    if (detail == null) throw StateError('任务不存在，无法带入助手');
    await _selectReference(
      AssistantReference(
        type: AssistantReferenceType.mission,
        id: missionId,
        title: detail.mission.title,
        goalId: detail.mission.goalId,
        nodeId: detail.mission.goalNodeId,
        path: detail.ownershipInfo?.label,
      ),
    );
  }

  Future<void> openGoalReference(String goalId) async {
    final goal = await _controller._goals.findById(goalId);
    if (goal == null) throw StateError('目标不存在，无法带入助手');
    await _selectReference(
      AssistantReference(
        type: AssistantReferenceType.goal,
        id: goalId,
        title: goal.title,
      ),
    );
  }

  Future<void> openNodeReference(String nodeId) async {
    final node = await _controller._goals.findNodeById(nodeId);
    if (node == null) throw StateError('节点不存在');
    final goal = await _controller._goals.findById(node.goalId);
    await _selectReference(
      AssistantReference(
        path: goal?.title,
        type: AssistantReferenceType.node,
        id: node.id,
        title: node.title,
        goalId: node.goalId,
      ),
    );
  }

  Future<void> openGlobalConversation() async {
    await _controller.initialize();
    _ensureUsable();
    if (_controller._reference == null) return;
    if (isRunning) throw StateError('请先结束当前对象的这一轮，再切换全局会话');
    final global = _controller._conversations
        .where(
          (item) =>
              item.missionId == null &&
              item.goalId == null &&
              item.nodeId == null,
        )
        .firstOrNull;
    await _closeSession();
    _controller._reference = null;
    if (global == null) {
      await _createSession();
    } else {
      await _openSession(global.id);
    }
  }

  Future<void> _selectReference(AssistantReference reference) async {
    _ensureUsable();
    if (_controller._reference?.type == reference.type &&
        _controller._reference?.id == reference.id) {
      _controller._reference = reference;
      _controller._notifyListeners();
      return;
    }
    if (isRunning) throw StateError('本轮结束后才能切换任务或目标会话');
    final matching = _controller._conversations.where(
      (item) => switch (reference.type) {
        AssistantReferenceType.mission => item.missionId == reference.id,
        AssistantReferenceType.goal =>
          item.goalId == reference.id && item.nodeId == null,
        AssistantReferenceType.node => item.nodeId == reference.id,
      },
    );
    await _closeSession();
    _controller._reference = reference;
    if (matching.isNotEmpty) {
      await _openSession(matching.first.id);
    } else {
      await _createSession();
    }
    _controller._notifyListeners();
  }

  Future<void> startNewSession({bool clearReference = true}) async {
    _ensureUsable();
    if (isRunning) throw StateError('请先等待本轮结束或停止本轮');
    await _closeSession();
    if (clearReference) _controller._reference = null;
    await _createSession();
  }

  Future<void> openConversation(String id) async {
    _ensureUsable();
    if (isRunning) throw StateError('请先等待本轮结束或停止本轮');
    if (_controller._session?.id == id) return;
    await _closeSession();
    _controller._reference = null;
    await _openSession(id);
  }

  Future<void> deleteConversation(String id) async {
    _ensureUsable();
    if (isRunning) throw StateError('请先结束当前运行，再删除会话');
    if (_controller._session?.id == id) {
      await _closeSession();
      _controller._reference = null;
    }
    await _controller._sessionStore.delete(id);
    await _refreshConversations();
    if (_controller._session == null && _controller._conversations.isNotEmpty) {
      await _openSession(_controller._conversations.first.id);
    }
    _controller._notifyListeners();
  }

  Future<void> renameCurrentSession(String title) async {
    _ensureUsable();
    final session = _requireSession();
    if (isRunning) throw StateError('本轮结束后才能修改会话名称');
    await session.rename(title);
    await _refreshConversations();
    _refreshSnapshot();
  }

  Future<void> renameConversation(String id, String title) async {
    _ensureUsable();
    if (isRunning) throw StateError('本轮结束后才能修改会话名称');
    if (id == currentSessionId) {
      await renameCurrentSession(title);
      return;
    }
    final session = await _controller._runtime!.openSession(id);
    try {
      await session.rename(title);
    } finally {
      await session.close();
    }
    await _refreshConversations();
    _controller._notifyListeners();
  }

  Future<AgentRunResult?> send(String input) async {
    final text = input.trim();
    if (text.isEmpty) throw ArgumentError('请输入要讨论或执行的内容');
    return sendMessage(UserMessage(text: text));
  }

  Future<AgentRunResult?> sendMessage(UserMessage message) async {
    _ensureUsable();
    if (!hasCredential && _controller._modelOverrides.isEmpty) {
      _controller._setError('请先在助手设置中保存 API Key');
      return null;
    }
    if (isRunning) {
      _controller._setError('本轮仍在运行，可以停止后再发送');
      return null;
    }
    if (_controller._session?.needsOutcomeResolution ?? false) {
      _controller._setError('请先核对结果未知的操作，再继续会话');
      _refreshSnapshot();
      return null;
    }
    _controller._sending = true;
    _controller._sendCancelled = false;
    _controller._connectionInterrupted = false;
    _controller._resumeWatchdog?.cancel();
    _controller._notifyListeners();
    _controller._tools.beginTurn();
    _controller._errorMessage = null;
    _controller._lastUserInput = message.text;
    try {
      if (_controller._session == null) await _createSession();
      final session = _requireSession();
      if (session.title == '新会话' && message.text.trim().isNotEmpty) {
        final title = message.text.trim();
        await session.rename(
          title.length > 32 ? '${title.substring(0, 32)}…' : title,
        );
      }
      await session.injectContext(
        source: 'mission_book_context',
        text: _contextText(),
      );
      if (_controller._memory != null) {
        await session.injectContext(
          source: 'mission_book_memory',
          text: '当前有效记忆（用户更正优先；待验证观察不作事实）：${await _controller._memory.core()}',
        );
      }
      if (_controller._sendCancelled) return null;
      final result = await session.sendMessage(message);
      _controller._errorMessage = _controller._connectionInterrupted
          ? '连接中断已恢复，可以继续本轮或发送新消息'
          : result.failure?.message;
      await _refreshConversations();
      _refreshSnapshot();
      return result;
    } catch (error) {
      _controller._setError(userErrorMessage(error, fallback: '会话操作未完成，请重试'));
      return null;
    } finally {
      _controller._sending = false;
      _refreshSnapshot();
    }
  }

  void stop() {
    _controller._sendCancelled = true;
    final session = _controller._session;
    if (session == null || !session.isRunning) return;
    session.cancel();
    for (final pending in _controller._pending.values.toList()) {
      if (!pending.decided) {
        pending.decided = true;
        pending.operation.status = AssistantOperationStatus.cancelled;
        pending.completer.complete(const ToolDecision.deny('用户停止了本轮'));
      }
    }
    _controller._notifyListeners();
  }

  Future<void> _createSession() async {
    final runtime = _controller._runtime ?? (throw StateError('助手尚未初始化'));
    final reference = _controller._reference;
    final title = reference == null
        ? '新会话'
        : '${reference.label} · ${reference.title}';
    final session = await runtime.createSession(
      title: title,
      systemPrompt: _effectiveSystemPrompt,
      modelProfileId: _configuration.defaultModelProfile,
      summaryProfileId: _configuration.summaryModelProfile,
    );
    if (reference != null) {
      await _controller._sessionStore.attachReference(
        session.id,
        missionId: reference.type == AssistantReferenceType.mission
            ? reference.id
            : null,
        goalId: reference.type == AssistantReferenceType.goal
            ? reference.id
            : reference.type == AssistantReferenceType.node
            ? reference.goalId
            : null,
        nodeId: reference.type == AssistantReferenceType.node
            ? reference.id
            : null,
      );
    }
    await _attachSession(session);
    await _refreshConversations();
  }

  Future<void> _openSession(String id) async {
    final runtime = _controller._runtime ?? (throw StateError('助手尚未初始化'));
    final session = await runtime.openSession(id);
    final summary = _controller._conversations
        .where((item) => item.id == id)
        .firstOrNull;
    if (summary?.nodeId != null) {
      final node = await _controller._goals.findNodeById(summary!.nodeId!);
      if (node != null) {
        _controller._reference = AssistantReference(
          type: AssistantReferenceType.node,
          id: node.id,
          title: node.title,
          goalId: node.goalId,
        );
      }
    } else if (summary?.missionId != null) {
      final detail = await _controller._missions.findDetail(
        missionId: summary!.missionId!,
      );
      if (detail != null) {
        _controller._reference = AssistantReference(
          type: AssistantReferenceType.mission,
          id: detail.mission.id,
          title: detail.mission.title,
          goalId: detail.mission.goalId,
          nodeId: detail.mission.goalNodeId,
          path: detail.ownershipInfo?.label,
        );
      }
    } else if (summary?.goalId != null) {
      final goal = await _controller._goals.findById(summary!.goalId!);
      if (goal != null) {
        _controller._reference = AssistantReference(
          type: AssistantReferenceType.goal,
          id: goal.id,
          title: goal.title,
        );
      }
    }
    await _attachSession(session);
  }

  Future<void> _attachSession(AgentSession session) async {
    await _controller._changes?.cancel();
    await _controller._events?.cancel();
    if (session.systemPrompt != _effectiveSystemPrompt) {
      await session.setSystemPrompt(_effectiveSystemPrompt);
    }
    _controller._session = session;
    _controller._preparedCalls.clear();
    _controller._pending.clear();
    _refreshSnapshot();
    _controller._changes = session.changes.listen((_) => _refreshSnapshot());
    _controller._events = session.events.listen((event) {
      if (event is ToolExecutionStarted) {
        _controller._operationFor(event.call).status =
            AssistantOperationStatus.running;
        _controller._refreshOperations();
      }
    });
  }

  Future<void> _closeSession() async {
    await _controller._changes?.cancel();
    await _controller._events?.cancel();
    _controller._changes = null;
    _controller._events = null;
    for (final pending in _controller._pending.values) {
      if (!pending.decided) {
        pending.decided = true;
        pending.completer.complete(const ToolDecision.deny('会话已切换'));
      }
    }
    _controller._pending.clear();
    _controller._preparedCalls.clear();
    final session = _controller._session;
    _controller._session = null;
    _controller._transcript = const [];
    _controller._operations.clear();
    _controller._activity = const SessionActivity(
      isRunning: false,
      text: '',
      thinking: '',
      attempt: 0,
    );
    if (session != null) await session.close();
  }

  void _refreshSnapshot() {
    final session = _controller._session;
    if (session == null || _controller._closed) return;
    _controller._transcript = session.transcript;
    _controller._activity = session.activity;
    _controller._refreshOperations();
    _controller._notifyListeners();
  }

  Future<void> _refreshConversations() async {
    _controller._conversations = await _controller._sessionStore
        .listConversations();
  }

  AgentSession _requireSession() =>
      _controller._session ?? (throw StateError('请先创建或选择一个会话'));

  void _ensureUsable() {
    if (_controller._closed) throw StateError('助手已关闭');
    if (_controller._configuring) throw StateError('正在保存助手设置，请稍候');
    if (!_controller._initialized && _controller._runtime == null) {
      throw StateError('助手正在初始化，请稍候');
    }
  }

  String _contextText() {
    final now = tz.TZDateTime.from(
      _controller._clock(),
      tz.getLocation(defaultScheduleTimeZone),
    );
    final reference = _controller._reference;
    return [
      '宿主当前时间：${now.toIso8601String()}；默认排期时区：$defaultScheduleTimeZone。',
      if (reference != null)
        '用户显式引用${reference.label}：编号 ${reference.id}，名称 ${reference.title}，所属目标 ${reference.goalId ?? '无额外引用'}，节点 ${reference.nodeId ?? (reference.type == AssistantReferenceType.node ? reference.id : '无额外引用')}，页面路径 ${reference.path ?? reference.label}。需要最新内容时用对应工具读取。',
      '只把这条上下文当作入口信息，不把它当作已完成操作或全部业务事实。',
    ].join('\n');
  }

  String _today() {
    final now = tz.TZDateTime.from(
      _controller._clock(),
      tz.getLocation(defaultScheduleTimeZone),
    );
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
