import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'assistant_settings.dart';
import 'assistant_conversation_store.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../goals/goal_service.dart';
import '../missions/mission_service.dart';
import 'assistant_tools.dart';
import 'assistant_reader.dart';

enum AssistantReferenceType { mission, goal, node }

class AssistantReference {
  const AssistantReference({
    required this.type,
    required this.id,
    required this.title,
    this.goalId,
    this.nodeId,
    this.path,
  });

  final String? goalId;
  final String? nodeId;
  final String? path;
  String get label => switch (type) {
    AssistantReferenceType.mission => '任务',
    AssistantReferenceType.goal => '目标',
    AssistantReferenceType.node => '节点',
  };

  final AssistantReferenceType type;
  final String id;
  final String title;
}

enum AssistantOperationStatus {
  waitingConfirmation,
  running,
  succeeded,
  failed,
  cancelled,
  unknown,
}

class AssistantOperation {
  AssistantOperation({
    required this.callId,
    required this.toolName,
    required this.input,
  });

  final String callId;
  final String toolName;
  Map<String, Object?> input;
  AssistantOperationStatus status = AssistantOperationStatus.running;
  String? output;
  String? error;
  MissionDetail? missionBefore;
  String? targetTitle;

  bool get isWrite => AssistantTools.writeToolNames.contains(toolName);
}

class _PendingAuthorization {
  _PendingAuthorization(this.prepared, this.operation);

  final PreparedToolCall prepared;
  final AssistantOperation operation;
  final completer = Completer<ToolDecision>();
  bool decided = false;
}

const _systemPrompt = '''
你是 MissionBook 内置助手。使用简体中文，帮助用户理解并完成真实目标与任务工作。
1. 当前日期、时区和显式引用以宿主注入的 ContextMessage 为准；需要数据时先调用工具，不猜测任务或目标编号。
2. 多个候选或字段不足时，列出简短候选让用户选择，不替用户猜测。不要把标题当成稳定编号。
3. 写入通过工具提出，界面会显示可编辑操作卡片。工具结果返回前不能说已经保存、改期、开始或结束。
4. END 的 COMPLETED / NOT_COMPLETED 只能来自用户明确陈述；不能自行推断完成、掌握或材料验收通过。
5. 阶段、Focus 和事实以工具结果为准；区分用户陈述、数据库事实、规则计算与你的建议。
6. 回答优先给可执行方案和必要依据，保持简洁。发生冲突或结果未知时，引导用户核对，不盲目重试。
''';

/// App 级助手控制器：页面只读取快照，运行和会话生命周期长于页面。
class AssistantController extends ChangeNotifier {
  AssistantController({
    required AssistantReader reader,
    required AssistantConversationStore sessionStore,
    required AssistantSettingsStore settingsStore,
    required MissionService missions,
    required GoalService goals,
    AgentConfiguration? configuration,
    Map<String, AgentModel> modelOverrides = const {},
    DateTime Function()? clock,
  }) : _sessionStore = sessionStore,
       _settingsStore = settingsStore,
       _missions = missions,
       _goals = goals,
       _baseConfiguration = configuration,
       _modelOverrides = modelOverrides,
       _clock = clock ?? DateTime.now {
    _tools = AssistantTools(
      reader: reader,
      missions: missions,
      goals: goals,
      resolveCall: _resolveCall,
      clock: _clock,
    );
  }

  final AssistantConversationStore _sessionStore;
  final AssistantSettingsStore _settingsStore;
  final MissionService _missions;
  final GoalService _goals;
  final AgentConfiguration? _baseConfiguration;
  final Map<String, AgentModel> _modelOverrides;
  final DateTime Function() _clock;
  late final AssistantTools _tools;

  AgentRuntime? _runtime;
  AgentSession? _session;
  StreamSubscription<void>? _changes;
  StreamSubscription<AgentEvent>? _events;
  final _preparedCalls = <String, PreparedToolCall>{};
  final _pending = <String, _PendingAuthorization>{};
  final _operations = <String, AssistantOperation>{};

  AssistantSettings _settings = const AssistantSettings(
    hasCredential: false,
    modelProfileId: 'deepseek-chat',
    autoApproveWrites: false,
  );
  List<AssistantConversationSummary> _conversations = const [];
  List<AgentMessage> _transcript = const [];
  SessionActivity _activity = const SessionActivity(
    isRunning: false,
    text: '',
    thinking: '',
    attempt: 0,
  );
  List<ScheduledMission>? _localSchedule;
  String? _localScheduleDate;
  AssistantReference? _reference;
  String? _errorMessage;
  String? _lastUserInput;
  final _drafts = <String?, String>{};
  String get draft => draftFor(currentSessionId);
  String draftFor(String? id) => _drafts[id] ?? '';
  void saveDraft(String? id, String text) {
    _drafts[id] = text;
  }

  set draft(String value) {
    _drafts[currentSessionId] = value;
  }

  Future<void>? _initializeFuture;
  bool _initialized = false;
  bool _initializing = false;
  bool _localLoading = false;
  bool _closed = false;
  bool _sending = false;
  bool _sendCancelled = false;
  bool _configuring = false;
  Completer<void>? _configurationDone;
  Future<void>? _closing;

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get isRunning => _sending || (_session?.isRunning ?? false);
  bool get configuring => _configuring;
  bool get isBusy => isRunning || _configuring;
  bool get hasCredential => profileHasCredential(modelProfileId);
  bool profileHasCredential(String id) => id == 'custom'
      ? _settings.hasCustomCredential
      : (_settings.hasDeepSeekCredential ?? _settings.hasCredential);
  ModelProfile? get customProfile => _settings.customProfile;
  bool get autoApproveWrites => _settings.autoApproveWrites;
  String get modelProfileId =>
      _session?.modelProfileId ?? _settings.modelProfileId;
  String get sessionTitle => _session?.title ?? '新会话';
  String? get currentSessionId => _session?.id;
  AssistantReference? get reference => _reference;
  String? get errorMessage => _errorMessage;
  String? get lastUserInput => _lastUserInput;
  bool get localLoading => _localLoading;
  String? get localScheduleDate => _localScheduleDate;
  List<ScheduledMission>? get localSchedule => _localSchedule;
  List<AssistantConversationSummary> get conversations =>
      List.unmodifiable(_conversations);
  List<AgentMessage> get transcript => List.unmodifiable(_transcript);
  SessionActivity get activity => _activity;
  List<AssistantOperation> get operations =>
      List.unmodifiable(_operations.values);
  bool get needsOutcomeResolution => _session?.needsOutcomeResolution ?? false;

  AgentConfiguration get _configuration {
    final base = _baseConfiguration ?? AgentConfiguration.deepSeek();
    final selected = _settings.modelProfileId;
    final profiles = [
      ...base.profiles.where((profile) => profile.id != 'custom'),
      if (_settings.customProfile != null) _settings.customProfile!,
    ];
    final profileId = profiles.any((profile) => profile.id == selected)
        ? selected
        : base.defaultModelProfile;
    return AgentConfiguration(
      profiles: profiles,
      defaultModelProfile: profileId,
      summaryModelProfile: profileId,
      maxSteps: base.maxSteps,
      maxRunDuration: base.maxRunDuration,
      context: base.context,
    );
  }

  Future<void> initialize() => _initializeFuture ??= _initialize();

  Future<void> _initialize() async {
    if (_initialized || _initializing || _closed) return;
    _initializing = true;
    notifyListeners();
    try {
      _settings = await _settingsStore.load();
      _runtime = AgentRuntime(
        configuration: _configuration,
        store: _sessionStore,
        credentials: _settingsStore.resolveCredential,
        tools: _tools.tools,
        authorize: _authorize,
        modelOverrides: _modelOverrides,
      );
      await _refreshConversations();
      if (_conversations.isNotEmpty) {
        await _openSession(_conversations.first.id);
      }
      _initialized = true;
      _errorMessage = null;
    } catch (error) {
      _initializeFuture = null;
      _errorMessage = '助手初始化失败：$error';
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> openMissionReference(String missionId) async {
    final detail = await _missions.findDetailSnapshot(missionId: missionId);
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
    final goal = await _goals.findById(goalId);
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
    final node = await _goals.findNodeById(nodeId);
    if (node == null) throw StateError('节点不存在');
    final goal = await _goals.findById(node.goalId);
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
    await initialize();
    _ensureUsable();
    if (_reference == null) return;
    if (isRunning) throw StateError('请先结束当前对象的这一轮，再切换全局会话');
    final global = _conversations
        .where(
          (item) =>
              item.missionId == null &&
              item.goalId == null &&
              item.nodeId == null,
        )
        .firstOrNull;
    await _closeSession();
    _reference = null;
    if (global == null) {
      await _createSession();
    } else {
      await _openSession(global.id);
    }
  }

  Future<void> _selectReference(AssistantReference reference) async {
    _ensureUsable();
    if (_reference?.type == reference.type && _reference?.id == reference.id) {
      _reference = reference;
      notifyListeners();
      return;
    }
    if (isRunning) throw StateError('本轮结束后才能切换任务或目标会话');
    final matching = _conversations.where(
      (item) => switch (reference.type) {
        AssistantReferenceType.mission => item.missionId == reference.id,
        AssistantReferenceType.goal =>
          item.goalId == reference.id && item.nodeId == null,
        AssistantReferenceType.node => item.nodeId == reference.id,
      },
    );
    await _closeSession();
    _reference = reference;
    if (matching.isNotEmpty) {
      await _openSession(matching.first.id);
    } else {
      await _createSession();
    }
    notifyListeners();
  }

  Future<void> startNewSession({bool clearReference = true}) async {
    _ensureUsable();
    if (isRunning) throw StateError('请先等待本轮结束或停止本轮');
    await _closeSession();
    if (clearReference) _reference = null;
    await _createSession();
  }

  Future<void> openConversation(String id) async {
    _ensureUsable();
    if (isRunning) throw StateError('请先等待本轮结束或停止本轮');
    if (_session?.id == id) return;
    await _closeSession();
    _reference = null;
    await _openSession(id);
  }

  Future<void> deleteConversation(String id) async {
    _ensureUsable();
    if (isRunning) throw StateError('请先结束当前运行，再删除会话');
    if (_session?.id == id) {
      await _closeSession();
      _reference = null;
    }
    await _sessionStore.delete(id);
    await _refreshConversations();
    if (_session == null && _conversations.isNotEmpty) {
      await _openSession(_conversations.first.id);
    }
    notifyListeners();
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
    final session = await _runtime!.openSession(id);
    try {
      await session.rename(title);
    } finally {
      await session.close();
    }
    await _refreshConversations();
    notifyListeners();
  }

  Future<AgentRunResult?> send(String input) async {
    final text = input.trim();
    if (text.isEmpty) throw ArgumentError('请输入要讨论或执行的内容');
    return sendMessage(UserMessage(text: text));
  }

  Future<AgentRunResult?> sendMessage(UserMessage message) async {
    _ensureUsable();
    if (!hasCredential && _modelOverrides.isEmpty) {
      _setError('请先在助手设置中保存 API Key');
      return null;
    }
    if (isRunning) {
      _setError('本轮仍在运行，可以停止后再发送');
      return null;
    }
    if (_session?.needsOutcomeResolution ?? false) {
      _setError('请先核对结果未知的操作，再继续会话');
      _refreshSnapshot();
      return null;
    }
    _sending = true;
    _sendCancelled = false;
    notifyListeners();
    _tools.beginTurn();
    _errorMessage = null;
    _lastUserInput = message.text;
    try {
      if (_session == null) await _createSession();
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
      if (_sendCancelled) return null;
      final result = await session.sendMessage(message);
      _errorMessage = result.failure?.message;
      await _refreshConversations();
      _refreshSnapshot();
      return result;
    } catch (error) {
      _setError('$error');
      return null;
    } finally {
      _sending = false;
      _refreshSnapshot();
    }
  }

  void stop() {
    _sendCancelled = true;
    final session = _session;
    if (session == null || !session.isRunning) return;
    session.cancel();
    for (final pending in _pending.values.toList()) {
      if (!pending.decided) {
        pending.decided = true;
        pending.operation.status = AssistantOperationStatus.cancelled;
        pending.completer.complete(const ToolDecision.deny('用户停止了本轮'));
      }
    }
    notifyListeners();
  }

  Future<void> resolveUnknownOutcome(String callId) async {
    final session = _requireSession();
    final unknown = session.unknownOutcomes[callId];
    final operation = _operations[callId];
    if (unknown == null || operation == null) return;
    try {
      final output = await _tools.recoverOutcome(
        toolName: operation.toolName,
        idempotencyKey: '${session.id}:$callId',
        input: operation.input,
      );
      if (output == null) {
        _setError('暂时没有查到可确认的结果，请打开原任务或目标人工核对');
        return;
      }
      await session.resolveToolOutcome(
        callId,
        output,
        source: 'mission_book_recovery',
      );
      _errorMessage = null;
      _refreshSnapshot();
    } catch (error) {
      _setError('结果核对失败：$error');
    }
  }

  String? updateProposal(String callId, Map<String, Object?> input) {
    final pending = _pending[callId];
    if (pending == null || pending.decided) return '这份提案已失效，请重新检查';
    for (final key in ['missionId', 'goalId', 'nodeId']) {
      if (input[key] != pending.prepared.input[key]) {
        return '不能在编辑提案时更换操作对象，请取消后重新提出';
      }
    }
    final validation = _tools.validate(pending.operation.toolName, input);
    if (validation != null) return validation;
    pending.prepared.input = Map<String, Object?>.unmodifiable(input);
    pending.operation.input = pending.prepared.input;
    notifyListeners();
    return null;
  }

  String? confirmProposal(String callId) {
    final pending = _pending[callId];
    if (pending == null || pending.decided) return '这份提案已失效，请重新检查';
    final validation = _tools.validate(
      pending.operation.toolName,
      pending.prepared.input,
    );
    if (validation != null) return validation;
    pending.decided = true;
    pending.operation.status = AssistantOperationStatus.running;
    pending.completer.complete(
      ToolDecision.allowWithInput(pending.prepared.input),
    );
    notifyListeners();
    return null;
  }

  void cancelProposal(String callId) {
    final pending = _pending[callId];
    if (pending == null || pending.decided) return;
    pending.decided = true;
    pending.operation.status = AssistantOperationStatus.cancelled;
    pending.completer.complete(const ToolDecision.deny('用户取消了这份操作提案'));
    notifyListeners();
  }

  Future<void> saveCredential(String value, {String? profileId}) =>
      _updateConfiguration(() async {
        await _settingsStore.saveCredential(
          (profileId ?? modelProfileId) == 'custom'
              ? 'MISSIONBOOK_CUSTOM_API_KEY'
              : 'DEEPSEEK_API_KEY',
          value,
        );
        await _reloadSettings();
      });

  Future<void> saveCustomProfile(ModelProfile profile) =>
      _updateConfiguration(() async {
        await _settingsStore.saveCustomProfile(profile);
        final sessionId = currentSessionId;
        await _closeSession();
        await _runtime?.close();
        _settings = await _settingsStore.load();
        _runtime = AgentRuntime(
          configuration: _configuration,
          store: _sessionStore,
          credentials: _settingsStore.resolveCredential,
          tools: _tools.tools,
          authorize: _authorize,
          modelOverrides: _modelOverrides,
        );
        if (sessionId != null) await _openSession(sessionId);
      });

  Future<void> selectModelProfile(String profileId) => _updateConfiguration(
    () async {
      if (!_configuration.profiles.any((profile) => profile.id == profileId)) {
        throw ArgumentError('请先保存所选模型的配置');
      }
      await _settingsStore.saveModelProfile(profileId);
      _settings = await _settingsStore.load();
      if (_session != null &&
          (_session!.modelProfileId != profileId ||
              _session!.summaryProfileId != profileId)) {
        await _session!.selectModels(
          conversation: _settings.modelProfileId,
          summary: _settings.modelProfileId,
        );
      }
    },
  );

  Future<void> setAutoApproveWrites(bool value) =>
      _updateConfiguration(() async {
        await _settingsStore.saveAutoApproveWrites(value);
        await _reloadSettings();
      });

  Future<void> _updateConfiguration(Future<void> Function() update) async {
    _ensureUsable();
    if (isRunning) throw StateError('请先结束本轮，再修改助手设置');
    _configuring = true;
    final done = Completer<void>();
    _configurationDone = done;
    notifyListeners();
    try {
      await update();
    } finally {
      _configuring = false;
      _configurationDone = null;
      done.complete();
      if (!_closed) notifyListeners();
    }
  }

  Future<String> testConnection() async {
    _ensureUsable();
    final configuration = _configuration;
    final registry = ModelRegistry(
      configuration: configuration,
      credentials: _settingsStore.resolveCredential,
      overrides: _modelOverrides,
    );
    final cancellation = CancellationToken();
    final timer = Timer(const Duration(seconds: 30), cancellation.cancel);
    try {
      final response = await registry
          .model(modelProfileId)
          .complete(
            ModelRequest(
              systemPrompt: '这是 MissionBook 的连接检查。',
              messages: [UserMessage(text: '只回复“连接正常”。')],
              tools: const [],
              maxOutputTokens: 64,
            ),
            cancellation,
          );
      return response.message.text.trim().isEmpty
          ? '连接成功，模型已返回响应'
          : response.message.text.trim();
    } finally {
      timer.cancel();
      registry.close();
    }
  }

  Future<void> loadLocalSchedule({String? date}) async {
    if (_localLoading) return;
    _localLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final selected = date ?? _today();
      final result = await _missions.findScheduledSnapshotOn(
        scheduledDate: selected,
      );
      _localSchedule = result;
      _localScheduleDate = selected;
    } catch (error) {
      _setError('读取本地日程失败：$error');
    } finally {
      _localLoading = false;
      notifyListeners();
    }
  }

  void clearLocalSchedule() {
    if (_localSchedule == null) return;
    _localSchedule = null;
    _localScheduleDate = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<ToolDecision> _authorize(
    ToolDefinition tool,
    ToolCallBlock call,
    CancellationToken cancellation,
  ) async {
    if (!AssistantTools.writeToolNames.contains(tool.name)) {
      return const ToolDecision.allow();
    }
    final PreparedToolCall prepared;
    try {
      prepared = await _tools.prepare(tool.name, call.input);
    } on ToolRejected catch (error) {
      return ToolDecision.deny(error.message);
    }
    _preparedCalls[call.id] = prepared;
    if (_settings.autoApproveWrites) {
      return ToolDecision.allowWithInput(prepared.input);
    }
    final operation = _operationFor(call);
    operation
      ..input = prepared.input
      ..targetTitle = prepared.snapshot['targetTitle'] as String?
      ..missionBefore = prepared.snapshot['detail'] as MissionDetail?
      ..status = AssistantOperationStatus.waitingConfirmation;
    final pending = _PendingAuthorization(prepared, operation);
    _pending[call.id] = pending;
    _refreshOperations();
    try {
      return await cancellation.wait(pending.completer.future);
    } finally {
      _pending.remove(call.id);
      if (!pending.decided) {
        pending.operation.status = AssistantOperationStatus.cancelled;
      }
      _refreshOperations();
    }
  }

  PreparedToolCall _resolveCall(String callId) {
    final prepared = _preparedCalls[callId];
    if (prepared == null) throw StateError('找不到这次操作的固定提案');
    return prepared;
  }

  AssistantOperation _operationFor(ToolCallBlock call) =>
      _operations[call.id] ??= AssistantOperation(
        callId: call.id,
        toolName: call.name,
        input: call.input,
      );

  Future<void> _createSession() async {
    final runtime = _runtime ?? (throw StateError('助手尚未初始化'));
    final reference = _reference;
    final title = reference == null
        ? '新会话'
        : '${reference.label} · ${reference.title}';
    final session = await runtime.createSession(
      title: title,
      systemPrompt: _systemPrompt,
      modelProfileId: _configuration.defaultModelProfile,
      summaryProfileId: _configuration.summaryModelProfile,
    );
    if (reference != null) {
      await _sessionStore.attachReference(
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
    final runtime = _runtime ?? (throw StateError('助手尚未初始化'));
    final session = await runtime.openSession(id);
    final summary = _conversations.where((item) => item.id == id).firstOrNull;
    if (summary?.nodeId != null) {
      final node = await _goals.findNodeById(summary!.nodeId!);
      if (node != null) {
        _reference = AssistantReference(
          type: AssistantReferenceType.node,
          id: node.id,
          title: node.title,
          goalId: node.goalId,
        );
      }
    } else if (summary?.missionId != null) {
      final detail = await _missions.findDetailSnapshot(
        missionId: summary!.missionId!,
      );
      if (detail != null) {
        _reference = AssistantReference(
          type: AssistantReferenceType.mission,
          id: detail.mission.id,
          title: detail.mission.title,
          goalId: detail.mission.goalId,
          nodeId: detail.mission.goalNodeId,
          path: detail.ownershipInfo?.label,
        );
      }
    } else if (summary?.goalId != null) {
      final goal = await _goals.findById(summary!.goalId!);
      if (goal != null) {
        _reference = AssistantReference(
          type: AssistantReferenceType.goal,
          id: goal.id,
          title: goal.title,
        );
      }
    }
    await _attachSession(session);
  }

  Future<void> _attachSession(AgentSession session) async {
    await _changes?.cancel();
    await _events?.cancel();
    _session = session;
    _preparedCalls.clear();
    _pending.clear();
    _refreshSnapshot();
    _changes = session.changes.listen((_) => _refreshSnapshot());
    _events = session.events.listen((event) {
      if (event is ToolExecutionStarted) {
        _operationFor(event.call).status = AssistantOperationStatus.running;
        _refreshOperations();
      }
    });
  }

  Future<void> _closeSession() async {
    await _changes?.cancel();
    await _events?.cancel();
    _changes = null;
    _events = null;
    for (final pending in _pending.values) {
      if (!pending.decided) {
        pending.decided = true;
        pending.completer.complete(const ToolDecision.deny('会话已切换'));
      }
    }
    _pending.clear();
    _preparedCalls.clear();
    final session = _session;
    _session = null;
    _transcript = const [];
    _operations.clear();
    _activity = const SessionActivity(
      isRunning: false,
      text: '',
      thinking: '',
      attempt: 0,
    );
    if (session != null) await session.close();
  }

  void _refreshSnapshot() {
    final session = _session;
    if (session == null || _closed) return;
    _transcript = session.transcript;
    _activity = session.activity;
    _refreshOperations();
    notifyListeners();
  }

  void _refreshOperations() {
    for (final message in _transcript) {
      if (message is AssistantMessage) {
        for (final call in message.toolCalls) {
          final operation = _operationFor(call);
          if (operation.output == null && !_pending.containsKey(call.id)) {
            operation.input =
                _session?.executedCalls[call.id]?.input ?? call.input;
          }
        }
      } else if (message is ToolResultMessage) {
        final operation = _operations[message.toolCallId];
        if (operation == null) continue;
        final resolved = _session?.resolvedOutcomes[message.toolCallId];
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
    for (final entry in _pending.entries) {
      final operation = _operations[entry.key];
      if (operation != null) {
        operation
          ..input = entry.value.prepared.input
          ..status = AssistantOperationStatus.waitingConfirmation;
      }
    }
    notifyListeners();
  }

  Future<void> _refreshConversations() async {
    _conversations = await _sessionStore.listConversations();
  }

  Future<void> _reloadSettings() async {
    _settings = await _settingsStore.load();
    _errorMessage = null;
    notifyListeners();
  }

  AgentSession _requireSession() =>
      _session ?? (throw StateError('请先创建或选择一个会话'));

  void _ensureUsable() {
    if (_closed) throw StateError('助手已关闭');
    if (_configuring) throw StateError('正在保存助手设置，请稍候');
    if (!_initialized && _runtime == null) throw StateError('助手正在初始化，请稍候');
  }

  String _contextText() {
    final now = tz.TZDateTime.from(_clock(), tz.getLocation('Asia/Shanghai'));
    final reference = _reference;
    return [
      '宿主当前时间：${now.toIso8601String()}；默认排期时区：Asia/Shanghai。',
      if (reference != null)
        '用户显式引用${reference.label}：编号 ${reference.id}，名称 ${reference.title}，所属目标 ${reference.goalId ?? '无额外引用'}，节点 ${reference.nodeId ?? (reference.type == AssistantReferenceType.node ? reference.id : '无额外引用')}，页面路径 ${reference.path ?? reference.label}。需要最新内容时用对应工具读取。',
      '只把这条上下文当作入口信息，不把它当作已完成操作或全部业务事实。',
    ].join('\n');
  }

  String _today() {
    final now = tz.TZDateTime.from(_clock(), tz.getLocation('Asia/Shanghai'));
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    stop();
    await _configurationDone?.future;
    await _closeSession();
    await _runtime?.close();
    _runtime = null;
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
