part of 'assistant_controller.dart';

/// 助手控制器的独立职责；状态和生命周期由主控制器持有。
class _AssistantSessions {
  _AssistantSessions(this._controller);
  final AssistantController _controller;
  Timer? _snapshotNotify;
  Future<void>? _navigation;

  Future<void> _navigate(Future<void> Function() action) async {
    while (_navigation != null) {
      await _navigation;
    }
    _ensureUsable();
    _controller._changingConversation = true;
    final done = Completer<void>();
    _navigation = done.future;
    _controller._notifyListeners();
    try {
      await action();
    } finally {
      _controller._changingConversation = false;
      _navigation = null;
      done.complete();
      _controller._notifyListeners();
    }
  }

  bool get isRunning => _controller.isRunning;
  bool get hasCredential => _controller.hasCredential;
  String? get currentSessionId => _controller.currentSessionId;
  String get _effectiveSystemPrompt => _controller._effectiveSystemPrompt;

  String? get _referenceGoalId {
    final reference = _controller._reference;
    if (reference == null) return null;
    return reference.type == AssistantReferenceType.goal
        ? reference.id
        : reference.goalId;
  }

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
    await _navigate(_openGlobalConversation);
  }

  Future<void> _openGlobalConversation() async {
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
      _showEmptyConversation();
    } else {
      await _openSession(global.id);
    }
  }

  Future<void> _selectReference(AssistantReference reference) =>
      _navigate(() => _selectReferenceNow(reference));

  Future<void> _selectReferenceNow(AssistantReference reference) async {
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
    _controller._unavailableReference = null;
    if (matching.isNotEmpty) {
      await _openSession(matching.first.id);
    } else {
      _showEmptyConversation();
    }
    _controller._notifyListeners();
  }

  Future<void> startNewSession({bool clearReference = true}) =>
      _navigate(() async {
        if (isRunning) throw StateError('请先结束本轮，再新建会话');
        await _closeSession();
        if (clearReference) _controller._reference = null;
        _showEmptyConversation();
      });

  /// 空白会话只是界面草稿；首次有效消息发送时才创建持久会话。
  void _showEmptyConversation() {
    _controller._unavailableReference = null;
    _controller._lastUserInput = null;
    _controller._errorMessage = null;
    _controller._localSchedule = null;
    _controller._localScheduleDate = null;
    _controller._notifyListeners();
  }

  Future<void> openConversation(String id) =>
      _navigate(() => _openConversationNow(id));

  Future<void> _openConversationNow(String id) async {
    if (isRunning) throw StateError('请先等待本轮结束或停止本轮');
    if (_controller._session?.id == id) return;
    await _closeSession();
    _controller._reference = null;
    await _openSession(id);
  }

  Future<void> deleteConversation(String id) =>
      _navigate(() => _deleteConversation(id));

  Future<void> _deleteConversation(String id) async {
    if (isRunning) throw StateError('请先结束当前运行，再删除会话');
    if (_controller._session?.id == id) {
      await _closeSession();
      _controller._reference = null;
    }
    await _controller._sessionStore.delete(id);
    _controller._drafts.remove(id);
    _controller._unsentDrafts.remove(id);
    _controller._attachmentDrafts.remove(id);
    await _refreshConversations();
    if (_controller._session == null && _controller._conversations.isNotEmpty) {
      await _openSession(_controller._conversations.first.id);
    }
    _controller._notifyListeners();
  }

  Future<void> renameCurrentSession(String title) =>
      _navigate(() => _renameCurrentSession(title));

  Future<void> _renameCurrentSession(String title) async {
    final session = _requireSession();
    if (isRunning) throw StateError('本轮结束后才能修改会话名称');
    await session.rename(title);
    await _refreshConversations();
    _refreshSnapshot();
  }

  Future<void> renameConversation(String id, String title) =>
      _navigate(() => _renameConversation(id, title));

  Future<void> _renameConversation(String id, String title) async {
    if (isRunning) throw StateError('本轮结束后才能修改会话名称');
    if (id == currentSessionId) {
      await _renameCurrentSession(title);
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
    if (message.text.trim().isEmpty &&
        !message.content.any((block) => block is! TextBlock)) {
      throw ArgumentError('请输入消息或添加附件后再发送');
    }
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
    final originDraftKey = _controller.draftKey;
    _controller._sending = true;
    _controller._sendCancelled = false;
    _controller._connectionInterrupted = false;
    _controller._resumeWatchdog?.cancel();
    _controller._notifyListeners();
    _controller._errorMessage = null;
    _controller._lastUserInput = message.text;
    String? createdSessionId;
    try {
      final stale = _controller._session;
      if (stale != null && stale.needsReopen) {
        final id = stale.id;
        await _closeSession();
        await _openSession(id);
        if (_requireSession().needsOutcomeResolution) {
          _controller._setError('会话已恢复，请先核对结果未知的操作，再发送；输入已保留');
          return null;
        }
      }
      if (_controller._session == null) {
        await _createSession();
        createdSessionId = _controller._session!.id;
      }
      final session = _requireSession();
      if (session.title == '新会话' && message.text.trim().isNotEmpty) {
        final title = message.text.trim();
        await session.rename(
          title.length > 32 ? '${title.substring(0, 32)}…' : title,
        );
      }
      await session.replaceContext(
        source: 'mission_book_context',
        text: _contextText(),
      );
      final assembler = _controller._memoryAssembler;
      if (assembler != null) {
        var memoryText = '';
        List<Map<String, Object?>> injected = const [];
        try {
          final loaded = await assembler.assemble(
            goalId: _referenceGoalId,
            topic: message.text,
          );
          injected = loaded.injected;
          if (!loaded.isEmpty) {
            memoryText =
                '当前有效记忆（stable=核心身份与稳定偏好；goal=当前引用目标及任务 brief；'
                'topic=本轮相关事实；unverified=观察或未确认，均不作事实；'
                '用户更正优先）：${loaded.text}';
          }
        } catch (_) {
          // 记忆只增强上下文；读取失败不阻断本轮，也不保留可能过期的旧块。
          debugPrint('记忆上下文读取失败，已跳过本轮记忆');
        }
        _controller._lastMemoryInjection = const [];
        await session.replaceContext(
          source: 'mission_book_memory',
          text: memoryText.isEmpty ? null : memoryText,
        );
        if (_controller._sendCancelled) return null;
        _controller._lastMemoryInjection = injected;
        _controller._memoryUsage?.record([
          for (final item in injected) item['id'] as String,
        ], injected: true);
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
      final session = _controller._session;
      if (createdSessionId != null &&
          session?.id == createdSessionId &&
          !session!.transcript.any((item) => item is UserMessage)) {
        // 输入预检或上下文准备失败时清理本次新建的空壳；模型失败但用户消息已保存则保留历史。
        final error = _controller._errorMessage;
        final shellText = _controller.draftFor(createdSessionId);
        final shellFiles = _controller.attachmentsFor(createdSessionId);
        try {
          await _closeSession();
          await _controller._sessionStore.delete(createdSessionId);
          await _refreshConversations();
          _controller._drafts.remove(createdSessionId);
          _controller._attachmentDrafts.remove(createdSessionId);
          if (shellText.isNotEmpty || shellFiles.isNotEmpty) {
            if (_controller.draftFor(originDraftKey).isEmpty &&
                _controller.attachmentsFor(originDraftKey).isEmpty) {
              _controller.saveDraft(originDraftKey, shellText);
              _controller.saveAttachments(originDraftKey, shellFiles);
            } else {
              _controller.retainUnsentDraft(
                originDraftKey,
                AssistantUnsentDraft(shellText, shellFiles),
              );
            }
          }
        } catch (cleanupError) {
          debugPrint('未发送空会话清理失败：$cleanupError');
        }
        _controller._errorMessage = error;
        _controller._notifyListeners();
      }
      _refreshSnapshot();
    }
  }

  void stop() {
    _controller._sendCancelled = true;
    _controller._gateway.interruptObsoleteRequests();
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
    try {
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
    } catch (_) {
      if (identical(_controller._session, session)) {
        await _closeSession();
      } else {
        await session.close();
      }
      if (!session.transcript.any((message) => message is UserMessage)) {
        await _controller._sessionStore.delete(session.id);
      }
      rethrow;
    }
  }

  Future<void> _openSession(String id) async {
    final runtime = _controller._runtime ?? (throw StateError('助手尚未初始化'));
    final session = await runtime.openSession(id);
    try {
      _controller._reference = null;
      _controller._unavailableReference = null;
      _controller._errorMessage = null;
      _controller._lastUserInput = null;
      _controller._localSchedule = null;
      _controller._localScheduleDate = null;
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
      if (_controller._reference == null &&
          summary != null &&
          (summary.missionId != null ||
              summary.goalId != null ||
              summary.nodeId != null)) {
        _controller._unavailableReference =
            '原关联对象已不存在或无法读取，聊天记录仍保留；后续操作需要重新指定对象。';
      }
      await _attachSession(session);
    } catch (_) {
      if (identical(_controller._session, session)) {
        await _closeSession();
      } else {
        await session.close();
      }
      rethrow;
    }
  }

  Future<void> _attachSession(AgentSession session) async {
    await _controller._changes?.cancel();
    await _controller._events?.cancel();
    // 查询结果仅对当前轮有效；注册持久刷新策略，覆盖发送、继续和手动压缩。
    await session.invalidateToolResults(toolNames: {'getMemory'});
    if (session.systemPrompt != _effectiveSystemPrompt) {
      await session.setSystemPrompt(_effectiveSystemPrompt);
    }
    _controller._session = session;
    await _controller._config._applyReasoningEffort();
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
    _snapshotNotify?.cancel();
    _snapshotNotify = null;
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
    _controller._publishActivity(AssistantController._idleActivity);
    if (session != null) await session.close();
  }

  void _refreshSnapshot() {
    final session = _controller._session;
    if (_controller._closed) return;
    if (session != null) {
      final previous = _controller._transcript;
      final transcriptChanged =
          session.transcriptLength != previous.length ||
          session.lastTranscriptMessageId != previous.lastOrNull?.id;
      // 记录只追加；纯文本增量用 O(1) 元数据识别，避免每个 token 复制整条历史。
      if (transcriptChanged) {
        _controller._transcript = session.transcript;
        _controller._refreshOperations();
      }
    }
    // 模型逐 token 推送：只更新正文/思考快照，让生成中的区域单独刷新；
    // 整页仍按请求边界（开始、结束、工具、会话）重建，避免输入区和会话列表逐帧重绘。
    if (session != null && session.modelRequestRunning) {
      _snapshotNotify ??= Timer(const Duration(milliseconds: 66), () {
        _snapshotNotify = null;
        if (_controller._closed) return;
        _controller._publishActivity(session.activity);
      });
      return;
    }
    _snapshotNotify?.cancel();
    _snapshotNotify = null;
    _controller._publishActivity(
      session?.activity ?? AssistantController._idleActivity,
    );
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
    if (_controller._changingConversation) throw StateError('正在切换会话，请稍候');
    if (_controller._configuring) throw StateError('正在保存助手设置，请稍候');
    if (!_controller._initialized && _controller._runtime == null) {
      throw StateError(_controller._errorMessage ?? '助手正在初始化，请稍候');
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
      if (_controller._unavailableReference != null)
        _controller._unavailableReference!,
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
