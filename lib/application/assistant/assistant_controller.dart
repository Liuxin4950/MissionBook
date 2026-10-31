import 'assistant_prompt.dart';
import '../errors/user_error_message.dart';
import '../memory/memory_service.dart';
import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'assistant_settings.dart';
import 'assistant_attachment.dart';
import 'assistant_schedule.dart';
import '../../domain/entities/schedule_proposal.dart';
import 'assistant_conversation_store.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../goals/goal_service.dart';
import '../missions/mission_service.dart';
import 'assistant_tools.dart';
import 'assistant_reader.dart';
import '../records/record_service.dart';
import '../analysis/analysis_service.dart';
import '../web/web_service.dart';
import 'unified_reader.dart';
import 'context_tools.dart';
export 'assistant_settings.dart'
    show
        AssistantPermissionMode,
        AssistantSpeechSettings,
        AssistantPersona,
        AssistantRole,
        AssistantReplyStyle,
        AssistantAvatar;

part 'assistant_sessions.dart';
part 'assistant_configuration.dart';
part 'assistant_operations.dart';
part 'assistant_model_gateway.dart';

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
  List<MissionDetail> historyMissions = const [];
  int historySkippedCount = 0;
  List<ScheduleConflict> planConflicts = const [];
  Map<String, MissionDetail> planOriginals = const {};
  bool planChecking = false;
  bool planPreviewReady = false;
  String? planPreviewError;

  bool get isWrite => AssistantTools.writeToolNames.contains(toolName);
}

class _PendingAuthorization {
  _PendingAuthorization(this.prepared, this.operation);

  final PreparedToolCall prepared;
  final AssistantOperation operation;
  final completer = Completer<ToolDecision>();
  bool decided = false;
}

/// App 级助手控制器：页面只读取快照，运行和会话生命周期长于页面。
class AssistantController extends ChangeNotifier {
  late final _sessions = _AssistantSessions(this);
  late final _config = _AssistantConfiguration(this);
  late final _operationCoordinator = _AssistantOperations(this);
  late final _gateway = _AssistantModelGateway(this);

  void _notifyListeners() {
    _gateway.interruptObsoleteRequests();
    if (!_closed) notifyListeners();
  }

  AssistantController({
    required AssistantReader reader,
    required AssistantConversationStore sessionStore,
    required AssistantSettingsStore settingsStore,
    required MissionService missions,
    required GoalService goals,
    RecordService? records,
    MemoryService? memory,
    AnalysisStore? analysis,
    UnifiedReader? unifiedReader,
    WebService? web,
    AgentConfiguration? configuration,
    Map<String, AgentModel> modelOverrides = const {},
    DateTime Function()? clock,
    this.resumeGrace = const Duration(seconds: 20),
    this.analysisTimeout = const Duration(seconds: 60),
    this.connectionTestTimeout = const Duration(seconds: 30),
  }) : _sessionStore = sessionStore,
       _settingsStore = settingsStore,
       _missions = missions,
       _goals = goals,
       _memory = memory,
       _analysis = analysis,
       _baseConfiguration = configuration,
       _modelOverrides = modelOverrides,
       _clock = clock ?? DateTime.now {
    _tools = AssistantTools(
      reader: reader,
      missions: missions,
      goals: goals,
      resolveCall: _resolveCall,
      memory: memory,
      extraTools:
          records != null &&
              memory != null &&
              analysis != null &&
              unifiedReader != null &&
              web != null
          ? contextTools(
              reader: unifiedReader,
              records: records,
              memory: memory,
              analysis: analysis,
              web: web,
              analyze: analyzeOnDemand,
              snapshot: (id) => _preparedCalls[id]?.snapshot ?? const {},
              userStatement: () => _lastUserInput ?? '',
            )
          : const [],
      clock: _clock,
    );
  }

  final AssistantConversationStore _sessionStore;
  final AssistantSettingsStore _settingsStore;
  final MissionService _missions;
  final GoalService _goals;
  final MemoryService? _memory;
  final AnalysisStore? _analysis;
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
  final _attachmentDrafts = <String?, List<AssistantAttachment>>{};
  List<AssistantAttachment> attachmentsFor(String? id) =>
      List.unmodifiable(_attachmentDrafts[id ?? draftKey] ?? const []);
  void saveAttachments(String? id, List<AssistantAttachment> attachments) {
    if (attachments.isEmpty) {
      _attachmentDrafts.remove(id ?? draftKey);
    } else {
      _attachmentDrafts[id ?? draftKey] = List.of(attachments);
    }
  }

  /// 未发送的全局/对象聊天按草稿身份隔离，不需要先建立数据库会话。
  String get draftKey {
    final ref = _reference;
    return currentSessionId ??
        (ref == null ? 'draft:global' : 'draft:${ref.type.name}:${ref.id}');
  }

  String get draft => draftFor(draftKey);
  String draftFor(String? id) => _drafts[id ?? draftKey] ?? '';
  void saveDraft(String? id, String text) {
    _drafts[id ?? draftKey] = text;
  }

  set draft(String value) {
    _drafts[draftKey] = value;
  }

  Future<void>? _initializeFuture;
  bool _initialized = false;
  bool _initializing = false;
  bool _localLoading = false;
  bool _closed = false;
  bool _sending = false;
  bool _changingConversation = false;
  bool _sendCancelled = false;
  final Duration resumeGrace;
  final Duration analysisTimeout; // 单次分析包含图片读取的总等待上限。
  final Duration connectionTestTimeout; // 设置页连接检查的总等待上限。
  bool _backgrounded = false;
  bool _connectionInterrupted = false;
  Timer? _resumeWatchdog;

  String get _progressFingerprint =>
      '${_transcript.length}:${_transcript.lastOrNull?.id}:${_activity.attempt}:${_activity.toolName}:${_activity.text}:${_activity.thinking}';

  /// 切后台不取消请求；回前台后若模型连接持续无进展，结束旧等待并开放继续入口。
  void setForeground(bool foreground) {
    if (_closed) return;
    _resumeWatchdog?.cancel();
    if (!foreground) {
      _backgrounded = true;
      return;
    }
    final returning = _backgrounded;
    _backgrounded = false;
    _refreshSnapshot();
    if (!returning || !isRunning) return;
    final progress = _progressFingerprint;
    _resumeWatchdog = Timer(resumeGrace, () {
      if (_closed ||
          _backgrounded ||
          !isRunning ||
          _pending.isNotEmpty ||
          _activity.toolName != null ||
          _progressFingerprint != progress) {
        return;
      }
      _connectionInterrupted = true;
      stop();
      _setError('连接已中断，正在结束旧请求；随后可继续本轮');
    });
  }

  bool get canContinueInterrupted =>
      !isBusy &&
      !needsOutcomeResolution &&
      const [
        AgentStopReason.cancelled,
        AgentStopReason.interrupted,
        AgentStopReason.failed,
      ].contains(_session?.lastStopReason);

  Future<void> continueInterrupted() async {
    if (!canContinueInterrupted) return;
    _sending = true;
    _sendCancelled = false;
    _connectionInterrupted = false;
    _errorMessage = null;
    _tools.beginTurn();
    _notifyListeners();
    try {
      final result = await _requireSession().resume();
      _errorMessage = result.failure?.message;
      await _refreshConversations();
    } catch (error) {
      _setError(userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'));
    } finally {
      _sending = false;
      _refreshSnapshot();
    }
  }

  bool _configuring = false;
  Completer<void>? _configurationDone;
  Future<void>? _closing;

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get isRunning => _sending || (_session?.isRunning ?? false);
  bool get configuring => _configuring;
  bool get isBusy =>
      isRunning || _configuring || _compacting || _changingConversation;
  String? _contextEstimateKey;
  int _contextEstimate = 0;
  int get contextWindowTokens =>
      (_session?.modelProfile ?? _configuration.profile(modelProfileId))
          .contextWindowTokens;
  int get estimatedContextTokens {
    final session = _session;
    final profile =
        session?.modelProfile ?? _configuration.profile(modelProfileId);
    final rawMessages = session?.contextMessages ?? const <AgentMessage>[];
    // 工具正在运行时还没有结果，不能把半组调用交给严格的请求编码器。
    // 完整前缀使用同一估算器；未结束组仅按已收到的内容估算，不添加虚构结果。
    var completeLength = 0;
    final pending = <String>{};
    for (var i = 0; i < rawMessages.length; i++) {
      final message = rawMessages[i];
      if (message is AssistantMessage) {
        pending.addAll(message.toolCalls.map((c) => c.id));
      }
      if (message is ToolResultMessage) pending.remove(message.toolCallId);
      if (pending.isEmpty) completeLength = i + 1;
    }
    final messages = rawMessages.take(completeLength).toList();
    var pendingEstimate = 0.0;
    for (final message in rawMessages.skip(completeLength)) {
      final text =
          message.text +
          (message is AssistantMessage
              ? message.toolCalls.map((c) => jsonEncode(c.input)).join()
              : '');
      for (final rune in text.runes) {
        pendingEstimate += rune < 128 ? .4 : .8;
      }
    }
    final prompt = session?.systemPrompt ?? _effectiveSystemPrompt;
    final key =
        '${session?.id}:${profile.toJson()}:$prompt:${rawMessages.length}:${rawMessages.firstOrNull?.id}:${rawMessages.lastOrNull?.id}';
    if (_contextEstimateKey != key) {
      _contextEstimate = const ApproximateTokenEstimator().estimate(
        profile,
        ModelRequest(
          systemPrompt: prompt,
          messages: messages,
          tools: _tools.tools.map((tool) => tool.definition).toList(),
          maxOutputTokens: session?.outputTokens ?? profile.maxOutputTokens,
        ),
      );
      _contextEstimateKey = key;
    }
    return _contextEstimate + pendingEstimate.ceil();
  }

  bool _compacting = false;
  bool get compacting => _compacting;
  Future<ContextCompaction?> compactConversation() async {
    if (isBusy || _compacting || initializing) throw StateError('请等当前操作完成');
    if (!hasCredential) throw StateError('请先配置模型');
    final session = _session;
    if (session == null || session.transcript.isEmpty) return null;
    if (session.needsOutcomeResolution) throw StateError('请先核对未确认的操作结果');
    _compacting = true;
    _notifyListeners();
    try {
      return await session.compact();
    } finally {
      _compacting = false;
      _contextEstimateKey = null;
      if (!_closed) _refreshSnapshot();
    }
  }

  bool get hasCredential => profileHasCredential(modelProfileId);
  bool profileHasCredential(String id) => id == 'custom'
      ? _settings.hasCustomCredential
      : (_settings.hasDeepSeekCredential ?? _settings.hasCredential);
  ModelProfile? get customProfile => _settings.customProfile;
  bool get autoApproveWrites => _settings.autoApproveWrites;
  AssistantPermissionMode get permissionMode => _settings.permissionMode;
  AssistantSpeechSettings get speechSettings => _settings.speech;
  AssistantPersona get persona => _settings.persona;
  String get _effectiveSystemPrompt => buildAssistantSystemPrompt(persona);
  bool get hasTranscriptionCredential => _settings.hasTranscriptionCredential;
  bool get supportsImages {
    for (final profile in _configuration.profiles) {
      if (profile.id == modelProfileId) return profile.supportsImages;
    }
    // 旧会话或已删除的配置不应让能力查询抛错；按不支持图片处理。
    return false;
  }

  String get modelProfileId =>
      _session?.modelProfileId ?? _settings.modelProfileId;
  String get sessionTitle =>
      _session?.title ??
      (_reference == null
          ? '新会话'
          : '${_reference!.label} · ${_reference!.title}');
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

  AgentConfiguration get _configuration => _config._configuration;

  Future<void> initialize() => _config.initialize();

  Future<void> openMissionReference(String missionId) =>
      _sessions.openMissionReference(missionId);

  Future<void> openGoalReference(String goalId) =>
      _sessions.openGoalReference(goalId);

  Future<void> openNodeReference(String nodeId) =>
      _sessions.openNodeReference(nodeId);

  Future<void> openGlobalConversation() => _sessions.openGlobalConversation();

  Future<void> startNewSession({bool clearReference = true}) =>
      _sessions.startNewSession(clearReference: clearReference);

  Future<void> openConversation(String id) => _sessions.openConversation(id);

  Future<void> deleteConversation(String id) =>
      _sessions.deleteConversation(id);

  Future<void> renameCurrentSession(String title) =>
      _sessions.renameCurrentSession(title);

  Future<void> renameConversation(String id, String title) =>
      _sessions.renameConversation(id, title);

  Future<AgentRunResult?> send(String input) => _sessions.send(input);

  Future<AgentRunResult?> sendMessage(UserMessage message) =>
      _sessions.sendMessage(message);

  void stop() => _sessions.stop();

  Future<void> resolveUnknownOutcome(String callId) =>
      _operationCoordinator.resolveUnknownOutcome(callId);

  String? updateProposal(String callId, Map<String, Object?> input) =>
      _operationCoordinator.updateProposal(callId, input);

  /// 用户编辑后检查当前排期；旧检查返回时不能覆盖后来的一份预览。
  Future<String?> refreshPlanPreview(String callId) =>
      _operationCoordinator.refreshPlanPreview(callId);

  String? confirmProposal(String callId) =>
      _operationCoordinator.confirmProposal(callId);

  void cancelProposal(String callId) =>
      _operationCoordinator.cancelProposal(callId);

  Future<void> saveCredential(String value, {String? profileId}) =>
      _config.saveCredential(value, profileId: profileId);

  Future<void> saveCustomProfile(ModelProfile profile) =>
      _config.saveCustomProfile(profile);

  Future<void> selectModelProfile(String profileId) =>
      _config.selectModelProfile(profileId);

  Future<void> setAutoApproveWrites(bool value) =>
      _config.setAutoApproveWrites(value);

  Future<void> setPermissionMode(AssistantPermissionMode mode) =>
      _config.setPermissionMode(mode);

  Future<void> savePersona(AssistantPersona persona) =>
      _config.savePersona(persona);

  Future<void> saveSpeechSettings(
    AssistantSpeechSettings settings, {
    String? credential,
  }) => _config.saveSpeechSettings(settings, credential: credential);

  /// 独立分析请求不携带会话、记忆或工具；主会话开始时取消并让队列恢复。
  Future<String> analyze(
    String prompt, {
    String? imageKey,
    String? mime,
    bool json = false,
  }) => _gateway.analyze(prompt, imageKey: imageKey, mime: mime, json: json);
  Future<String> analyzeOnDemand(
    String prompt, {
    String? imageKey,
    String? mime,
    bool json = false,
  }) => _gateway.analyzeOnDemand(
    prompt,
    imageKey: imageKey,
    mime: mime,
    json: json,
  );

  Future<String> testConnection() => _gateway.testConnection();

  Future<void> loadLocalSchedule({String? date}) =>
      _gateway.loadLocalSchedule(date: date);

  void clearLocalSchedule() => _gateway.clearLocalSchedule();

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notifyListeners();
  }

  Future<ToolDecision> _authorize(
    ToolDefinition tool,
    ToolCallBlock call,
    CancellationToken cancellation,
  ) => _operationCoordinator._authorize(tool, call, cancellation);

  PreparedToolCall _resolveCall(String callId) =>
      _operationCoordinator._resolveCall(callId);

  AssistantOperation _operationFor(ToolCallBlock call) =>
      _operationCoordinator._operationFor(call);

  Future<void> _openSession(String id) => _sessions._openSession(id);

  Future<void> _closeSession() => _sessions._closeSession();

  void _refreshSnapshot() => _sessions._refreshSnapshot();

  void _refreshOperations() => _operationCoordinator._refreshOperations();

  Future<void> _refreshConversations() => _sessions._refreshConversations();

  AgentSession _requireSession() => _sessions._requireSession();

  void _ensureUsable() => _sessions._ensureUsable();

  String _today() => _sessions._today();

  void _setError(String message) {
    _errorMessage = message;
    _notifyListeners();
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _resumeWatchdog?.cancel();
    if (_closed) return;
    _closed = true;
    _gateway.interruptObsoleteRequests();
    stop();
    await _configurationDone?.future;
    await _changes?.cancel();
    await _events?.cancel();
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
