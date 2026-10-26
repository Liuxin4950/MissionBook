import 'package:flutter/material.dart';
import 'dart:async';
import 'presentation/today/today_page.dart';
import 'application/missions/mission_service.dart';
import 'application/notifications/app_notification_service.dart';
import 'core/theme/app_layout.dart';
import 'core/theme/colors.dart';
import 'presentation/missions/execution/mission_execution_page.dart';
import 'presentation/missions/detail/mission_detail_page.dart';
import 'domain/entities/mission_phase.dart';
import 'presentation/missions/shared/active_missions_bar.dart';
import 'presentation/missions/history/mission_history_page.dart';
import 'application/goals/goal_service.dart';
import 'presentation/goals/list/goals_page.dart';
import 'application/backup/backup_service.dart';
import 'application/settings/app_device.dart';
import 'presentation/me/me_page.dart';
import 'presentation/widgets/detail_pane.dart';

/// 管理四个顶层导航入口，并保留各页状态、转交共享业务对象。
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.missionService,
    required this.goalService,
    required this.backupService,
    required this.device,
    this.notifications,
    this.clock = DateTime.now,
  });
  // App 传入共享任务服务，本层转交给今天、历史及当前任务栏。
  final MissionService missionService;
  final GoalService goalService; // 由 App 装配并转交给目标页面。
  final BackupExporter backupService;
  final AppDevice device;

  // 通知动作的 UI 部分由外壳承接：打开 END 确认、旧按钮提示刷新。
  final AppNotificationService? notifications;

  /// 今天页使用的日期时钟；测试传入固定时刻，避免随运行日期改变查询。
  final DateTime Function() clock;

  @override
  State<AppShell> createState() {
    return _AppShellState();
  }
}

class _AppShellState extends State<AppShell> {
  // 索引
  int _selectedIndex = 0;

  // 右栏导航控制器：外壳常驻持有。宽屏并排、窄屏全屏接管都是同一个栈，
  // 窗口缩放只换显示位置，不重建页面（草稿、返回链都留在栈里）。
  final _detailPane = DetailPaneController();
  final _pageStackKey = GlobalKey();
  StreamSubscription<NotificationUiAction>? _uiActions;
  bool _selectingPage = false;

  @override
  void initState() {
    super.initState();
    _listenNotifications();
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
    if (action.result == NotificationActionResult.openEndConfirm ||
        action.result == NotificationActionResult.openMission) {
      final detail = await widget.missionService.findDetail(
        missionId: action.missionId,
      );
      if (detail == null || !mounted) return;
      final executing =
          detail.phase == MissionPhase.running ||
          detail.phase == MissionPhase.paused;
      await _detailPane.open<void>(
        DetailPaneEntry(
          executing ? '任务执行' : '任务详情',
          (_) => executing
              ? MissionExecutionPage(
                  detail: detail,
                  service: widget.missionService,
                  clock: widget.clock,
                  openEndConfirm:
                      action.result == NotificationActionResult.openEndConfirm,
                )
              : MissionDetailPage(
                  missionId: detail.mission.id,
                  missionService: widget.missionService,
                ),
        ),
        // 通知进入任务时保留下面尚未保存的页面，返回后继续原草稿。
        replace: DetailPaneReplace.none,
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(action.message ?? '任务已有新进展，请刷新后重试')));
  }

  // 路由变更方法
  Future<void> _selectPage(int index) async {
    if (_selectingPage) return;
    _selectingPage = true;
    try {
      // 切主导航先处理右栏及草稿守卫，否则新页面只会在旧面板下面切换。
      if (!await _detailPane.clear() || !mounted) return;
      setState(() => _selectedIndex = index);
    } finally {
      _selectingPage = false;
    }
  }

  @override
  void dispose() {
    unawaited(_uiActions?.cancel());
    _detailPane.dispose();
    super.dispose();
  }

  // 主要渲染内容
  @override
  Widget build(BuildContext context) {
    // 通过 widget 读取 App 传入的服务引用；重建页面时不重新创建服务。
    final pages = <Widget>[
      TodayPage(
        missionService: widget.missionService,
        goalService: widget.goalService,
        clock: widget.clock,
      ),
      GoalsPage(
        service: widget.goalService,
        missionService: widget.missionService,
      ),
      MissionHistoryPage(service: widget.missionService),
      MePage(
        device: widget.device,
        backup: widget.backupService,
        notifications: widget.notifications,
      ),
    ];
    final body = KeyedSubtree(
      key: _pageStackKey,
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
    );
    final compact = AppLayout.windowClassOf(context) == WindowClass.compact;
    // 右栏栈变化（打开/返回）会改变接管状态，这里需要跟着重建。
    return DetailPaneScope(
      controller: _detailPane,
      child: ListenableBuilder(
        listenable: _detailPane,
        builder: (context, _) {
          // 手机形态：底部胶囊导航（现行稿）；宽屏形态在下方改为左侧导航栏。
          final shell = compact
              ? Scaffold(
                  key: const Key('nav-capsule'),
                  body: body,
                  // 右栏全屏接管时底部导航跟着下场：子页不复制底部导航。
                  bottomNavigationBar: _detailPane.hasContent
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
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(child: body),
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
              // 双栏判定用内容区宽度（§2.0）：侧栏占宽后凑不齐左右最小宽就单列。
              final expanded =
                  AppLayout.windowClassOf(context) == WindowClass.expanded;
              final railWidth = compact ? 0.0 : (expanded ? 193.0 : 89.0);
              final contentWidth = constraints.maxWidth - railWidth;
              final split =
                  AppLayout.canSplitPane(contentWidth) &&
                  _detailPane.hasContent;
              final rightWidth = split
                  ? (contentWidth - AppLayout.paneGap - AppLayout.paneLeftMin)
                        .clamp(
                          AppLayout.paneRightMin,
                          AppLayout.detailPaneMaxWidth,
                        )
                  : constraints.maxWidth;
              final takeover = _detailPane.hasContent && !split;
              // 两个载体始终保持同一树位置；缩放只改尺寸和可见性。
              return ColoredBox(
                key: const Key('workspace-background'),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: split
                          ? constraints.maxWidth -
                                rightWidth -
                                AppLayout.paneGap
                          : constraints.maxWidth,
                      child: Offstage(
                        offstage: takeover,
                        child: TickerMode(enabled: !takeover, child: shell),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: rightWidth,
                      child: DetailPaneHost(controller: _detailPane),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 左侧导航栏：medium 图标在上、expanded 图标与文字并排加宽。
  // 语义与底部胶囊完全一致（标签/按钮/选中态/Tooltip），读屏行为不分平台。
  Widget _buildSideRail() {
    final expanded = AppLayout.windowClassOf(context) == WindowClass.expanded;
    Widget item(
      int index,
      String label,
      IconData icon,
      IconData selectedIcon,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: expanded ? 176 : 72,
        child: _navigationItem(
          index,
          label,
          icon,
          selectedIcon,
          extended: expanded,
        ),
      ),
    );
    return SizedBox(
      width: expanded ? 192 : 88,
      child: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border(right: BorderSide(color: AppColors.hairline)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                    child: expanded
                        ? Text(
                            'MissionBook',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          )
                        : const Icon(Icons.book_outlined, size: 28),
                  ),
                  item(0, '今天', Icons.home_outlined, Icons.home_rounded),
                  item(
                    1,
                    '目标',
                    Icons.track_changes_outlined,
                    Icons.track_changes,
                  ),
                  item(2, '历史', Icons.schedule_outlined, Icons.schedule),
                  item(3, '我的', Icons.person_outline, Icons.person),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 导航仍由 _selectedIndex 控制；这里只将标准横条改成当前稿的白色胶囊。
  Widget _buildNavigationBar() {
    final margin = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 24.0;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(margin, 8, margin, 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 792),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: AppColors.card,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 四个目的地共用同一排版与语义外壳；点击仍交给 _selectPage 切换 IndexedStack。
  // inCapsule：胶囊导航里横向铺满一格；extended：侧栏加宽条（图标+文字并排）。
  Widget _navigationItem(
    int index,
    String label,
    IconData icon,
    IconData selectedIcon, {
    bool inCapsule = false,
    bool extended = false,
  }) {
    final selected = index == _selectedIndex;
    final foreground = selected
        ? (inCapsule ? AppColors.onPrimary : AppColors.primary)
        : AppColors.textSecondary;

    // 触屏和读屏都调用同一个入口，使用当前导航项的 index 切换页面。
    void selectPage() {
      _selectPage(index);
    }

    final iconWidget = Icon(
      selected ? selectedIcon : icon,
      size: 22,
      color: foreground,
    );
    final labelWidget = Text(
      label,
      style:
          (extended
                  ? Theme.of(context).textTheme.labelMedium
                  : Theme.of(context).textTheme.labelSmall)
              ?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: foreground,
              ),
    );
    final content = extended
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [iconWidget, const SizedBox(width: 8), labelWidget],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [iconWidget, const SizedBox(height: 2), labelWidget],
            ),
          );
    final button = Semantics(
      label: label,
      button: true,
      selected: selected,
      enabled: true,
      // 替换子节点语义后，需要在这里同时提供标签和实际点击动作。
      excludeSemantics: true,
      onTap: selectPage,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: selectPage,
          customBorder: const StadiumBorder(),
          child: Ink(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: selected
                  ? (inCapsule ? AppColors.primary : AppColors.primarySoft)
                  : AppColors.card,
            ),
            child: content,
          ),
        ),
      ),
    );
    return inCapsule ? Expanded(child: button) : button;
  }
}
