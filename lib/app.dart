import 'application/missions/evidence_deadline_scheduler.dart';
import 'application/errors/user_error_message.dart';
import 'data/repositories/drift_memory_repository.dart';
import 'application/memory/memory_service.dart';
import 'application/records/record_service.dart';
import 'application/analysis/analysis_service.dart';
import 'application/web/web_service.dart';
import 'data/repositories/drift_record_repository.dart';
import 'data/analysis/drift_analysis_store.dart';
import 'data/analysis/analysis_preferences_store.dart';
import 'data/assistant/drift_unified_reader.dart';
import 'data/web/web_settings_store.dart';
import 'data/web/public_http_client.dart';
import 'presentation/records/record_scope.dart';
import 'application/settings/motion_settings.dart';
import 'data/settings/motion_settings_store.dart';
import 'presentation/widgets/motion_settings_scope.dart';
import 'dart:async';
import 'dart:io';
import 'application/missions/planned_mission_scheduler.dart';
import 'data/notifications/planned_alarm_bridge.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'application/missions/mission_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'data/local/app_database.dart';
import 'data/repositories/drift_mission_repository.dart';
import 'app_shell.dart';
import 'application/assistant/assistant_controller.dart';
import 'application/assistant/assistant_speech.dart';
import 'data/assistant/assistant_settings_store.dart';
import 'data/assistant/drift_session_store.dart';
import 'data/assistant/drift_assistant_reader.dart';
import 'data/assistant/configured_assistant_speech.dart';
import 'presentation/assistant/assistant_scope.dart';
import 'application/evidence/evidence_image_service.dart';
import 'data/attachments/evidence_image_platform.dart' as image_platform;
import 'application/goals/goal_service.dart';
import 'application/goals/goal_package_import_service.dart';
import 'data/goal_import/goal_import_database.dart';
import 'data/repositories/drift_goal_package_repository.dart';
import 'data/repositories/drift_goal_repository.dart';
import 'data/goal_import/goal_file_picker_platform.dart' as goal_file_platform;
import 'application/backup/backup_service.dart';
import 'data/backup/database_backup_service.dart';
import 'data/settings/app_device_platform.dart';
import 'application/settings/app_device.dart';
import 'application/notifications/app_notification_service.dart';
import 'data/notifications/android_notification_dispatcher.dart';
import 'data/notifications/notification_dispatcher.dart';
import 'data/notifications/reminder_store.dart';
import 'data/notifications/windows_notification_dispatcher.dart';
import 'domain/notifications/reminder_request.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'presentation/launch/launch_page.dart';
import 'core/theme/app_motion.dart';

/// 装配本地数据库、任务仓储和业务入口，并提供全局主题及中文界面。
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  bool _launchComplete = false; // 应用启动完成标志
  Timer? _launchTimer;
  // late 表示这些属性稍后初始化。
  // final 表示初始化后不再换成另一个对象。
  late final AssistantController _assistant;
  late final RecordService _records;
  late final MemoryService _memory;
  late final AnalysisService _analysis;
  late final WebService _web;
  late final AssistantVoiceController _assistantVoice;
  late final AppDatabase _database; // 定义数据库连接器
  late final MissionService _missionService; // 业务操作对象
  late final GoalService _goalService; // 目标服务，与任务服务共用数据库。
  late final BackupExporter _backupService; // 备份服务，负责导出数据。
  late final MotionSettings _motionSettings;
  late final AppDevice _device; // 设备服务，负责平台能力。
  // 系统提醒编排：装配层只负责创建与生命周期；业务规则在应用服务里。
  AppNotificationService? _notifications;
  bool _notificationsReady = false; // 通知服务是否初始化完成。
  PlannedMissionScheduler? _plannedMissions; // 计划任务编排器，负责协调系统唤醒与任务执行。
  PlannedAlarmBridge? _plannedBridge; // 计划任务桥接，负责协调系统唤醒与任务执行。
  AndroidNotificationDispatcher? _androidDispatcher; // Android 通知分发器，负责发送通知。
  final _pendingNotificationResponses = <NotificationResponse>[]; // 待处理的通知响应队列。
  EvidenceDeadlineScheduler? _evidenceDeadlines; // 前台材料截止维护，独立拥有订阅与定时器。

  @override
  void initState() {
    super.initState();
    // Flutter 创建这个 State 后调用一次 initState。
    // 不传 executor，由 AppDatabase 按平台选择原生文件或浏览器存储。
    _database = AppDatabase();
    // 将同一个数据库交给真实仓储。
    final repository = DriftMissionRepository(_database);
    // 这里只创建一个共享的任务业务对象，不执行创建或查询。
    // 页面稍后通过 create / findScheduledOn / findDetail 选择具体操作；
    // 三个方法使用同一个仓储、同一个数据库连接。
    // 平台能力只在 App 装配；业务服务依赖可注入接口，不反向引用 data 实现。
    _missionService = MissionService(
      repository,
      images: EvidenceImageService(
        store: image_platform.createImageStore(),
        picker: image_platform.createImagePicker(),
        filePicker: image_platform.createFilePicker(),
      ),
    );
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
    _records = RecordService(recordRepository, _missionService);
    final analysisStore = DriftAnalysisStore(_database);
    _web = WebService(
      settings: const SecureWebSettings(),
      quota: DriftSearchQuota(_database),
      fetchClient: publicHttpClient,
    );
    _assistant = AssistantController(
      reader: DriftAssistantReader(_database),
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
      store: analysisStore,
      model: _assistant.analyze,
      mainBusy: () => _assistant.isRunning,
    );
    unawaited(_analysis.start());
    _assistantVoice = AssistantVoiceController(
      ConfiguredAssistantSpeech(const SecureAssistantSettingsStore()),
      operationTimeout: const Duration(seconds: 60),
    );
    _backupService = DatabaseBackupService(
      database: _database,
      readAttachment: _missionService.readEvidenceImage,
    );
    _device = createAppDevice();
    _motionSettings = createMotionSettings();
    unawaited(_motionSettings.load());
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _plannedBridge = PlannedAlarmBridge()
        ..listenForCommits(_missionService.refreshAfterExternalCommit);
    }
    _plannedMissions = PlannedMissionScheduler(
      missions: _missionService,
      now: DateTime.now,
      beforeRefresh: () async {
        await _plannedBridge?.beginSync();
      },
      scheduleInSystem: (next) async {
        // 后台复用的通知编号先持久化，再允许系统唤醒。
        // 通知失败单独提示，仍安排系统自动执行；编号缺失只影响通知呈现。
        await _refreshNotifications();
        await _plannedBridge?.schedule(next);
      },
      onError: (error) {
        debugPrint('计划任务自动执行失败：$error');
        _notifications?.reportFailure(
          userErrorMessage(error, fallback: '计划任务自动执行失败，请刷新重试'),
        );
      },
    );
    unawaited(_initNotifications());
    // 首帧先呈现品牌页；短暂过渡后才装载四个主页面。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _launchTimer = Timer(AppMotion.launch, () {
        if (mounted) setState(() => _launchComplete = true);
      });
    });
    WidgetsBinding.instance.addObserver(this);
    _evidenceDeadlines = EvidenceDeadlineScheduler(
      missions: _missionService,
      now: DateTime.now,
      onError: (error) => debugPrint('材料截止补算失败：$error'),
    );
    unawaited(_evidenceDeadlines!.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 后台保留模型请求；麦克风单独结束，不能把切应用等同于用户停止AI。
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _assistant.setForeground(false);
      unawaited(_assistantVoice.cancel());
    }
    if (state == AppLifecycleState.detached) _assistant.stop();
    if (state == AppLifecycleState.resumed) _assistant.setForeground(true);
    final foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _evidenceDeadlines?.setForeground(foreground);
    if (foreground) {
      _analysis.wake();
      // 回到前台对账一次提醒调度（§7.1：只整理提醒，不写业务事实）。
      unawaited(_refreshNotifications());
      unawaited(_plannedMissions?.refreshSafely());
    }
  }

  /// 装配系统提醒：按平台选分发端，提醒偏好存应用支持目录（不进备份）。
  Future<void> _initNotifications() async {
    try {
      await _configureNotifications();
    } catch (error, stack) {
      debugPrint('通知初始化失败：$error\n$stack');
      _notifications?.reportFailure('提醒暂不可用，请稍后重试');
    } finally {
      if (mounted) {
        await _plannedMissions?.start().catchError((Object error) {
          debugPrint('计划任务调度初始化失败：$error');
          unawaited(_plannedMissions?.refreshSafely());
        });
      }
    }
  }

  Future<void> _refreshNotifications() async {
    try {
      if (_androidDispatcher != null) {
        _androidDispatcher!.updateExactAlarmPermission(
          (await _device.capabilities()).exactAlarms ?? false,
        );
      }
      await _notifications?.refresh();
    } catch (error) {
      _notifications?.reportFailure(
        userErrorMessage(error, fallback: '提醒更新失败，请稍后重试'),
      );
    }
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    if (!mounted ||
        response.notificationResponseType ==
            NotificationResponseType.notificationDismissed) {
      return;
    }
    if (_notifications == null || !_notificationsReady) {
      _pendingNotificationResponses.add(response);
      return;
    }
    final request = ReminderRequest.fromPayload(response.payload);
    if (request == null) return;
    await _notifications!.handleAction(
      request,
      actionId:
          response.notificationResponseType ==
              NotificationResponseType.selectedNotificationAction
          ? response.actionId ?? ''
          : '',
    );
  }

  Future<void> _configureNotifications() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_mission'),
        windows: WindowsInitializationSettings(
          appName: 'Mission Book',
          appUserModelId: 'chat.liuxin.mission_book',
          guid: '6f1b2c8e-4a5d-4f3a-9c0b-2e7d8a1b3c4d',
        ),
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    final NotificationDispatcher dispatcher;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      dispatcher = _androidDispatcher = AndroidNotificationDispatcher(
        plugin: plugin,
        // 精确提醒权限按 capabilities.exactAlarms 定档（N3.1 实测补全）。
        exactAlarmsAllowed: (await _device.capabilities()).exactAlarms ?? false,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      // 当前 exe 直发形态无法撤销调度项，实测/MSIX 定档后再调整。
      dispatcher = WindowsNotificationDispatcher(
        plugin: plugin,
        canCancelScheduled: false,
      );
    } else {
      dispatcher = const UnsupportedNotificationDispatcher();
    }
    final dir = await getApplicationSupportDirectory();
    final notifications = AppNotificationService(
      missions: _missionService,
      store: ReminderStore(File('${dir.path}/reminders.json')),
      dispatcher: dispatcher,
      now: DateTime.now,
    );
    if (!mounted) {
      await notifications.dispose();
      return;
    }
    setState(() => _notifications = notifications);
    await notifications.start();
    _notificationsReady = true;
    // 进程由通知启动时，初始化回调不会补发启动意图，必须显式读取。
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse != null) {
      _pendingNotificationResponses.add(launch!.notificationResponse!);
    }
    final pending = List<NotificationResponse>.of(
      _pendingNotificationResponses,
    );
    _pendingNotificationResponses.clear();
    for (final response in pending) {
      await _handleNotificationResponse(response);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MissionBook',
      builder: (context, child) => MotionSettingsHost(
        settings: _motionSettings,
        child: AssistantScope(
          controller: _assistant,
          voice: _assistantVoice,
          missions: _missionService,
          goals: _goalService,
          backup: _backupService,
          device: _device,
          child: RecordScope(
            service: _records,
            memory: _memory,
            analysis: _analysis,
            web: _web,
            child: child!,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // build 可以重复执行，但这里始终传入已创建的同一个业务对象。
      home: AnimatedSwitcher(
        duration: AppMotion.resolve(context, AppMotion.quick),
        child: _launchComplete
            ? AppShell(
                key: const ValueKey('app-shell'),
                assistant: _assistant,
                missionService: _missionService,
                goalService: _goalService,
                backupService: _backupService,
                device: _device,
                notifications: _notifications,
              )
            : const LaunchPage(key: ValueKey('launch-page')),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _launchTimer?.cancel();
    _plannedBridge?.dispose();
    final deadlineClose = _evidenceDeadlines?.dispose();
    final plannedClose = _plannedMissions?.dispose();
    unawaited(_notifications?.dispose());
    // Flutter 移除这个 State 时调用 dispose。
    // close 返回 Future，但 dispose 不能等待异步完成；
    // unawaited 明确表示在这里发起关闭，不等待它。
    unawaited(_missionService.dispose());
    unawaited(_goalService.dispose());
    unawaited(_goalService.packages?.dispose());
    _motionSettings.dispose();
    _assistantVoice.dispose();
    unawaited(
      _assistant.close().then((_) async {
        _assistant.dispose();
        await _analysis.dispose();
        await deadlineClose;
        await plannedClose;
        return _database.close();
      }),
    );
    super.dispose();
  }
}
