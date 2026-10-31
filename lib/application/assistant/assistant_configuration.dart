part of 'assistant_controller.dart';

/// 助手控制器的独立职责；状态和生命周期由主控制器持有。
class _AssistantConfiguration {
  _AssistantConfiguration(this._controller);
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

  AgentConfiguration get _configuration {
    final base =
        _controller._baseConfiguration ?? AgentConfiguration.deepSeek();
    final selected = _controller._settings.modelProfileId;
    final profiles = [
      ...base.profiles.where((profile) => profile.id != 'custom'),
      if (_controller._settings.customProfile != null)
        _controller._settings.customProfile!,
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

  Future<void> initialize() => _controller._initializeFuture ??= _initialize();

  Future<void> _initialize() async {
    if (_controller._initialized ||
        _controller._initializing ||
        _controller._closed) {
      return;
    }
    _controller._initializing = true;
    _controller._notifyListeners();
    try {
      _controller._settings = await _controller._settingsStore.load();
      if (_controller._closed) return;
      _controller._runtime = AgentRuntime(
        configuration: _configuration,
        store: _controller._sessionStore,
        credentials: _controller._settingsStore.resolveCredential,
        tools: _controller._tools.tools,
        authorize: _controller._authorize,
        modelOverrides: _controller._modelOverrides,
      );
      await _controller._refreshConversations();
      if (_controller._closed) return;
      if (_controller._conversations.isNotEmpty) {
        await _controller._openSession(_controller._conversations.first.id);
      }
      _controller._initialized = true;
      _controller._errorMessage = null;
    } catch (error) {
      _controller._initializeFuture = null;
      _controller._errorMessage = userErrorMessage(
        error,
        fallback: '助手初始化失败，请重试',
      );
    } finally {
      _controller._initializing = false;
      _controller._notifyListeners();
    }
  }

  Future<void> saveCredential(String value, {String? profileId}) =>
      _updateConfiguration(() async {
        await _controller._settingsStore.saveCredential(
          (profileId ?? modelProfileId) == 'custom'
              ? 'MISSIONBOOK_CUSTOM_API_KEY'
              : 'DEEPSEEK_API_KEY',
          value,
        );
        await _reloadSettings();
      });

  Future<void> saveCustomProfile(ModelProfile profile) =>
      _updateConfiguration(() async {
        await _controller._settingsStore.saveCustomProfile(profile);
        final sessionId = currentSessionId;
        await _controller._closeSession();
        await _controller._runtime?.close();
        _controller._settings = await _controller._settingsStore.load();
        _controller._runtime = AgentRuntime(
          configuration: _configuration,
          store: _controller._sessionStore,
          credentials: _controller._settingsStore.resolveCredential,
          tools: _controller._tools.tools,
          authorize: _controller._authorize,
          modelOverrides: _controller._modelOverrides,
        );
        if (sessionId != null) await _controller._openSession(sessionId);
      });

  Future<void> selectModelProfile(String profileId) => _updateConfiguration(
    () async {
      if (!_configuration.profiles.any((profile) => profile.id == profileId)) {
        throw ArgumentError('请先保存所选模型的配置');
      }
      await _controller._settingsStore.saveModelProfile(profileId);
      _controller._settings = await _controller._settingsStore.load();
      if (_controller._session != null &&
          (_controller._session!.modelProfileId != profileId ||
              _controller._session!.summaryProfileId != profileId)) {
        await _controller._session!.selectModels(
          conversation: _controller._settings.modelProfileId,
          summary: _controller._settings.modelProfileId,
        );
      }
    },
  );

  Future<void> setAutoApproveWrites(bool value) =>
      _updateConfiguration(() async {
        await _controller._settingsStore.saveAutoApproveWrites(value);
        await _reloadSettings();
      });

  Future<void> setPermissionMode(AssistantPermissionMode mode) =>
      _updateConfiguration(() async {
        await _controller._settingsStore.savePermissionMode(mode);
        await _reloadSettings();
      });

  Future<void> savePersona(AssistantPersona persona) =>
      _updateConfiguration(() async {
        persona.validate();
        await _controller._settingsStore.savePersona(persona);
        await _reloadSettings();
        if (_controller._session != null) {
          await _controller._session!.setSystemPrompt(_effectiveSystemPrompt);
        }
      });

  Future<void> saveSpeechSettings(
    AssistantSpeechSettings settings, {
    String? credential,
  }) => _updateConfiguration(() async {
    settings.validate();
    if (credential != null) {
      await _controller._settingsStore.saveCredential(
        'MISSIONBOOK_TRANSCRIPTION_API_KEY',
        credential,
      );
    }
    await _controller._settingsStore.saveSpeechSettings(settings);
    await _reloadSettings();
  });

  Future<void> _updateConfiguration(Future<void> Function() update) async {
    if (!_controller._initialized && _controller._runtime == null) {
      await initialize();
    }
    _controller._ensureUsable();
    if (isRunning) throw StateError('请先结束本轮，再修改助手设置');
    _controller._configuring = true;
    final done = Completer<void>();
    _controller._configurationDone = done;
    _controller._notifyListeners();
    try {
      await update();
      await _controller._analysis?.resumeBlocked();
    } finally {
      _controller._configuring = false;
      _controller._configurationDone = null;
      done.complete();
      if (!_controller._closed) _controller._notifyListeners();
    }
  }

  Future<void> _reloadSettings() async {
    _controller._settings = await _controller._settingsStore.load();
    await _controller._analysis?.resumeBlocked();
    _controller._errorMessage = null;
    _controller._notifyListeners();
  }
}
