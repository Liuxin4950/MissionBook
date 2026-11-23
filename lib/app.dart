import 'application/attachments/attachment_coordinator.dart';
import 'application/missions/evidence_deadline_scheduler.dart';
import 'application/lifecycle/close_resources.dart';
import 'application/errors/user_error_message.dart';
import 'data/repositories/drift_memory_repository.dart';
import 'application/memory/memory_service.dart';
import 'application/records/record_service.dart';
import 'application/analysis/analysis_service.dart';
import 'application/web/web_service.dart';
import 'data/repositories/drift_record_repository.dart';
import 'data/analysis/drift_analysis_store.dart';
import 'data/memory/drift_memory_settings_store.dart';
import 'data/analysis/analysis_preferences_store.dart';
import 'data/assistant/drift_unified_reader.dart';
import 'data/web/web_settings_store.dart';
import 'data/web/public_http_client.dart';
import 'presentation/records/shared/record_scope.dart';
import 'application/settings/motion_settings.dart';
import 'application/settings/onboarding_store.dart';
import 'data/settings/motion_settings_store.dart';
import 'data/settings/onboarding_store.dart';
import 'presentation/widgets/motion_settings_scope.dart';
import 'dart:async';
import 'dart:io';
import 'application/missions/planned_mission_scheduler.dart';
import 'data/notifications/planned_alarm_bridge.dart';
import 'data/notifications/today_widget_bridge.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'application/missions/mission_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'core/theme/colors.dart';
import 'data/local/app_database.dart';
import 'data/repositories/drift_mission_repository.dart';
import 'app_shell.dart';
import 'application/assistant/assistant_controller.dart';
import 'application/assistant/assistant_speech.dart';
import 'application/assistant/assistant_supervision.dart';
import 'data/assistant/assistant_settings_store.dart';
import 'data/assistant/drift_session_store.dart';
import 'data/assistant/assistant_workspace_bridge.dart';
import 'data/assistant/configured_assistant_speech.dart';
import 'presentation/assistant/entry/assistant_scope.dart';
import 'application/attachments/attachment_file_service.dart';
import 'data/attachments/attachment_platform.dart' as attachment_platform;
import 'application/goals/goal_service.dart';
import 'application/goals/goal_package_import_service.dart';
import 'data/goal_import/goal_import_database.dart';
import 'data/repositories/drift_goal_package_repository.dart';
import 'data/repositories/drift_goal_repository.dart';
import 'data/goal_import/goal_file_picker_platform.dart' as goal_file_platform;
import 'application/backup/backup_service.dart';
import 'data/backup/database_backup_service.dart';
import 'data/backup/database_backup_restorer.dart';
import 'data/backup/local_resources.dart';
import 'data/settings/app_device_platform.dart';
import 'application/settings/app_device.dart';
import 'application/notifications/app_notification_service.dart';
import 'data/notifications/android_notification_dispatcher.dart';
import 'application/notifications/notification_dispatcher.dart';
import 'data/notifications/reminder_store.dart';
import 'data/notifications/windows_notification_dispatcher.dart';
import 'domain/notifications/reminder_request.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'presentation/launch/launch_page.dart';
import 'presentation/onboarding/onboarding_page.dart';
import 'core/theme/app_layout.dart';
import 'core/theme/app_motion.dart';

part 'app_services.dart';

/// 确保后台入口共享一个工作区，并让 Windows 先呈现启动界面。
void runMissionBook() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    runApp(const App());
    return;
  }
  final runtime = _AppRuntime()..install();
  runApp(App._(runtime));
}

/// 装配本地数据库、任务仓储和业务入口，并提供全局主题及中文界面。
class App extends StatefulWidget {
  const App({super.key}) : _runtime = null;
  const App._(this._runtime);
  final _AppRuntime? _runtime;

  @override
  State<App> createState() => _AppHostState();
}

/// 恢复后用新身份重新装配整个工作区，旧页面与会话缓存不会跨库沿用。
class _AppHostState extends State<App> {
  _AppRuntime? _runtime;
  Object? _startupError;
  String? _notice;

  @override
  void initState() {
    super.initState();
    if (widget._runtime != null ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.windows) {
      _runtime = widget._runtime ?? _AppRuntime();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startDesktopWorkspace();
    });
  }

  void _startDesktopWorkspace() {
    try {
      // Release the first frame before synchronously assembling database and services.
      final runtime = _AppRuntime()..install();
      if (!mounted) {
        unawaited(runtime.closeWorkspace());
        runtime.dispose();
        return;
      }
      setState(() {
        _runtime = runtime;
        _startupError = null;
      });
    } catch (error, stack) {
      debugPrint('桌面工作区启动失败：$error\n$stack');
      if (!mounted) return;
      setState(() => _startupError = error);
    }
  }

  Widget _buildDesktopStartup() => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppLayout.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppLayout.spaceMd),
                const Text('正在准备书祺', style: AppTypography.pageTitle),
                const SizedBox(height: AppLayout.spaceSm),
                Text(
                  _startupError == null ? '正在打开本机工作区…' : '工作区启动失败，请检查运行环境后重试。',
                  style: AppTypography.metadata,
                  textAlign: TextAlign.center,
                ),
                if (_startupError == null) ...[
                  const SizedBox(height: AppLayout.spaceLg),
                  const CircularProgressIndicator(semanticsLabel: '正在启动'),
                ] else ...[
                  const SizedBox(height: AppLayout.spaceLg),
                  FilledButton.icon(
                    onPressed: _startDesktopWorkspace,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    if (runtime == null) return _buildDesktopStartup();
    return ValueListenableBuilder(
      valueListenable: runtime,
      builder: (_, services, _) => services == null
          ? const SizedBox.shrink()
          : _AppWorkspace(
              key: ObjectKey(services),
              services: services,
              notice: _notice,
              onRestoreFinished: (notice) {
                if (!mounted) return;
                _notice = notice;
                unawaited(runtime.reload(services));
              },
            ),
    );
  }

  @override
  void dispose() {
    final runtime = _runtime;
    if (widget._runtime == null && runtime != null) {
      unawaited(runtime.closeWorkspace());
      runtime.dispose();
    }
    super.dispose();
  }
}

class _AppWorkspace extends StatefulWidget {
  const _AppWorkspace({
    super.key,
    required this.services,
    this.notice,
    required this.onRestoreFinished,
  });
  final String? notice;
  final _AppServices services;
  final void Function(String) onRestoreFinished;
  @override
  State<_AppWorkspace> createState() => _AppState();
}

class _AppState extends State<_AppWorkspace> with WidgetsBindingObserver {
  bool _restoring = false;
  Future<void>? _notificationInitialization;
  Future<void>? _restoreShutdown;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _launchComplete = false; // 应用启动完成标志
  Timer? _launchTimer;
  late final OnboardingStore _onboarding;
  bool _onboardingLoaded = false;
  bool _onboardingCompleted = true;
  bool _onboardingSaving = false;
  // late 表示这些属性稍后初始化。
  // final 表示初始化后不再换成另一个对象。
  AssistantController get _assistant => widget.services._assistant;
  RecordService get _records => widget.services._records;
  MemoryService get _memory => widget.services._memory;
  AnalysisService get _analysis => widget.services._analysis;
  WebService get _web => widget.services._web;
  AssistantVoiceController get _assistantVoice =>
      widget.services._assistantVoice;
  AppDatabase get _database => widget.services._database;
  MissionService get _missionService => widget.services._missionService;
  GoalService get _goalService => widget.services._goalService;
  late final BackupExporter _backupService; // 备份服务，负责导出数据。
  late final MotionSettings _motionSettings;
  late final AppDevice _device; // 设备服务，负责平台能力。
  // 系统提醒编排：装配层只负责创建与生命周期；业务规则在应用服务里。
  AppNotificationService? _notifications;
  bool _notificationsReady = false; // 通知服务是否初始化完成。
  Future<void>? _notificationRetry;
  bool _notificationQueueOverflowed = false;
  PlannedMissionScheduler? _plannedMissions; // 计划任务编排器，负责协调系统唤醒与任务执行。
  PlannedAlarmBridge? _plannedBridge; // 计划任务桥接，负责协调系统唤醒与任务执行。
  AndroidNotificationDispatcher? _androidDispatcher; // Android 通知分发器，负责发送通知。
  final _pendingNotificationResponses = <NotificationResponse>[]; // 待处理的通知响应队列。
  EvidenceDeadlineScheduler? _evidenceDeadlines; // 前台材料截止维护，独立拥有订阅与定时器。

  @override
  void initState() {
    super.initState();
    widget.services.closeFrontend = _closeFrontend;
    final attachments = widget.services._attachments;
    final attachmentStore = widget.services._attachmentStore;
    unawaited(_analysis.start());
    _backupService = ManagedBackupService(
      exporter: DatabaseBackupService(
        database: _database,
        readAttachment: _missionService.readEvidenceImage,
        attachments: attachments,
        localResources: createLocalResourceStore(),
      ),
      restorer: DatabaseBackupRestorer(
        database: _database,
        files: attachmentStore,
        attachments: attachments,
        localResources: createLocalResourceStore(),
      ),
      runRestore: _runRestore,
    );
    _device = createAppDevice();
    _onboarding = createOnboardingStore();
    unawaited(_loadOnboarding());
    _motionSettings = createMotionSettings();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      _motionSettings.addListener(_syncDesktopOverlayMotion);
    }
    final motionLoaded = _motionSettings.load();
    unawaited(motionLoaded);
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
    // Windows 通知插件在初始化时会同步回调平台生命周期；放到首帧之后，
    // 避免在 build/persistentCallbacks 阶段触发调度器断言。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notificationInitialization = _initNotifications();
      unawaited(_notificationInitialization!);
    });
    // 首帧先呈现品牌页；短暂过渡后才装载四个主页面。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await motionLoaded;
      if (!mounted) return;
      final reduced = _motionSettings.reduceMotion(
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations,
      );
      if (_launchComplete) return;
      _launchTimer = Timer(
        reduced ? Duration.zero : AppMotion.launchHold,
        _completeLaunch,
      );
    });
    WidgetsBinding.instance.addObserver(this);
    _evidenceDeadlines = EvidenceDeadlineScheduler(
      missions: _missionService,
      now: DateTime.now,
      onError: (error) => debugPrint('材料截止补算失败：$error'),
    );
    unawaited(_evidenceDeadlines!.start());
  }

  void _syncDesktopOverlayMotion() {
    unawaited(() async {
      try {
        await const MethodChannel('mission_book/device').invokeMethod<void>(
          'syncAssistantOverlayMotion',
          _motionSettings.preference.name,
        );
      } on MissingPluginException {
        // Widget 测试可只装配 Flutter 界面。
      } on PlatformException catch (error) {
        debugPrint('桌面悬浮球动效同步失败：${error.code}');
      }
    }());
  }

  void _completeLaunch() {
    if (!mounted || _launchComplete) return;
    _launchTimer?.cancel();
    setState(() => _launchComplete = true);
    if (widget.notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _messenger.currentState?.showSnackBar(
            SnackBar(content: Text(widget.notice!)),
          );
        }
      });
    }
  }

  Future<void> _loadOnboarding() async {
    try {
      final completed = await _onboarding.readCompleted();
      if (!mounted) return;
      setState(() {
        _onboardingCompleted = completed;
        _onboardingLoaded = true;
      });
    } catch (error, stack) {
      // 引导状态是 UI 偏好；读取失败时不阻断主工作区，避免用户被困在启动页。
      debugPrint('读取首次体验状态失败：$error\n$stack');
      if (!mounted) return;
      setState(() {
        _onboardingCompleted = true;
        _onboardingLoaded = true;
      });
    }
  }

  Future<bool> _finishOnboarding() async {
    if (_onboardingSaving) return false;
    setState(() {
      _onboardingSaving = true;
    });
    try {
      await _onboarding.markCompleted();
      if (!mounted) return true;
      setState(() {
        _onboardingCompleted = true;
        _onboardingSaving = false;
      });
      return true;
    } catch (error, stack) {
      debugPrint('保存首次体验状态失败：$error\n$stack');
      if (!mounted) return false;
      setState(() {
        _onboardingSaving = false;
      });
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_restoring) return;
    // 后台保留模型请求；麦克风单独结束，不能把切应用等同于用户停止AI。
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _assistant.setForeground(false);
      if (widget.services._overlay?.desktopVoiceActive != true) {
        unawaited(_assistantVoice.cancel());
      }
    }
    if (state == AppLifecycleState.detached) {
      _assistant.setForeground(false);
      if (widget.services._overlay == null) _assistant.stop();
    }
    if (state == AppLifecycleState.resumed) {
      _assistant.setForeground(true);
      widget.services._todayWidget?.refresh();
    }
    final foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _evidenceDeadlines?.setForeground(foreground);
    if (foreground) {
      _analysis.wake();
      if (!_notificationsReady && !kIsWeb) unawaited(_retryNotifications());
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
    if (_restoring || !_notificationsReady) return;
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

  Future<void> _retryNotifications() => _notificationRetry ??= (() async {
    try {
      // 首次初始化可能还在读取平台能力；等它结束后再决定是否恢复。
      await _notificationInitialization;
      if (!mounted || _restoring || _notificationsReady) return;
      await _notifications?.dispose();
      if (mounted && !_restoring) await _configureNotifications();
    } catch (error, stack) {
      debugPrint('提醒恢复失败：${error.runtimeType}\n$stack');
      _notifications?.reportFailure('提醒恢复未完成，请稍后回到应用重试');
    }
  })().whenComplete(() => _notificationRetry = null);

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    if (_restoring) return;
    if (!mounted ||
        response.notificationResponseType ==
            NotificationResponseType.notificationDismissed) {
      return;
    }
    if (_notifications == null || !_notificationsReady) {
      if (_pendingNotificationResponses.length >= 64) {
        _pendingNotificationResponses.removeAt(0);
        _notificationQueueOverflowed = true;
      }
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
    if (kIsWeb) {
      // Web 没有系统提醒能力，也不能在运行期访问本机应用支持目录。
      debugPrint('当前浏览器不支持系统提醒');
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // 临时对照：确认 Windows 原生 abort 是否来自通知插件初始化。
      debugPrint('Windows 通知初始化暂时跳过');
      return;
    }
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
    if (defaultTargetPlatform == TargetPlatform.android) {
      dispatcher = _androidDispatcher = AndroidNotificationDispatcher(
        plugin: plugin,
        // 精确提醒权限按 capabilities.exactAlarms 定档（N3.1 实测补全）。
        exactAlarmsAllowed: (await _device.capabilities()).exactAlarms ?? false,
      );
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      // 当前 exe 直发形态无法撤销调度项，实测/MSIX 定档后再调整。
      dispatcher = WindowsNotificationDispatcher(
        plugin: plugin,
        canCancelScheduled: false,
      );
    } else {
      dispatcher = const UnsupportedNotificationDispatcher();
    }
    final dir = await getApplicationSupportDirectory();
    final store = ReminderStore(File('${dir.path}/reminders.json'));
    await store.load();
    final recovered = store.needsNotificationReset;
    if (recovered) {
      // 编号表已损坏，先撤销旧通知再允许重新分配，避免旧编号误指向新任务。
      await plugin.cancelAll();
      await store.completeNotificationReset();
    }
    final notifications = AppNotificationService(
      missions: _missionService,
      store: store,
      dispatcher: dispatcher,
      now: DateTime.now,
    );
    if (!mounted) {
      await notifications.dispose();
      return;
    }
    setState(() => _notifications = notifications);
    await notifications.start();
    if (!mounted || _restoring) {
      await notifications.dispose();
      return;
    }
    _notificationsReady = true;
    if (recovered) notifications.reportFailure('提醒设置文件损坏，已保留原件并按当前任务重建提醒');
    if (_notificationQueueOverflowed) {
      _notificationQueueOverflowed = false;
      notifications.reportFailure('提醒初始化期间操作过多，部分旧操作已丢弃，请核对当前任务');
    }
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

  Future<BackupRestoreResult> _runRestore(
    Future<BackupRestoreResult> Function() restore,
  ) async {
    if (_restoring ||
        _assistant.isBusy ||
        _goalService.packages?.busy == true) {
      throw StateError('请先结束助手或目标导入操作，再恢复备份');
    }
    setState(() => _restoring = true);
    try {
      _restoreShutdown = _stopForRestore();
      await _restoreShutdown;
      final result = await restore();
      if (mounted) {
        widget.onRestoreFinished(
          '备份已恢复：${result.counts['missions'] ?? 0} 项任务，${result.counts['records'] ?? 0} 条记录；若备份包含助手设置与 Key，会覆盖本机模型配置',
        );
      }
      return result;
    } catch (_) {
      if (mounted) widget.onRestoreFinished('恢复未完成，当前数据已保留。请重新打开数据备份页重试。');
      rethrow;
    }
  }

  Future<void> _stopForRestore() async {
    // 先解绑旧工作区；重建后旧 State.dispose 不能清掉新工作区的通道监听。
    _plannedBridge?.dispose();
    await widget.services._overlay?.resetObservation();
    widget.services.stopExternalEntry();
    final stopped = await closeResources([
      (
        name: 'today widget',
        close: () async => widget.services._todayWidget?.close(),
      ),
      (name: 'voice', close: _assistantVoice.cancel),
      (name: 'assistant', close: _assistant.close),
      (name: 'analysis', close: _analysis.dispose),
      (
        name: 'notification initialization',
        close: () async => _notificationInitialization,
      ),
      (name: 'notification retry', close: () async => _notificationRetry),
      (name: 'deadlines', close: () async => _evidenceDeadlines?.dispose()),
      (
        name: 'planned missions',
        close: () async => _plannedMissions?.dispose(),
      ),
      (name: 'notifications', close: () async => _notifications?.dispose()),
      (
        name: 'system schedule',
        close: () async {
          await _plannedBridge?.beginSync();
          await _plannedBridge?.schedule(null);
        },
      ),
    ], onError: _logCloseFailure);
    if (!stopped) throw StateError('后台服务未全部停止，未替换当前数据，请重试恢复');
  }

  void _logCloseFailure(String name, Object error, StackTrace stack) =>
      debugPrint('资源释放失败 [$name]：${error.runtimeType}\n$stack');

  Future<void> _closeFrontend() async {
    WidgetsBinding.instance.removeObserver(this);
    _launchTimer?.cancel();
    if (_restoreShutdown == null) _plannedBridge?.dispose();
    await closeResources([
      (name: 'restore', close: () async => _restoreShutdown),
      (
        name: 'notification initialization',
        close: () async => _notificationInitialization,
      ),
      (name: 'notification retry', close: () async => _notificationRetry),
      (name: 'deadlines', close: () async => _evidenceDeadlines?.dispose()),
      (
        name: 'planned missions',
        close: () async => _plannedMissions?.dispose(),
      ),
      (name: 'notifications', close: () async => _notifications?.dispose()),
      (name: 'motion', close: _motionSettings.dispose),
    ], onError: _logCloseFailure);
    _pendingNotificationResponses.clear();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _messenger,
      title: 'MissionBook',
      builder: (context, child) => MotionSettingsHost(
        settings: _motionSettings,
        child: AssistantScope(
          createVoiceTest: () => AssistantVoiceController(
            ConfiguredAssistantSpeech(const SecureAssistantSettingsStore()),
            operationTimeout: const Duration(seconds: 60),
          ),
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
            goals: _goalService,
            child: Stack(
              children: [
                AbsorbPointer(absorbing: _restoring, child: child!),
                if (_restoring)
                  const Positioned.fill(
                    child: Material(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: AppLayout.spaceLg),
                            Text('正在恢复数据，请稍候…'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // build 可以重复执行，但这里始终传入已创建的同一个业务对象。
      home: Builder(
        builder: (context) => AnimatedSwitcher(
          duration: AppMotion.resolve(context, AppMotion.quick),
          child: !_launchComplete || !_onboardingLoaded
              ? LaunchPage(
                  key: const ValueKey('launch-page'),
                  onContinue: _onboardingLoaded ? _completeLaunch : null,
                )
              : !_onboardingCompleted
              ? OnboardingPage(
                  key: const ValueKey('onboarding-page'),
                  onFinish: _finishOnboarding,
                )
              : AppShell(
                  key: const ValueKey('app-shell'),
                  assistant: _assistant,
                  assistantWorkspace: widget.services._overlay,
                  missionService: _missionService,
                  goalService: _goalService,
                  backupService: _backupService,
                  device: _device,
                  notifications: _notifications,
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(widget.services.close());
    super.dispose();
  }
}
