import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'presentation/today/today_page.dart';
import 'package:flutter/services.dart';
import 'application/assistant/assistant_controller.dart';
import 'data/assistant/assistant_workspace_bridge.dart';
import 'presentation/assistant/entry/assistant_launcher.dart';
import 'presentation/assistant/entry/assistant_scope.dart';
import 'presentation/assistant/settings/assistant_settings_page.dart';
import 'application/missions/mission_service.dart';
import 'application/notifications/app_notification_service.dart';
import 'core/theme/app_layout.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/colors.dart';
import 'presentation/missions/execution/mission_execution_page.dart';
import 'presentation/missions/detail/mission_detail_page.dart';
import 'domain/entities/mission_phase.dart';
import 'presentation/missions/shared/active_missions_bar.dart';
import 'presentation/missions/history/mission_history_page.dart';
import 'presentation/records/list/records_page.dart';
import 'application/goals/goal_service.dart';
import 'presentation/goals/list/goals_page.dart';
import 'application/backup/backup_service.dart';
import 'application/settings/app_device.dart';
import 'presentation/me/me_page.dart';
import 'presentation/widgets/detail_pane.dart';
import 'presentation/widgets/app_interactive_surface.dart';
import 'presentation/widgets/app_content_transition.dart';

/// 管理顶层导航入口，并保留各页状态、转交共享业务对象。
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.missionService,
    required this.goalService,
    required this.backupService,
    required this.device,
    this.notifications,
    this.assistant,
    this.assistantWorkspace,
    this.clock = DateTime.now,
  });
  // App 传入共享任务服务，本层转交给今天、历史及当前任务栏。
  final MissionService missionService;
  final GoalService goalService; // 由 App 装配并转交给目标页面。
  final BackupExporter backupService;
  final AppDevice device;

  // 通知动作的 UI 部分由外壳承接：打开 END 确认、旧按钮提示刷新。
  final AppNotificationService? notifications;
  final AssistantController? assistant;
  final AssistantWorkspaceBridge? assistantWorkspace;

  /// 今天页使用的日期时钟；测试传入固定时刻，避免随运行日期改变查询。
  final DateTime Function() clock;

  @override
  State<AppShell> createState() {
    return _AppShellState();
  }
}

class _AppShellState extends State<AppShell> {
  static const _overlayChannel = MethodChannel(
    'mission_book/assistant_overlay',
  );
  // 索引
  int _selectedIndex = 0;
  final _visitedPages = <int>{0};

  // 右栏导航控制器：外壳常驻持有。宽屏并排、窄屏全屏接管都是同一个栈，
  // 窗口缩放只换显示位置，不重建页面（草稿、返回链都留在栈里）。
  final _detailPane = DetailPaneController();
  final _pageStackKey = GlobalKey();
  final _assistantEntry = GlobalKey<AssistantLauncherState>();
  StreamSubscription<NotificationUiAction>? _uiActions;
  bool _selectingPage = false;
  int _todayWidgetEntry = 0;

  // 原生悬浮语音面板「打开语音设置」交给外壳的一次性路由值：
  // 与 Kotlin 侧 AssistantOverlayVoiceActivity.ROUTE_VOICE_SETTINGS 同一语义。
  static const _voiceSettingsRoute = 'voiceSettings';
  // 现有助手设置页里的「语音输入」行。设置页没有分段/锚点入参，
  // 因此只按它自己的分组滚动定位，不新建页面、不复制设置 UI。
  static const _voiceSettingsRowKey = Key('assistant-speech-settings-entry');
  bool _openingVoiceSettings = false;

  @override
  void initState() {
    super.initState();
    _overlayChannel.setMethodCallHandler(_handleOverlayCall);
    _listenNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_consumePendingAssistantOpen());
        unawaited(_consumeAssistantMission());
        unawaited(_consumeAssistantRecord());
        unawaited(_consumeWidgetOpen());
        unawaited(_consumeAssistantRoute());
      }
    });
  }

  Future<void> _handleOverlayCall(MethodCall call) async {
    if (call.method == 'pendingOpen') await _consumePendingAssistantOpen();
    if (call.method == 'pendingMission') await _consumeAssistantMission();
    if (call.method == 'pendingRecord') await _consumeAssistantRecord();
    if (call.method == 'pendingWidgetOpen') await _consumeWidgetOpen();
    if (call.method == 'pendingAssistantRoute') await _consumeAssistantRoute();
  }

  Future<void> _consumePendingAssistantOpen() async {
    try {
      final pending = await _overlayChannel.invokeMethod<bool>(
        'consumePendingOpen',
      );
      if (pending == true && mounted) {
        final id = await _overlayChannel.invokeMethod<String>(
          'consumeAssistantSession',
        );
        if (!mounted) return;
        if (id != null && widget.assistant != null) {
          await widget.assistant!.initialize();
          if (!mounted) return;
          await widget.assistant!.openConversation(id);
        }
        if (!mounted) return;
        final entry = _assistantEntry.currentState;
        if (entry != null && ModalRoute.of(context)?.isCurrent == true) {
          await entry.openGlobalAssistant();
        } else {
          await widget.assistant?.prepareExternalEntry();
          if (mounted) await showAssistantConversation(context);
        }
      }
    } on PlatformException {
      // 桌面和 Web 没有 Android 悬浮入口。
    } on MissingPluginException {
      // 桌面和 Web 没有 Android 悬浮入口。
    } on StateError {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前会话正在运行，或提醒已删除')));
      }
    }
  }

  Future<void> _consumeAssistantMission() async {
    try {
      final id = await _overlayChannel.invokeMethod<String>(
        'consumePendingMission',
      );
      if (!mounted || id == null) return;
      await _openExternalMission(id);
    } on MissingPluginException {
      // 当前平台没有 Android 悬浮入口。
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开任务，请从日程重新查看')));
      }
    }
  }

  Future<void> _consumeWidgetOpen() async {
    try {
      final entry = await _overlayChannel.invokeMapMethod<String, String?>(
        'consumeWidgetOpen',
      );
      if (!mounted || entry == null) return;
      final id = entry['missionId'];
      if (id != null) {
        await _openExternalMission(id);
      } else if (await _detailPane.clear() && mounted) {
        _assistantEntry.currentState?.resetContext();
        setState(() {
          _selectedIndex = 0;
          _todayWidgetEntry++;
        });
      }
    } on MissingPluginException {
      // 非 Android 平台没有小组件入口。
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开桌面任务，请从日程重新查看')));
      }
    }
  }

  Future<void> _consumeAssistantRecord() async {
    final bridge = widget.assistantWorkspace;
    if (bridge == null) return;
    try {
      final id = await _overlayChannel.invokeMethod<String>(
        'consumeAssistantRecord',
      );
      if (!mounted || id == null) return;
      final image = bridge.takeRecord(id);
      if (image == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('这张截图已失效')));
        return;
      }
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => RecordEditor(
            initialImage: image.bytes,
            missionId: image.missionId,
          ),
        ),
      );
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开记录草稿')));
      }
    } on MissingPluginException {
      // 当前设备没有悬浮记录入口。
    }
  }

  /// 一次性消费原生「打开语音设置」路由（冷启动拉取与热启动推送共用）。
  ///
  /// 没有待消费路由时直接结束，这是常态而不是失败；只有真正拿到路由却
  /// 打不开（未知路由、未装配助手、导航异常）才提示，并保留当前页面。
  Future<void> _consumeAssistantRoute() async {
    try {
      final entry = await _overlayChannel.invokeMapMethod<String, String?>(
        'consumeAssistantRoute',
      );
      final route = entry?['route'];
      if (!mounted || route == null) return;
      if (route != _voiceSettingsRoute) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法识别该助手入口，请从助手设置进入')));
        return;
      }
      await _openAssistantVoiceSettings();
    } on MissingPluginException {
      // 桌面和 Web 没有 Android 悬浮语音入口。
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开语音设置，请从助手设置进入')));
      }
    }
  }

  /// 在完整路由上打开现有助手设置页，并定位到它的「语音输入」分组。
  ///
  /// 用根 Navigator 而不是右栏，任意页面（含助手会话不可见时）都能打开，
  /// 返回后仍停在原页面与原右栏栈；不新建设置页、不新建路由体系。
  Future<void> _openAssistantVoiceSettings() async {
    final controller = widget.assistant;
    if (controller == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未装配助手，无法打开语音设置')));
      return;
    }
    if (_openingVoiceSettings) return;
    _openingVoiceSettings = true;
    final pageKey = GlobalKey();
    try {
      final opened = Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              AssistantSettingsPage(key: pageKey, controller: controller),
        ),
      );
      // 设置页先读本机配置再建表单，等它挂载后按首帧位置滚动一次。
      unawaited(_revealVoiceSettingsRow(pageKey));
      await opened;
    } catch (error, stack) {
      debugPrint('打开语音设置失败：$error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开语音设置，请从助手设置进入')));
      }
    } finally {
      _openingVoiceSettings = false;
    }
  }

  /// 把现有设置页里的「语音输入」行滚入视野。
  ///
  /// 行要等设置加载完成才建出来，所以这里有限次等待；超时就停在设置页顶部，
  /// 用户仍可自行滚动。用户已返回时立即结束，不在后台继续操作。
  Future<void> _revealVoiceSettingsRow(GlobalKey pageKey) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      final page = pageKey.currentContext;
      if (page == null) return;
      final row = _findElementByKey(page as Element, _voiceSettingsRowKey);
      if (row == null) continue;
      await Scrollable.ensureVisible(
        row,
        alignment: 0.12,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      return;
    }
  }

  /// 在已挂载的子树上按键找元素：只用于设置页内部的滚动定位。
  static Element? _findElementByKey(Element root, Key key) {
    if (root.widget.key == key) return root;
    Element? found;
    root.visitChildren((child) {
      found ??= _findElementByKey(child, key);
    });
    return found;
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifications != widget.notifications) {
      unawaited(_uiActions?.cancel());
      _listenNotifications();
    }
  }

  void _listenNotifications() {
    _uiActions = widget.notifications?.uiActions.listen((_) {
      _drainNotificationUi();
    });
    // 冷启动意图等宿主 Navigator 挂载后再交付，不依赖450ms启动页的快慢。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _drainNotificationUi();
    });
  }

  void _drainNotificationUi() {
    final actions = widget.notifications?.takePendingUiActions() ?? [];
    for (final action in actions) {
      unawaited(_handleNotificationUi(action));
    }
  }

  /// 通知动作的 UI 接手（§7.2）：停止后打开 END 确认；旧按钮只提示刷新。
  Future<void> _handleNotificationUi(NotificationUiAction action) async {
    if (!mounted) return;
    try {
      if (action.result == NotificationActionResult.openEndConfirm ||
          action.result == NotificationActionResult.openMission) {
        await _openExternalMission(
          action.missionId,
          openEndConfirm:
              action.result == NotificationActionResult.openEndConfirm,
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action.message ?? '任务已有新进展，请刷新后重试')),
      );
    } catch (error, stack) {
      debugPrint('通知动作处理失败：$error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('任务读取失败，请刷新后重试')));
      }
    }
  }

  // 路由变更方法
  Future<void> _selectPage(int index) async {
    if (_selectingPage || index == _selectedIndex) return;
    _selectingPage = true;
    try {
      // 切主导航先处理右栏及草稿守卫，否则新页面只会在旧面板下面切换。
      if (!await _detailPane.clear() || !mounted) return;
      _assistantEntry.currentState?.resetContext();
      setState(() {
        _selectedIndex = index;
        _visitedPages.add(index);
      });
    } finally {
      _selectingPage = false;
    }
  }

  Future<void> _openExternalMission(
    String id, {
    bool openEndConfirm = false,
  }) async {
    final detail = await widget.missionService.findDetail(missionId: id);
    if (!mounted) return;
    if (detail == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('任务已不存在')));
      return;
    }
    final executing = const {
      MissionPhase.running,
      MissionPhase.paused,
      MissionPhase.reportPending,
    }.contains(detail.phase);
    await _detailPane.open<void>(
      DetailPaneEntry(
        executing ? '任务执行' : '任务详情',
        (_) => executing
            ? MissionExecutionPage(
                detail: detail,
                service: widget.missionService,
                clock: widget.clock,
                openEndConfirm: openEndConfirm,
              )
            : MissionDetailPage(
                missionId: id,
                missionService: widget.missionService,
              ),
      ),
      replace: DetailPaneReplace.none,
    );
  }

  @override
  void dispose() {
    _overlayChannel.setMethodCallHandler(null);
    unawaited(_uiActions?.cancel());
    _detailPane.dispose();
    super.dispose();
  }

  // 主要渲染内容
  @override
  Widget build(BuildContext context) {
    // 通过 widget 读取 App 传入的服务引用；重建页面时不重新创建服务。
    final pages = <Widget>[
      if (_visitedPages.contains(0))
        TodayPage(
          key: ValueKey(_todayWidgetEntry),
          missionService: widget.missionService,
          goalService: widget.goalService,
          clock: widget.clock,
          active: _selectedIndex == 0,
        )
      else
        const SizedBox.shrink(key: ValueKey('unvisited-page-0')),
      if (_visitedPages.contains(1))
        GoalsPage(
          service: widget.goalService,
          missionService: widget.missionService,
          active: _selectedIndex == 1,
        )
      else
        const SizedBox.shrink(key: ValueKey('unvisited-page-1')),
      if (_visitedPages.contains(2))
        MissionHistoryPage(
          service: widget.missionService,
          active: _selectedIndex == 2,
        )
      else
        const SizedBox.shrink(key: ValueKey('unvisited-page-2')),
      if (_visitedPages.contains(3))
        MePage(
          missions: widget.missionService,
          goals: widget.goalService,
          device: widget.device,
          backup: widget.backupService,
          notifications: widget.notifications,
          active: _selectedIndex == 3,
        )
      else
        const SizedBox.shrink(key: ValueKey('unvisited-page-3')),
    ];
    final pageBody = KeyedSubtree(
      key: _pageStackKey,
      child: AppContentTransition(
        identity: _selectedIndex,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            for (var index = 0; index < pages.length; index++)
              TickerMode(
                enabled: index == _selectedIndex,
                child: pages[index],
              ), // 只在选中时才启动动画
          ],
        ),
      ),
    );
    final body = AssistantEntryScope(
      openNode: (id) => _assistantEntry.currentState?.openNodeMenu(id),
      child: pageBody,
    );
    final compact = AppLayout.windowClassOf(context) == WindowClass.compact;
    // 右栏栈变化（打开/返回）会改变接管状态，这里需要跟着重建。
    return DetailPaneScope(
      controller: _detailPane,
      child: ListenableBuilder(
        listenable: _detailPane,
        builder: (context, _) {
          final mode = _detailPane.assistantPaneMode;
          final chatAttached = _detailPane.isAssistantConversationActive;
          // 显式「仅工作区」：宽屏折成贴边细门轨，窄窗也保持工作区，
          // 聊天留在右栏栈里等入口恢复（不 pop、不重建）。
          final workspaceOnly =
              _detailPane.hasContent &&
              chatAttached &&
              mode == AssistantPaneMode.workspaceExpanded;
          // 让位判断在构建外壳前就要有结论：页面正文的 TickerMode 依赖它。
          // 侧栏只在隐藏页面上暂停动画，外壳操作（助手入口菜单收尾）继续走完。
          final windowWidth = MediaQuery.sizeOf(context).width;
          final shellRailWidth = compact
              ? 0.0
              : AppLayout.railWidthForWindow(windowWidth);
          final shellContentWidth = math.max(0.0, windowWidth - shellRailWidth);
          final shellAssistantRoom = AppLayout.canSplitAssistantPane(
            shellContentWidth,
          );
          final shellSplitAssistant =
              _detailPane.hasContent && chatAttached && shellAssistantRoom;
          final shellNormalSplit =
              _detailPane.hasContent &&
              !chatAttached &&
              AppLayout.canSplitPane(shellContentWidth);
          final shellPaused =
              _detailPane.hasContent &&
              !workspaceOnly &&
              !shellNormalSplit &&
              (!shellSplitAssistant ||
                  mode == AssistantPaneMode.assistantExpanded);
          final pageBodyPaused = TickerMode(enabled: !shellPaused, child: body);
          // 手机形态：底部胶囊导航（现行稿）；宽屏形态在下方改为左侧导航栏。
          final shell = compact
              ? Scaffold(
                  key: const Key('nav-capsule'),
                  body: pageBodyPaused,
                  // 右栏全屏接管时底部导航跟着下场：子页不复制底部导航。
                  // 聊天被折叠隐藏时导航与当前任务栏仍属于可见工作区。
                  bottomNavigationBar: _detailPane.hasContent && !workspaceOnly
                      ? null
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ActiveMissionsBar(
                              service: widget.missionService,
                              clock: widget.clock,
                            ),
                            _buildNavigationBar(),
                          ],
                        ),
                )
              : Scaffold(
                  key: const Key('nav-side-rail'),
                  body: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSideRail(),
                      const VerticalDivider(
                        width: AppLayout.strokeThin,
                        thickness: AppLayout.strokeThin,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(child: pageBodyPaused),
                            ActiveMissionsBar(
                              service: widget.missionService,
                              clock: widget.clock,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // 侧栏占位与助手顶栏共用同一换算：常规 89、扩展 193（含 1dp 边线）。
              final railWidth = compact
                  ? 0.0
                  : AppLayout.railWidthForWindow(width);
              final contentWidth = math.max(0.0, width - railWidth);
              // 助手专用门槛按「工作区 480 + 门 24 + 助手 360」判定；
              // 普通详情继续用 16dp 栏间距的 856 门槛。
              final assistantRoom = AppLayout.canSplitAssistantPane(
                contentWidth,
              );
              final splitAssistant =
                  _detailPane.hasContent && chatAttached && assistantRoom;
              final normalSplit =
                  _detailPane.hasContent &&
                  !chatAttached &&
                  AppLayout.canSplitPane(contentWidth);
              final assistantOnly =
                  splitAssistant && mode == AssistantPaneMode.assistantExpanded;

              AssistantSplitGeometry? split;
              double paneWidth;
              double workspaceWidth;
              if (splitAssistant) {
                split = _detailPane.resolveAssistantGeometry(
                  windowWidth: width,
                  railWidth: railWidth,
                );
                workspaceWidth = split.workspaceWidth;
                paneWidth = split.assistantWidth;
              } else if (normalSplit) {
                final availableWidth = contentWidth - AppLayout.paneGap;
                paneWidth = (availableWidth - AppLayout.paneLeftMin).clamp(
                  AppLayout.paneRightMin,
                  _detailPane.activeMaxWidth,
                );
                workspaceWidth = width - paneWidth - AppLayout.paneGap;
              } else if (workspaceOnly) {
                // 窄窗显式「仅工作区」：聊天子树按有效栏宽隐藏布局，
                // 恢复时仍是同一个会话、同一份草稿。
                paneWidth = _detailPane.assistantSplitWidthFor(contentWidth);
                workspaceWidth = width;
              } else if (_detailPane.hasContent) {
                // 窄窗接管：同一聊天/详情路由铺满窗口，草稿与返回链不迁移。
                paneWidth = width;
                workspaceWidth = width;
              } else {
                paneWidth = 0;
                workspaceWidth = width;
              }
              // 工作区只在右栏真正铺满窗口时让位；并排/显式保留时始终可见。
              final workspaceHidden =
                  _detailPane.hasContent &&
                  !workspaceOnly &&
                  !normalSplit &&
                  (!splitAssistant || assistantOnly);
              final paneHidden = workspaceOnly;
              // 门只在助手会话是实际可见栈顶时出现；被历史/设置盖住时只留 24dp 缝隙。
              final showDoor =
                  split != null &&
                  _detailPane.isAssistantConversationVisibleTop;
              // 键盘只在这里缩一次：两栏、橱窗门和右栏一同止于可用内容底部，
              // 子树自己的 Scaffold 不再重复扣减，避免门铺到键盘下面。
              final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
              return _AssistantSplitLayoutGuard(
                controller: _detailPane,
                availableWidth: split?.availableWidth ?? 0,
                assistantRoom: assistantRoom,
                visibleTop: _detailPane.isAssistantConversationVisibleTop,
                child: MediaQuery.removeViewInsets(
                  context: context,
                  removeBottom: true,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: ColoredBox(
                      key: const Key('workspace-background'),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PositionedDirectional(
                            start: 0,
                            top: 0,
                            bottom: 0,
                            width: workspaceWidth,
                            child: Offstage(
                              offstage: workspaceHidden,
                              child: ExcludeFocus(
                                excluding: workspaceHidden,
                                // 页面正文的 TickerMode 在 shell 内单独关闭；
                                // 外壳（侧栏助手入口）保留一次动画收尾的机会。
                                child: shell,
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            end: 0,
                            top: 0,
                            bottom: 0,
                            width: paneWidth,
                            child: Offstage(
                              offstage: paneHidden,
                              child: ExcludeFocus(
                                excluding: paneHidden,
                                child: TickerMode(
                                  enabled: !paneHidden,
                                  child: DetailPaneHost(
                                    controller: _detailPane,
                                    active: !paneHidden,
                                    restoreSplitOnBack:
                                        splitAssistant &&
                                        mode != AssistantPaneMode.split,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (showDoor)
                            PositionedDirectional(
                              start: split.doorAtEnd ? null : split.doorOffset,
                              end: split.doorAtEnd ? split.doorOffset : null,
                              top: 0,
                              bottom: 0,
                              width: AppLayout.splitDoorWidth,
                              // 从内容安全区顶接到底，键盘出现时止于可用内容底部。
                              child: SafeArea(
                                left: false,
                                right: false,
                                child: AssistantSplitDoor(
                                  controller: _detailPane,
                                  availableWidth: split.availableWidth,
                                  assistantWidth: split.dragStartWidth,
                                  textDirection: Directionality.of(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 平板保留紧凑侧栏，足够宽时才把图标与文字并排。
  // 语义与底部胶囊完全一致（标签/按钮/选中态/Tooltip），读屏行为不分平台。
  static const _railDestinations =
      <({String label, IconData icon, IconData selected})>[
        (label: '今天', icon: Icons.home_outlined, selected: Icons.home_rounded),
        (
          label: '目标',
          icon: Icons.track_changes_outlined,
          selected: Icons.track_changes,
        ),
        (label: '历史', icon: Icons.schedule_outlined, selected: Icons.schedule),
        (label: '我的', icon: Icons.person_outline, selected: Icons.person),
      ];

  /// 四个目的地的稳定 Key：选中底色按真实项边界移动，不再按 1/4 估算。
  final _railItemKeys = List.generate(4, (_) => GlobalKey());

  /// 宽 rail 的标签槽：四项共用同一槽宽，按最宽标签（选中字重）实测。
  /// 容器放不下时返回 vertical，让图文改为上下、文字可两行。
  ({double labelSlot, bool vertical}) _railLabelGeometry(
    BuildContext context,
    double itemWidth,
  ) {
    final available =
        itemWidth -
        AppLayout.spaceMd * 2 -
        AppLayout.iconLg -
        AppLayout.spaceSm;
    final base = Theme.of(context).textTheme.labelMedium ?? const TextStyle();
    final style = base.copyWith(fontWeight: FontWeight.w600);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final destination in _railDestinations) {
      final painter = TextPainter(
        text: TextSpan(text: destination.label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    if (widest > available) return (labelSlot: 0, vertical: true);
    return (labelSlot: widest.ceilToDouble(), vertical: false);
  }

  Widget _buildSideRail() {
    final expanded = AppLayout.useExtendedRail(context);
    final itemWidth = expanded ? 176.0 : 72.0;
    final label = expanded
        ? _railLabelGeometry(context, itemWidth)
        : (labelSlot: 0.0, vertical: true);
    return SizedBox(
      key: const Key('navigation-rail-width'),
      width: expanded ? 192 : 88,
      child: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border(right: BorderSide(color: AppColors.hairline)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppLayout.spaceLg,
              horizontal: AppLayout.spaceSm,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppLayout.spaceSm,
                            bottom: AppLayout.spaceXxl,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: Align(
                              // 品牌字标随侧栏中线对齐，不随宽度变化偏左。
                              alignment: Alignment.center,
                              child: expanded
                                  ? Text(
                                      'MissionBook',
                                      key: const Key('navigation-brand'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    )
                                  : const Icon(Icons.book_outlined, size: 28),
                            ),
                          ),
                        ),
                        _RailSelectionIndicator(
                          selectedIndex: _selectedIndex,
                          itemKeys: _railItemKeys,
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < _railDestinations.length;
                                index++
                              )
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppLayout.spaceXs,
                                  ),
                                  child: SizedBox(
                                    key: _railItemKeys[index],
                                    width: itemWidth,
                                    child: _navigationItem(
                                      index,
                                      _railDestinations[index].label,
                                      _railDestinations[index].icon,
                                      _railDestinations[index].selected,
                                      extended: expanded,
                                      vertical: label.vertical,
                                      labelSlotWidth: label.labelSlot,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (widget.assistant != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppLayout.spaceMd,
                              horizontal: AppLayout.spaceLg,
                            ),
                            child: Align(
                              // 展开与收起都以导航栏中线对齐，圆形入口不随宽度变化偏左。
                              alignment: Alignment.center,
                              child: AssistantLauncher(
                                key: _assistantEntry,
                                navigationRailWidth: expanded ? 192 : 88,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 导航仍由 _selectedIndex 控制；这里只将标准横条改成当前稿的白色胶囊。
  Widget _buildNavigationBar() {
    final margin = AppLayout.horizontalPadding(context);
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        margin,
        AppLayout.spaceSm,
        margin,
        AppLayout.spaceMd,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppLayout.radiusPill),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  blurRadius: AppLayout.shadowBlur,
                  offset: const Offset(0, AppLayout.shadowOffsetY),
                ),
              ],
            ),
            child: Material(
              color: AppColors.card,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(AppLayout.spaceXs),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final assistantWidth = widget.assistant == null
                        ? 0.0
                        : 56 + AppLayout.spaceXs * 2;
                    final itemWidth =
                        (constraints.maxWidth - assistantWidth) / 4;
                    return Stack(
                      children: [
                        AnimatedPositionedDirectional(
                          key: ValueKey(
                            MediaQuery.disableAnimationsOf(context),
                          ),
                          duration: AppMotion.resolve(
                            context,
                            AppMotion.standard,
                          ),
                          curve: AppMotion.curve,
                          start:
                              itemWidth * _selectedIndex +
                              (_selectedIndex >= 2 ? assistantWidth : 0),
                          top: 0,
                          bottom: 0,
                          width: itemWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppLayout.spaceMd,
                            ),
                            child: _navigationSelection(),
                          ),
                        ),
                        Row(
                          children: [
                            _navigationItem(
                              0,
                              '今天',
                              Icons.home_outlined,
                              Icons.home_rounded,
                              inCapsule: true,
                            ),
                            _navigationItem(
                              1,
                              '目标',
                              Icons.track_changes_outlined,
                              Icons.track_changes,
                              inCapsule: true,
                            ),
                            if (widget.assistant != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppLayout.spaceXs,
                                ),
                                child: AssistantLauncher(key: _assistantEntry),
                              ),
                            _navigationItem(
                              2,
                              '历史',
                              Icons.schedule_outlined,
                              Icons.schedule,
                              inCapsule: true,
                            ),
                            _navigationItem(
                              3,
                              '我的',
                              Icons.person_outline,
                              Icons.person,
                              inCapsule: true,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navigationSelection() => _railSelectionSurface();

  // 四个目的地共用同一排版与语义外壳；点击仍交给 _selectPage 切换 IndexedStack。
  // inCapsule：胶囊导航里横向铺满一格；extended：侧栏加宽条（图标+文字并排）。
  Widget _navigationItem(
    int index,
    String label,
    IconData icon,
    IconData selectedIcon, {
    bool inCapsule = false,
    bool extended = false,
    bool vertical = false,
    double labelSlotWidth = 0,
  }) {
    final selected = index == _selectedIndex;
    final foreground = selected ? AppColors.primary : AppColors.textSecondary;

    // 触屏和读屏都调用同一个入口，使用当前导航项的 index 切换页面。
    void selectPage() {
      _selectPage(index);
    }

    final duration = AppMotion.resolve(context, AppMotion.quick);
    final iconWidget = SizedBox(
      key: ValueKey('navigation-icon-$index'),
      width: AppLayout.iconLg,
      height: AppLayout.iconLg,
      child: AnimatedScale(
        key: ValueKey(duration),
        scale: selected ? 1.06 : 1,
        duration: duration,
        curve: AppMotion.curve,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: foreground),
          duration: duration,
          curve: AppMotion.curve,
          builder: (_, color, _) => Icon(
            selected ? selectedIcon : icon,
            size: AppLayout.iconLg,
            color: color,
          ),
        ),
      ),
    );
    final labelWidget = AnimatedDefaultTextStyle(
      key: ValueKey(duration),
      duration: duration,
      curve: AppMotion.curve,
      style:
          ((extended
                      ? Theme.of(context).textTheme.labelMedium
                      : Theme.of(context).textTheme.labelSmall) ??
                  const TextStyle())
              .copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: foreground,
              ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        softWrap: true,
      ),
    );
    // 侧栏项：图文组在整项中线居中；宽 rail 的标签在自身等宽槽里居中。
    final content = inCapsule
        ? (extended
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    iconWidget,
                    const SizedBox(width: AppLayout.spaceSm),
                    labelWidget,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconWidget,
                    const SizedBox(height: 2),
                    labelWidget,
                  ],
                ))
        : Center(
            child: extended && !vertical
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconWidget,
                      const SizedBox(width: AppLayout.spaceSm),
                      SizedBox(
                        width: labelSlotWidth,
                        child: Align(
                          alignment: Alignment.center,
                          child: labelWidget,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconWidget,
                      const SizedBox(height: 2),
                      labelWidget,
                    ],
                  ),
          );
    final button = Tooltip(
      message: label,
      child: AppInteractiveSurface(
        semanticsLabel: label,
        selected: selected,
        // 选中底色由下方移动指示层绘制；交互表面只负责悬停和聚焦反馈。
        selectedColor: Colors.transparent,
        baseColor: Colors.transparent,
        onTap: selectPage,
        borderRadius: AppLayout.radiusMd,
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.spaceMd,
          vertical: AppLayout.spaceSm,
        ),
        child: content,
      ),
    );
    return inCapsule ? Expanded(child: button) : button;
  }
}

/// 侧栏选中底色：测量真实目的项的矩形，按该项边界移动。
///
/// 四项高度会随系统字号变化，因此不再用 1/4 估算；短窗口滚动时，
/// 指示层与列表在同一滚动容器内一起移动。
class _RailSelectionIndicator extends StatefulWidget {
  const _RailSelectionIndicator({
    required this.selectedIndex,
    required this.itemKeys,
    required this.child,
  });

  final int selectedIndex;
  final List<GlobalKey> itemKeys;
  final Widget child;

  @override
  State<_RailSelectionIndicator> createState() =>
      _RailSelectionIndicatorState();
}

class _RailSelectionIndicatorState extends State<_RailSelectionIndicator> {
  Rect? _selectionRect;
  bool _measureScheduled = false;

  @override
  void didUpdateWidget(covariant _RailSelectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 目的项换了：用上一帧布局立即瞄准新项，动画从本次构建就开始，
    // 不会先停在旧位置一帧；布局本身变化时再由帧末测量校正。
    final rect = _measureNow();
    if (rect != null) _selectionRect = rect;
    if (oldWidget.selectedIndex != widget.selectedIndex) _scheduleMeasure();
  }

  /// 读取选中项当前渲染盒相对指示层的矩形；尚未布局时返回 null。
  Rect? _measureNow() {
    final box =
        widget.itemKeys[widget.selectedIndex].currentContext?.findRenderObject()
            as RenderBox?;
    final self = context.findRenderObject() as RenderBox?;
    if (box == null || self == null || !box.attached || !self.attached) {
      return null;
    }
    if (!box.hasSize || !self.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: self) & box.size;
  }

  /// 布局完成后测量选中项；只有矩形真的变化才重建，避免逐帧 setState。
  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final rect = _measureNow();
      if (rect == null || rect == _selectionRect) return;
      setState(() => _selectionRect = rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    final duration = AppMotion.resolve(context, AppMotion.standard);
    final rect = _selectionRect;
    return Stack(
      children: [
        if (rect != null)
          AnimatedPositioned(
            // 策略变化时重置纯视觉指示器，进行中的动画直接到位。
            key: ValueKey(duration),
            duration: duration,
            curve: AppMotion.curve,
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: IgnorePointer(child: _railSelectionSurface()),
          ),
        widget.child,
      ],
    );
  }
}

/// 侧栏/胶囊共用的选中表面（纯视觉；交互由 AppInteractiveSurface 承担）。
Widget _railSelectionSurface() => DecoratedBox(
  key: const Key('navigation-selection-surface'),
  decoration: ShapeDecoration(
    color: AppColors.primarySoft,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppLayout.radiusMd),
    ),
  ),
  child: const SizedBox.expand(),
);

/// 分屏布局守卫：窗口宽度或实际可见栈顶变化时丢弃拖动预览，保留提交比例。
class _AssistantSplitLayoutGuard extends StatefulWidget {
  const _AssistantSplitLayoutGuard({
    required this.controller,
    required this.availableWidth,
    required this.assistantRoom,
    required this.visibleTop,
    required this.child,
  });

  final DetailPaneController controller;
  final double availableWidth;
  final bool assistantRoom;
  final bool visibleTop;
  final Widget child;

  @override
  State<_AssistantSplitLayoutGuard> createState() =>
      _AssistantSplitLayoutGuardState();
}

class _AssistantSplitLayoutGuardState
    extends State<_AssistantSplitLayoutGuard> {
  @override
  void didUpdateWidget(covariant _AssistantSplitLayoutGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableWidth == widget.availableWidth &&
        oldWidget.assistantRoom == widget.assistantRoom &&
        oldWidget.visibleTop == widget.visibleTop) {
      return;
    }
    // 只在帧末丢弃预览：不在 build 里写控制器，也不把旧几何带进下一帧。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.cancelAssistantResize();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
