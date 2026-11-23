import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/colors.dart';
import 'motion_settings_scope.dart';

/// 稳定标记：只有助手会话路由允许使用可调分屏，普通详情保持既有布局。
const assistantConversationPaneIdentity = 'assistant-conversation';

/// 统一右栏页面工作区的显示状态。
enum PaneDisplayMode { split, fullScreen }

/// 助手分屏的纯几何：由窗口宽度和控制器状态算出两栏宽度与门槽位置。
///
/// 门槽在阅读末端（分屏、仅工作区）或阅读起点（仅助手）定位，
/// RTL 镜像交给外壳的 `PositionedDirectional`，这里只保留逻辑侧。
class PaneSplitGeometry {
  const PaneSplitGeometry({
    required this.contentWidth,
    required this.availableWidth,
    required this.workspaceWidth,
    required this.rightPaneWidth,
    required this.committedPaneWidth,
    required this.dragStartWidth,
    required this.doorOffset,
    required this.previewOverflow,
  });

  /// 正文宽度：已扣除导航与系统侧边。
  final double contentWidth;

  /// 可分配正文宽度：正文扣掉 24dp 门槽，比例、吸附和键盘步进都按它算。
  final double availableWidth;

  /// 工作区布局宽度（含侧栏）；仅助手时仍给出隐藏子树的合法宽度。
  final double workspaceWidth;

  /// 助手右栏布局宽度；仅工作区时给出隐藏子树的合法宽度。
  final double rightPaneWidth;

  /// 提交比例夹取后的助手栏宽：恢复分屏和读屏百分比都用它。
  final double committedPaneWidth;

  /// 拖动起点宽度：分屏按夹取栏宽，仅工作区从 0 起、仅助手从可分配宽起。
  final double dragStartWidth;

  /// 门槽距所贴边的偏移。
  final double doorOffset;

  /// 预览被可读下限夹取的超出量：负=助手已到下限，正=工作区已到下限。
  final double previewOverflow;
}

/// 纯函数几何：不读 BuildContext，测试可直接按断点和矩形断言。
PaneSplitGeometry resolvePaneSplitGeometry({
  required double windowWidth,
  required double railWidth,
  required double ratio,
  required double maxPaneWidth,
  double? previewWidth,
}) {
  final contentWidth = math.max(0.0, windowWidth - railWidth);
  final available = math.max(0.0, contentWidth - AppLayout.splitDoorWidth);
  final minAssistant = math.min(AppLayout.paneRightMin, available);
  final maxAssistant = math.max(
    minAssistant,
    math.min(maxPaneWidth, available - AppLayout.paneLeftMin),
  );
  final committed = (ratio * available)
      .clamp(minAssistant, maxAssistant)
      .toDouble();
  final dragging = previewWidth != null;
  final preview = dragging
      ? previewWidth.clamp(minAssistant, maxAssistant).toDouble()
      : null;
  final overflow = dragging ? previewWidth - preview! : 0.0;
  final slot = preview ?? committed;
  final door = AppLayout.splitDoorWidth;

  return PaneSplitGeometry(
    contentWidth: contentWidth,
    availableWidth: available,
    workspaceWidth: math.max(0.0, windowWidth - door - slot),
    rightPaneWidth: slot,
    committedPaneWidth: committed,
    dragStartWidth: slot,
    doorOffset: slot,
    previewOverflow: overflow,
  );
}

/// 右栏入口的替换语义：打开新页面时如何处理已有返回链。
enum DetailPaneReplace {
  /// 普通入栈（列表 → 详情 → 记录……逐级可返回）。
  none,

  /// 替换栈顶（详情 → 执行这类“不回头”的转场，等价 pushReplacement）。
  top,

  /// 清空返回链后入栈（切换任务/目标），逐个经过离开守卫。
  all,
}

/// 右栏里的一个页面入口：记录页面身份、构建器与可选离开守卫。
///
/// 右栏不是简单替换组件，而是自己的导航栈；每个入口都登记构建器，
/// 窗口缩放迁移与“切换前先问草稿”都靠这份登记。
class DetailPaneEntry {
  DetailPaneEntry(
    this.label,
    this.builder, {
    this.identity,
    this.maxWidth,
    this.onRequestLeave,
  });

  /// 语义标签（如“任务详情”），读屏/测试用它识别入口身份。
  final String label;

  /// 与 MaterialPageRoute 的构建器同型：右栏完全复用 push 形态的页面组件。
  final WidgetBuilder builder;

  /// 可选的稳定页面身份，用于从外部入口恢复已经打开的页面。
  final String? identity;

  /// 该入口及其子页面使用的右栏最大宽度；为空时继承已有入口。
  final double? maxWidth;

  /// 离开守卫：返回 false 表示用户放弃离开（如表单有未保存修改）。
  /// 替换/清空右栏必须先问过它；页面可经 [DetailPaneController.registerTopGuard] 注册。
  Future<bool> Function()? onRequestLeave;

  // 守卫属于创建它的路由；隐藏页面重建时不能覆盖另一个页面的守卫。
  Route<dynamic>? route;
}

/// 右栏导航控制器：持久持有嵌套 Navigator 与入口栈。
///
/// 手机形态没有并排右栏时，整条链以全屏面板呈现（外壳保持挂载）；
/// 宽屏分栏时同一个 Navigator 就是右栏。两种形态共享同一状态，
/// 窗口缩放只改变载体位置，不重建页面——这是缩放不丢草稿的关键。
class DetailPaneController extends ChangeNotifier {
  DetailPaneController();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final List<DetailPaneEntry> entries = [];

  /// 右栏导航栈的路由观察者：历史/设置等未登记入口的路由变化也要重算可见栈顶。
  late final NavigatorObserver routeObserver = _PaneRouteObserver(this);

  bool _disposed = false;
  bool _changing = false;
  PaneDisplayMode _paneDisplayMode = PaneDisplayMode.split;
  int? _fullScreenEntryDepth;
  double _paneSplitRatio = 0.5;
  double? _panePreviewWidth;

  /// 只在助手会话是栈顶时可调；普通详情不继承分屏展示模式。
  bool get isAssistantConversationActive =>
      entries.isNotEmpty &&
      entries.last.identity == assistantConversationPaneIdentity;

  /// 助手会话是否是右栏**实际可见**的栈顶：历史/设置子页盖在上面时为 false。
  ///
  /// 纯控制器测试没有 Navigator 路由，此时以入口栈顶为准。
  bool get isAssistantConversationVisibleTop {
    if (!isAssistantConversationActive) return false;
    final route = entries.last.route;
    return route == null || route.isCurrent;
  }

  PaneDisplayMode get paneDisplayMode => _paneDisplayMode;

  bool get isPaneFullScreen => _paneDisplayMode == PaneDisplayMode.fullScreen;

  /// 全屏返回时，只有退回到进入全屏时的页面深度才恢复并排。
  bool get shouldRestorePaneOnBack =>
      isPaneFullScreen &&
      _fullScreenEntryDepth != null &&
      entries.length <= _fullScreenEntryDepth!;

  /// 最后一次提交的助手栏比例，不包含门槽；布局夹取不覆盖它。
  double get paneSplitRatio => _paneSplitRatio;

  /// 拖动预览中的栏宽；为空表示没有进行中的拖动。
  double? get panePreviewWidth => _panePreviewWidth;

  bool get isPaneResizing => _panePreviewWidth != null;

  /// 路由可见栈顶变化后由观察者调用：让外壳重算门与接管状态。
  void notifyVisibilityChanged() => notifyListeners();

  /// 切换当前页面工作区的全屏/并排显示，不改变导航栈。
  void togglePaneFullScreen() {
    setPaneDisplayMode(
      isPaneFullScreen ? PaneDisplayMode.split : PaneDisplayMode.fullScreen,
    );
  }

  void setPaneDisplayMode(PaneDisplayMode mode, {bool restoreOnBack = true}) {
    final changed = _paneDisplayMode != mode || _panePreviewWidth != null;
    if (!changed) return;
    _setPaneDisplayMode(mode, restoreOnBack: restoreOnBack);
    notifyListeners();
  }

  void _setPaneDisplayMode(PaneDisplayMode mode, {bool restoreOnBack = true}) {
    if (mode == PaneDisplayMode.fullScreen &&
        _paneDisplayMode != PaneDisplayMode.fullScreen &&
        restoreOnBack) {
      _fullScreenEntryDepth = entries.length;
    } else if (mode == PaneDisplayMode.split) {
      _fullScreenEntryDepth = null;
    } else if (mode == PaneDisplayMode.fullScreen && !restoreOnBack) {
      _fullScreenEntryDepth = null;
    }
    _paneDisplayMode = mode;
    _panePreviewWidth = null;
  }

  void restorePaneSplit() => setPaneDisplayMode(PaneDisplayMode.split);

  /// 丢弃拖动预览并保留上次提交比例：取消、窗口宽度或可见栈顶变化时使用。
  void cancelPaneResize() {
    if (_panePreviewWidth == null) return;
    _panePreviewWidth = null;
    notifyListeners();
  }

  void beginPaneResize(double rightPaneWidth) {
    _panePreviewWidth = rightPaneWidth;
  }

  void updatePaneResize({
    required double physicalDelta,
    required double availableWidth,
    required TextDirection textDirection,
  }) {
    final current = _panePreviewWidth;
    if (current == null || availableWidth <= 0) return;
    final delta = textDirection == TextDirection.ltr
        ? physicalDelta
        : -physicalDelta;
    // 保留未经栏宽约束的拖动位置，以便在释放时判断是否真的到达边缘。
    _panePreviewWidth = current - delta;
    notifyListeners();
  }

  void endPaneResize({required double availableWidth}) {
    final preview = _panePreviewWidth;
    _panePreviewWidth = null;
    if (preview == null || availableWidth <= 0) return;
    final width = _clampPaneWidth(preview, availableWidth);
    _paneDisplayMode = PaneDisplayMode.split;
    if (width != paneSplitWidthFor(availableWidth)) {
      _paneSplitRatio = width / availableWidth;
    }
    notifyListeners();
  }

  void adjustPaneWidth({
    required double widthDelta,
    required double availableWidth,
  }) {
    if (availableWidth <= 0 || isPaneFullScreen) {
      return;
    }
    final current = paneSplitWidthFor(availableWidth);
    final width = _clampPaneWidth(current + widthDelta, availableWidth);
    if (width == current) return;
    _paneSplitRatio = width / availableWidth;
    notifyListeners();
  }

  double _clampPaneWidth(double width, double availableWidth) {
    final minWidth = math.min(AppLayout.paneRightMin, availableWidth / 2);
    final maxWidth = math.max(
      minWidth,
      math.min(activeMaxWidth, availableWidth - AppLayout.paneLeftMin),
    );
    return width.clamp(minWidth, maxWidth).toDouble();
  }

  /// 即使当前在单栏，也能计算恢复时的助手栏尺寸。
  double paneSplitWidthFor(double availableWidth) =>
      _clampPaneWidth(_paneSplitRatio * availableWidth, availableWidth);

  /// 当前实际交互槽宽：拖动中被夹在可读下限内，不把面板压到 0。
  double paneWidthFor(double availableWidth) => _clampPaneWidth(
    _panePreviewWidth ?? _paneSplitRatio * availableWidth,
    availableWidth,
  );

  /// 预览超出可读下限的量：负=助手太窄，正=工作区太窄；非拖动时为 0。
  double panePreviewOverflowFor(double availableWidth) {
    final preview = _panePreviewWidth;
    if (preview == null) return 0;
    return preview - paneWidthFor(availableWidth);
  }

  /// 外壳布局入口：一次算出两栏宽度、门槽位置和预览夹取信息。
  PaneSplitGeometry resolvePaneGeometry({
    required double windowWidth,
    required double railWidth,
  }) => resolvePaneSplitGeometry(
    windowWidth: windowWidth,
    railWidth: railWidth,
    ratio: _paneSplitRatio,
    maxPaneWidth: activeMaxWidth,
    previewWidth: _panePreviewWidth,
  );

  /// 面板是否有内容：决定外壳并排、让位还是继续显示。
  bool get hasContent => entries.isNotEmpty;

  /// 当前右栏所需的最大宽度；子页面没有单独声明时继承根入口。
  double get activeMaxWidth {
    for (final entry in entries.reversed) {
      if (entry.maxWidth case final width?) return width;
    }
    return isAssistantConversationActive
        ? AppLayout.assistantPaneMaxWidth
        : AppLayout.detailPaneMaxWidth;
  }

  /// 查找当前导航栈中具有稳定身份的入口。
  DetailPaneEntry? findByIdentity(String identity) {
    for (final entry in entries.reversed) {
      if (entry.identity == identity) return entry;
    }
    return null;
  }

  /// 将已有入口恢复到栈顶，并在离开其子页面前执行返回守卫。
  Future<bool> reveal(String identity) async {
    if (_disposed || _changing) return false;
    final targetIndex = entries.indexWhere(
      (entry) => entry.identity == identity,
    );
    if (targetIndex < 0) return false;
    _changing = true;
    try {
      for (final entry in entries.reversed.take(
        entries.length - targetIndex - 1,
      )) {
        final guard = entry.onRequestLeave;
        if (guard != null && !await guard()) return false;
      }
      final route = entries[targetIndex].route;
      if (route == null) return false;
      navigatorKey.currentState?.popUntil(
        (candidate) => identical(candidate, route),
      );
      entries.removeRange(targetIndex + 1, entries.length);
      notifyListeners();
      return true;
    } finally {
      _changing = false;
    }
  }

  /// 页面在 initState 注册自己的离开守卫到当前栈顶入口
  /// （表单的未保存确认、材料区的草稿确认都走这里），调用方不必传参。
  void registerTopGuard(
    Future<bool> Function() requestLeave, {
    Route<dynamic>? route,
  }) {
    for (final entry in entries.reversed) {
      if (route == null || identical(entry.route, route)) {
        entry.onRequestLeave = requestLeave;
        return;
      }
    }
  }

  /// 打开一个入口，与 Navigator.push 一样把结果（如保存是否成功）交回调用方。
  /// 从主工作区开始新页面链时，使用唯一的右侧 Navigator；页面链的
  /// 展示方式在入口处确定，后续子页面不会因设置变化而迁移到另一套栈。
  Future<T?> openFromWorkspace<T extends Object?>(
    DetailPaneEntry entry, {
    DetailPaneReplace replace = DetailPaneReplace.all,
    bool openInPane = true,
  }) => open<T>(
    entry,
    replace: replace,
    presentFromWorkspace: true,
    initialDisplayMode: openInPane
        ? PaneDisplayMode.split
        : PaneDisplayMode.fullScreen,
  );

  /// 打开一个入口，与 Navigator.push 一样把结果（如保存是否成功）交回调用方。
  Future<T?> open<T extends Object?>(
    DetailPaneEntry entry, {
    DetailPaneReplace replace = DetailPaneReplace.none,
    bool presentFromWorkspace = false,
    PaneDisplayMode? initialDisplayMode,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null || _disposed || _changing) return null;
    _changing = true;
    late Future<T?> closed;
    try {
      if (replace == DetailPaneReplace.all && !await _confirmLeaveAll()) {
        return null;
      }
      if (replace == DetailPaneReplace.top) {
        final guard = entries.isEmpty ? null : entries.last.onRequestLeave;
        if (guard != null && !await guard()) return null;
      }
      if (_disposed || !navigator.mounted) return null;
      if (replace == DetailPaneReplace.all) {
        navigator.popUntil((route) => route.isFirst);
        entries.clear();
      } else if (replace == DetailPaneReplace.top && entries.isNotEmpty) {
        entries.removeLast();
      }
      _panePreviewWidth = null;
      if (presentFromWorkspace) {
        _setPaneDisplayMode(
          initialDisplayMode ?? PaneDisplayMode.split,
          restoreOnBack: false,
        );
      }
      entries.add(entry);
      final route = MaterialPageRoute<T>(builder: entry.builder);
      entry.route = route;
      closed = replace == DetailPaneReplace.top && navigator.canPop()
          ? navigator.pushReplacement<T, void>(route)
          : navigator.push<T>(route);
      notifyListeners();
    } finally {
      // 防重入只保护守卫和入栈过程，不锁住页面整个阅读期间。
      _changing = false;
    }
    final result = await closed;
    // 路由被 pop（返回链回退、保存后返回）时同步入口登记。
    entries.remove(entry);
    if (!_disposed) notifyListeners();
    return result;
  }

  /// 顶层导航切换前清空子页，先让每层保存/报告草稿决定是否离开。
  Future<bool> clear() async {
    if (_disposed || _changing) return false;
    _changing = true;
    try {
      if (!await _confirmLeaveAll() || _disposed) return false;
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      entries.clear();
      notifyListeners();
      return true;
    } finally {
      _changing = false;
    }
  }

  /// 逐层走返回链；栈空返回 false，由外壳/系统继续处理。
  Future<bool> maybePop() async {
    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return false;
    return navigator.maybePop();
  }

  /// 替换/清空前逐个询问离开守卫；任一拒绝就中止，草稿继续保留。
  Future<bool> _confirmLeaveAll() async {
    for (final entry in entries.reversed.toList()) {
      final guard = entry.onRequestLeave;
      if (guard != null && !await guard()) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 右栏栈的路由观察者：未登记进 entries 的历史/设置页也会改变实际可见栈顶。
class _PaneRouteObserver extends NavigatorObserver {
  _PaneRouteObserver(this._controller);

  final DetailPaneController _controller;

  /// didPush 可能发生在 `Navigator` 首次构建期间，统一延到帧末再通知宿主。
  void _scheduleRefresh() {
    final controller = _controller;
    if (controller._disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller._disposed) controller.notifyVisibilityChanged();
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _scheduleRefresh();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _scheduleRefresh();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _scheduleRefresh();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _scheduleRefresh();
}

/// 右栏宿主：常驻挂载嵌套 Navigator，空栈时隐身让位。
///
/// 常驻是缩放迁移的关键：窗口变窄变宽只换这个宿主的位置，
/// 整条导航栈（含表单里未保存的输入）原样保留，不重建页面。
class DetailPaneHost extends StatelessWidget {
  const DetailPaneHost({
    super.key,
    required this.controller,
    this.restoreSplitOnBack = false,
    this.active = true,
  });
  final DetailPaneController controller;

  /// 折叠成单栏时，系统/顶栏返回优先恢复两栏；只在能分屏且聊天可见时传入。
  final bool restoreSplitOnBack;

  /// 右栏是否正在承载可见内容：隐藏的聊天子树不接管系统返回。
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pane = Offstage(
          offstage: !controller.hasContent,
          child: Navigator(
            key: controller.navigatorKey,
            observers: [controller.routeObserver],
            // 空栈垫底的初始路由；清空返回链时保留它作为终点。
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const SizedBox.shrink()),
          ),
        );
        // 系统返回先走右栏返回链（表单的未保存确认在链里生效），
        // 栈空才交回外壳；隐藏的聊天不弹到可见工作区之上。
        // 手动折叠（含贴边细轨）时先恢复两栏，再考虑离开。
        final canRestoreSplit =
            restoreSplitOnBack && controller.shouldRestorePaneOnBack;
        return PopScope(
          canPop: !controller.hasContent || (!active && !canRestoreSplit),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (canRestoreSplit) {
              controller.restorePaneSplit();
              return;
            }
            if (!active) return;
            await controller.maybePop();
          },
          child: pane,
        );
      },
    );
  }
}

/// 统一分页分隔门：贯穿上下的 24dp 槽，中间 8dp 门轨。
/// 点击门轨切换右栏全屏/并排；水平拖动只调整右栏宽度。
class PaneSplitDoor extends StatefulWidget {
  const PaneSplitDoor({
    super.key,
    required this.controller,
    required this.availableWidth,
    required this.rightPaneWidth,
    required this.textDirection,
  });

  /// 方向键步进沿用现行 40dp。
  static const keyboardStep = 40.0;

  final DetailPaneController controller;

  /// 可分配正文宽度（已扣门槽）：比例、吸附与键盘步进都按它算。
  final double availableWidth;

  /// 提交比例对应的助手栏宽；折叠态用 0/可分配宽作为拖动起点。
  final double rightPaneWidth;

  final TextDirection textDirection;

  @override
  State<PaneSplitDoor> createState() => _PaneSplitDoorState();
}

class _PaneSplitDoorState extends State<PaneSplitDoor> {
  bool _hovered = false;
  bool _dragging = false;

  DetailPaneController get _controller => widget.controller;

  void _adjust(double delta) => _controller.adjustPaneWidth(
    widthDelta: delta,
    availableWidth: widget.availableWidth,
  );

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final towardStart = widget.textDirection == TextDirection.ltr
          ? key == LogicalKeyboardKey.arrowLeft
          : key == LogicalKeyboardKey.arrowRight;
      _adjust(
        towardStart ? -PaneSplitDoor.keyboardStep : PaneSplitDoor.keyboardStep,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _controller.togglePaneFullScreen();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setDragging(bool value) {
    if (!mounted || _dragging == value) return;
    setState(() => _dragging = value);
  }

  @override
  Widget build(BuildContext context) {
    final fullScreen = _controller.isPaneFullScreen;
    final label = fullScreen ? '恢复并排分页' : '调整分页宽度';
    final percent = widget.availableWidth <= 0
        ? 50
        : (widget.rightPaneWidth / widget.availableWidth * 100)
              .clamp(0, 100)
              .round();
    return Focus(
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasPrimaryFocus;
          final active = focused || _hovered || _dragging;
          return Semantics(
            key: const Key('pane-split-door-semantics'),
            container: true,
            label: label,
            button: true,
            slider: !fullScreen,
            focusable: true,
            focused: focused,
            value: fullScreen ? '右侧页面全屏' : '右侧页面占宽 $percent%',
            increasedValue: fullScreen ? null : '右侧页面加宽',
            decreasedValue: fullScreen ? null : '右侧页面缩窄',
            hint: fullScreen
                ? '点击或按 Enter 还原并排分页'
                : '点击或按 Enter 进入右侧全屏；拖动或按方向键调整宽度',
            customSemanticsActions: {
              CustomSemanticsAction(label: fullScreen ? '还原并排分页' : '右侧页面全屏'):
                  _controller.togglePaneFullScreen,
            },
            onTap: _controller.togglePaneFullScreen,
            onIncrease: fullScreen
                ? null
                : () => _adjust(PaneSplitDoor.keyboardStep),
            onDecrease: fullScreen
                ? null
                : () => _adjust(-PaneSplitDoor.keyboardStep),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onTap: () {
                  Focus.of(context).requestFocus();
                  _controller.togglePaneFullScreen();
                },
                onHorizontalDragStart: (_) {
                  _setDragging(true);
                  _controller.beginPaneResize(widget.rightPaneWidth);
                },
                onHorizontalDragUpdate: (details) =>
                    _controller.updatePaneResize(
                      physicalDelta: details.primaryDelta ?? 0,
                      availableWidth: widget.availableWidth,
                      textDirection: widget.textDirection,
                    ),
                onHorizontalDragCancel: () {
                  _setDragging(false);
                  _controller.cancelPaneResize();
                },
                onHorizontalDragEnd: (_) {
                  _setDragging(false);
                  _controller.endPaneResize(
                    availableWidth: widget.availableWidth,
                  );
                },
                child: SizedBox(
                  key: const Key('pane-split-door'),
                  width: AppLayout.splitDoorWidth,
                  height: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: AppLayout.splitDoorTrackWidth,
                          height: double.infinity,
                          child: AnimatedContainer(
                            key: const Key('pane-split-door-track'),
                            duration: AppMotion.resolve(
                              context,
                              AppMotion.quick,
                            ),
                            curve: AppMotion.curve,
                            decoration: BoxDecoration(
                              // 闲置时退成低对比发丝线，不再像一根绿色墙；
                              // 只有悬停、聚焦或拖动时才强调为森林绿门轨。
                              color: active
                                  ? AppColors.primary.withValues(alpha: .62)
                                  : AppColors.hairline.withValues(alpha: .72),
                              borderRadius: BorderRadius.circular(
                                AppLayout.radiusXs,
                              ),
                            ),
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
      ),
    );
  }
}

class DetailPaneScope extends InheritedNotifier<DetailPaneController> {
  const DetailPaneScope({
    super.key,
    required DetailPaneController controller,
    required super.child,
  }) : super(notifier: controller);

  static DetailPaneController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailPaneScope>()?.notifier;
}

/// 语义化打开子页：有右栏（宽屏并排或窄屏全屏面板）就进右栏导航栈，
/// 页面单独使用（测试/预览）时回退普通 push——两种载体业务结果一致。
Future<T?> openDetailPane<T extends Object?>(
  BuildContext context, {
  required String label,
  required WidgetBuilder builder,
  String? identity,
  double? maxWidth,
  DetailPaneReplace replace = DetailPaneReplace.none,
  bool preserveExistingEntries = false,
}) {
  final controller = DetailPaneScope.maybeOf(context);
  if (controller != null) {
    // 主列表选择另一对象时替换整条右栏链；右栏内部的详情→编辑仍逐级入栈。
    final fromWorkspace =
        Navigator.of(context) != controller.navigatorKey.currentState;
    final usePane =
        MotionSettingsScope.maybeOf(context)?.settings.openSubpagesInPane ??
        true;
    return controller.open<T>(
      DetailPaneEntry(label, builder, identity: identity, maxWidth: maxWidth),
      replace:
          fromWorkspace &&
              replace == DetailPaneReplace.none &&
              !preserveExistingEntries
          ? DetailPaneReplace.all
          : replace,
      presentFromWorkspace: fromWorkspace,
      initialDisplayMode: fromWorkspace
          ? usePane
                ? PaneDisplayMode.split
                : PaneDisplayMode.fullScreen
          : null,
    );
  }
  // 无外壳（页面单独测试/预览）：保持 push/pushReplacement 的原有语义。
  final route = MaterialPageRoute<T>(builder: builder);
  if (replace == DetailPaneReplace.top) {
    return Navigator.of(context).pushReplacement<T, void>(route);
  }
  return Navigator.of(context).push<T>(route);
}
