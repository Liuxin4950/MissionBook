part of 'app.dart';

/// 一个工作区的一组服务；先于页面创建，悬浮窗可从同一 Dart 引擎访问。
class _AppServices {
  _AppServices() {
    // Flutter 创建这个 State 后调用一次 initState。
    // 不传 executor，由 AppDatabase 按平台选择原生文件或浏览器存储。
    _database = AppDatabase();
    // 将同一个数据库交给真实仓储。
    final repository = DriftMissionRepository(_database);
    // 这里只创建一个共享的任务业务对象，不执行创建或查询。
    // 页面稍后通过 create / findScheduledOn / findDetail 选择具体操作；
    // 三个方法使用同一个仓储、同一个数据库连接。
    // 平台能力只在 App 装配；业务服务依赖可注入接口，不反向引用 data 实现。
    _attachmentStore = attachment_platform.createImageStore();
    _attachments = AttachmentCoordinator(
      referencedKeys: repository.referencedAttachmentKeys,
      files: AttachmentFileService(
        store: _attachmentStore,
        picker: attachment_platform.createImagePicker(),
        filePicker: attachment_platform.createFilePicker(),
      ),
    );
    _missionService = MissionService(repository, attachments: _attachments);
    // 启动即回收无引用原件：崩溃或取消留下的副本不必等用户下次打开编辑器才清理。
    // 协调器只执行一次并与提交互斥；失败只记录，不影响启动和后续准备。
    unawaited(() async {
      try {
        await _attachments.initialize();
      } catch (error) {
        debugPrint('启动清理无引用附件失败：$error');
      }
    }());
    final packages = GoalPackageImportService(
      stage: GoalImportDatabase(),
      repository: DriftGoalPackageRepository(_database),
      onCommitted: () {
        _goalService.refreshAfterExternalCommit();
        _missionService.refreshAfterExternalCommit();
      },
    );
    _goalService = GoalService(
      DriftGoalRepository(_database),
      filePicker: goal_file_platform.createGoalFilePicker(),
      packages: packages,
    );
    // 记录与记忆各自负责内容和长期上下文，所有仓储共享同一个数据库连接。
    final recordRepository = DriftRecordRepository(
      _database,
      materials: repository,
    );
    _memory = MemoryService(DriftMemoryRepository(_database));
    _records = RecordService(recordRepository, _missionService, _attachments);
    final analysisStore = DriftAnalysisStore(_database);
    _web = WebService(
      settings: const SecureWebSettings(),
      quota: DriftSearchQuota(_database),
      fetchClient: publicHttpClient,
    );
    _assistant = AssistantController(
      records: _records,
      memory: _memory,
      analysis: analysisStore,
      unifiedReader: DriftUnifiedReader(_database),
      web: _web,
      sessionStore: DriftSessionStore(_database),
      settingsStore: const SecureAssistantSettingsStore(),
      missions: _missionService,
      goals: _goalService,
    );
    _analysis = AnalysisService(
      preferencesStore: const SecureAnalysisPreferences(),
      memorySettings: DriftMemorySettingsStore(_database),
      missions: _missionService,
      store: analysisStore,
      model: _assistant.analyze,
      mainBusy: () => _assistant.isRunning,
    );
    final speech = ConfiguredAssistantSpeech(
      const SecureAssistantSettingsStore(),
    );
    _assistantVoice = AssistantVoiceController(
      speech,
      operationTimeout: const Duration(seconds: 60),
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _overlay = AndroidAssistantBridge(
        _assistant,
        speech: speech,
        supervision: AssistantSupervision(_assistant, _missionService),
      )..install();
    }
  }

  late final AppDatabase _database;
  late final MissionService _missionService;
  late final GoalService _goalService;
  late final MemoryService _memory;
  late final RecordService _records;
  late final WebService _web;
  late final AssistantController _assistant;
  late final AnalysisService _analysis;
  late final AssistantVoiceController _assistantVoice;
  late final AttachmentCoordinator _attachments;
  late final AttachmentStore _attachmentStore;
  AndroidAssistantBridge? _overlay;
  Future<void> Function()? closeFrontend;
  Future<void>? _closing;

  void stopExternalEntry() => _overlay?.detach();

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    stopExternalEntry();
    await closeResources(
      [
        (name: 'frontend', close: () async => closeFrontend?.call()),
        (name: 'voice', close: _assistantVoice.close),
        (name: 'assistant', close: _assistant.close),
        (name: 'analysis', close: _analysis.dispose),
        (
          name: 'goal import',
          close: () async => _goalService.packages?.dispose(),
        ),
        (name: 'missions', close: _missionService.dispose),
        (name: 'goals', close: _goalService.dispose),
        (name: 'assistant listeners', close: _assistant.dispose),
        (name: 'voice listeners', close: _assistantVoice.dispose),
        (name: 'database', close: _database.close),
      ],
      onError: (name, error, stack) {
        debugPrint('工作区释放失败 [$name]：$error\n$stack');
      },
    );
  }
}

/// Android 引擎没有 View 时仍可启动/关闭唯一的助手工作区。
class _AppRuntime extends ValueNotifier<_AppServices?> {
  _AppRuntime() : super(_AppServices());

  static const _lifecycle = MethodChannel('mission_book/workspace_lifecycle');
  Future<void>? _closing;

  void install() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _lifecycle.setMethodCallHandler((call) async {
      if (call.method == 'close') {
        await closeWorkspace();
      } else if (call.method == 'open') {
        await _closing;
        value ??= _AppServices();
      } else {
        throw MissingPluginException(call.method);
      }
    });
  }

  Future<void> closeWorkspace() async {
    final services = value;
    if (services != null) {
      _closing = services.close();
      value = null;
    }
    await _closing;
  }

  Future<void> reload(_AppServices previous) async {
    if (!identical(value, previous)) return;
    await closeWorkspace();
    value ??= _AppServices();
  }
}
