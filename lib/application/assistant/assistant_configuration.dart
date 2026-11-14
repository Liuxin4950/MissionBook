part of 'assistant_controller.dart';

/// 一次服务保存的结果；目录已生效时也可能带有后续需要处理的提示。
final class ProviderSaveReceipt {
  const ProviderSaveReceipt({
    required this.providerId,
    this.warnings = const [],
  });

  final String providerId;
  final List<String> warnings;
}

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

  /// 目录是唯一运行来源；停用的服务与模型仍会编译进来，保证历史会话可打开。
  AgentConfiguration get _configuration {
    final base =
        _controller._baseConfiguration ?? AgentConfiguration.deepSeek();
    return _controller._settings.catalog.compileConfiguration(
      base: base,
      reasoningEfforts: _controller._settings.reasoningEfforts,
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
      _controller._runtime = _buildRuntime();
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

  AgentRuntime _buildRuntime() => AgentRuntime(
    configuration: _configuration,
    store: _controller._sessionStore,
    credentials: _controller._settingsStore.resolveCredential,
    tools: _controller._tools.tools,
    authorize: _controller._authorize,
    modelOverrides: _controller._modelOverrides,
  );

  /// 目录变化后重建运行时；重建前后都保留当前会话，避免用户丢失上下文。
  Future<void> _rebuildRuntime({String? reopenSessionId}) async {
    await _controller._closeSession();
    await _controller._runtime?.close();
    _controller._settings = await _controller._settingsStore.load();
    _controller._runtime = _buildRuntime();
    if (reopenSessionId != null) {
      await _controller._openSession(reopenSessionId);
    }
  }

  /// 一次提交服务、该服务的模型与凭据。
  ///
  /// 顺序为：校验 → 写新凭据 → 整份目录写入 → 重建运行时 → 重开会话。
  /// 目录写入失败时回收本次新写入的凭据，并保留旧目录继续生效。
  Future<ProviderSaveReceipt> saveProvider({
    required ProviderConfig provider,
    required List<ProviderModel> models,
    String? credential,
    bool clearCredential = false,
  }) => _updateConfiguration(() async {
    final settings = _controller._settings;
    final catalog = settings.catalog;
    final warnings = <String>[];

    for (final model in models) {
      if (model.providerId != provider.providerId) {
        throw ArgumentError(
          '模型 ${model.profileId} 不属于服务 ${provider.providerId}',
        );
      }
    }

    // 表单里被移除的模型只停用，不物理删除，否则旧会话会找不到历史身份。
    final incoming = {for (final model in models) model.profileId: model};
    final existing = catalog.modelsOfProvider(
      provider.providerId,
      includeArchived: true,
    );
    final mergedModels = [
      for (final model in existing)
        incoming.remove(model.profileId) ?? model.copyWith(archived: true),
      ...incoming.values,
    ];

    final nextCatalog = ProviderCatalog(
      providers: [
        for (final item in catalog.providers)
          if (item.providerId != provider.providerId) item,
        provider,
      ],
      models: [
        for (final item in catalog.models)
          if (item.providerId != provider.providerId) item,
        ...mergedModels,
      ],
      selection: catalog.selection,
    );

    final archivedDefault = nextCatalog.modelOfProfile(
      nextCatalog.selection.defaultProfileId,
    );
    if (archivedDefault == null || archivedDefault.archived) {
      throw StateError('请先把默认模型切换到其他模型，再停用当前默认模型');
    }

    final sessionId = _controller.currentSessionId;
    final wroteNewCredential =
        !clearCredential &&
        credential != null &&
        credential.trim().isNotEmpty &&
        !settings.configuredCredentials.contains(provider.credentialRef);

    if (clearCredential) {
      await _controller._settingsStore.saveCredential(
        provider.credentialRef,
        '',
      );
    } else if (credential != null && credential.trim().isNotEmpty) {
      await _controller._settingsStore.saveCredential(
        provider.credentialRef,
        credential,
      );
    }

    try {
      await _controller._settingsStore.saveCatalog(nextCatalog);
    } on Object {
      if (wroteNewCredential) {
        try {
          await _controller._settingsStore.saveCredential(
            provider.credentialRef,
            '',
          );
        } on Object {
          warnings.add('目录保存失败，且本次输入的 Key 未能自动清理，请重试');
        }
      }
      rethrow;
    }

    try {
      await _rebuildRuntime(reopenSessionId: sessionId);
    } on Object catch (error) {
      warnings.add('模型目录已保存，但当前会话重载失败：$error');
    }

    return ProviderSaveReceipt(
      providerId: provider.providerId,
      warnings: warnings,
    );
  });

  Future<void> setProviderArchived(String providerId, bool archived) =>
      _updateConfiguration(() async {
        final settings = _controller._settings;
        final catalog = settings.catalog;
        catalog.providerOf(providerId);
        if (archived) {
          final selectableDefaults = catalog
              .modelsOfProvider(providerId)
              .where(
                (model) =>
                    model.profileId == catalog.selection.defaultProfileId,
              );
          if (selectableDefaults.isNotEmpty) {
            throw StateError('请先把默认模型切换到其他服务，再停用该服务');
          }
          final sessionModelId = _controller._session?.modelProfileId;
          if (sessionModelId != null &&
              catalog.modelOfProfile(sessionModelId)?.providerId ==
                  providerId) {
            throw StateError('请先为当前会话选择其他模型，再停用该服务');
          }
        }
        final next = catalog.copyWith(
          providers: [
            for (final item in catalog.providers)
              item.providerId == providerId
                  ? item.copyWith(archived: archived)
                  : item,
          ],
        );
        await _controller._settingsStore.saveCatalog(next);
        await _reloadSettings();
      });

  Future<void> setModelArchived(String profileId, bool archived) =>
      _updateConfiguration(() async {
        final settings = _controller._settings;
        final catalog = settings.catalog;
        final model = catalog.modelOfProfile(profileId);
        if (model == null) throw ArgumentError('不存在模型：$profileId');
        if (archived) {
          if (catalog.selection.defaultProfileId == profileId) {
            throw StateError('请先把默认模型切换到其他模型，再停用该模型');
          }
          if (_controller._session?.modelProfileId == profileId) {
            throw StateError('请先为当前会话选择其他模型，再停用该模型');
          }
        }
        final next = catalog.copyWith(
          models: [
            for (final item in catalog.models)
              item.profileId == profileId
                  ? item.copyWith(archived: archived)
                  : item,
          ],
        );
        await _controller._settingsStore.saveCatalog(next);
        await _reloadSettings();
      });

  /// 只影响之后创建的新会话；不隐式改写已打开的会话。
  Future<void> setDefaultModels({required String main, String? summary}) =>
      _updateConfiguration(() async {
        final settings = _controller._settings;
        final catalog = settings.catalog;
        if (!catalog.isSelectable(main)) {
          throw StateError('该模型已停用，不能设为默认模型');
        }
        if (!settings.profileHasCredential(main)) {
          throw StateError('该服务还没有配置凭据');
        }
        if (summary != null) {
          if (!catalog.isSelectable(summary)) {
            throw StateError('摘要模型已停用，请选择其他模型');
          }
          if (!settings.profileHasCredential(summary)) {
            throw StateError('摘要模型所属服务还没有配置凭据');
          }
        }
        await _controller._settingsStore.saveSelection(
          ModelSelection(defaultProfileId: main, summaryProfileId: summary),
        );
        await _reloadSettings();
      });

  /// 只切换当前会话使用的模型，不改全局默认。
  Future<void> selectSessionModel(String profileId) =>
      _updateConfiguration(() async {
        final settings = _controller._settings;
        final catalog = settings.catalog;
        final session = _controller._session;
        if (session == null) throw StateError('请先打开或新建一个会话');
        if (!catalog.isSelectable(profileId)) {
          throw StateError('该模型已停用，请选择可用模型');
        }
        if (!settings.profileHasCredential(profileId)) {
          throw StateError('该服务还没有配置凭据');
        }
        if (session.modelProfileId == profileId) return;
        await session.selectModels(
          conversation: profileId,
          // 未显式设置摘要模型时跟随当前会话主模型。
          summary: catalog.selection.summaryProfileId ?? profileId,
        );
        await _applyReasoningEffort();
      });

  Future<void> saveCredentialForProvider(String providerId, String value) =>
      _updateConfiguration(() async {
        final provider = _controller._settings.catalog.providerOf(providerId);
        await _controller._settingsStore.saveCredential(
          provider.credentialRef,
          value,
        );
        await _reloadSettings();
      });

  Future<void> setReasoningEffort(ReasoningEffort effort) =>
      _updateConfiguration(() async {
        await _controller._settingsStore.saveReasoningEffort(
          modelProfileId,
          effort,
        );
        _controller._settings = await _controller._settingsStore.load();
        await _applyReasoningEffort();
      });

  Future<void> _applyReasoningEffort() async {
    final session = _controller._session;
    if (session == null) return;
    final effort =
        _controller._settings.reasoningEfforts[session.modelProfileId];
    if (effort == null) return;
    if (session.reasoningEffort != effort) {
      await session.configureGeneration(thinking: effort);
    }
  }

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

  Future<T> _updateConfiguration<T>(Future<T> Function() update) async {
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
      return await update();
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
