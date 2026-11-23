import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/colors.dart';

/// 稳定标记：只有助手会话路由允许使用可调分屏，普通详情保持既有布局。
const assistantConversationPaneIdentity = 'assistant-conversation';

/// 助手分屏的显示形态；折叠只改变布局，不从导航栈移除页面。
enum AssistantPaneMode { split, workspaceExpanded, assistantExpanded }

/// 助手分屏的纯几何：由窗口宽度和控制器状态算出两栏宽度与门槽位置。
///
/// 门槽在阅读末端（分屏、仅工作区）或阅读起点（仅助手）定位，
/// RTL 镜像交给外壳的 `PositionedDirectional`，这里只保留逻辑侧。
class AssistantSplitGeometry {
  const AssistantSplitGeometry({
    required this.contentWidth,
    required this.availableWidth,
    required this.workspaceWidth,
    required this.assistantWidth,
    required this.committedAssistantWidth,
    required this.dragStartWidth,
    required this.mode,
    required this.doorAtEnd,
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
  final double assistantWidth;

  /// 提交比例夹取后的助手栏宽：恢复分屏和读屏百分比都用它。
  final double committedAssistantWidth;

  /// 拖动起点宽度：分屏按夹取栏宽，仅工作区从 0 起、仅助手从可分配宽起。
  final double dragStartWidth;

  /// 拖动预览期间门槽按分屏画，但模式要到松手才提交。
  final AssistantPaneMode mode;

  /// 门槽贴在阅读末端（工作区/仅工作区）还是阅读起点（仅助手）。
  final bool doorAtEnd;

  /// 门槽距所贴边的偏移。
  final double doorOffset;

  /// 预览被可读下限夹取的超出量：负=助手已到下限，正=工作区已到下限。
  final double previewOverflow;

  bool get isSplit => mode == AssistantPaneMode.split;
}

/// 纯函数几何：不读 BuildContext，测试可直接按断点和矩形断言。
AssistantSplitGeometry resolveAssistantSplitGeometry({
  required double windowWidth,
  required double railWidth,
  required AssistantPaneMode mode,
  required double ratio,
  required double maxAssistantWidth,
  double? previewWidth,
}) {
  final contentWidth = math.max(0.0, windowWidth - railWidth);
  final available = math.max(0.0, contentWidth - AppLayout.splitDoorWidth);
  final minAssistant = math.min(AppLayout.paneRightMin, available);
  final maxAssistant = math.max(
    minAssistant,
    math.min(maxAssistantWidth, available - AppLayout.paneLeftMin),
  );
  final committed = (ratio * available)
      .clamp(minAssistant, maxAssistant)
      .toDouble();
  // 拖动中（含从折叠态拉出）一律按分屏几何布局，松手才提交模式。
  final dragging = previewWidth != null;
  final effectiveMode = dragging ? AssistantPaneMode.split : mode;
  final preview = dragging
      ? previewWidth.clamp(minAssistant, maxAssistant).toDouble()
      : null;
  final overflow = dragging ? previewWidth - preview! : 0.0;
  final slot = preview ?? committed;
  final door = AppLayout.splitDoorWidth;

  switch (effectiveMode) {
    case AssistantPaneMode.split:
      return AssistantSplitGeometry(
        contentWidth: contentWidth,
        availableWidth: available,
        workspaceWidth: math.max(0.0, windowWidth - door - slot),
        assistantWidth: slot,
        committedAssistantWidth: committed,
        dragStartWidth: mode == AssistantPaneMode.workspaceExpanded
            ? 0.0
            : slot,
        mode: mode,
        doorAtEnd: true,
        doorOffset: slot,
        previewOverflow: overflow,
      );
    case AssistantPaneMode.workspaceExpanded:
      return AssistantSplitGeometry(
        contentWidth: contentWidth,
        availableWidth: available,
        // 隐藏的助手子树保留合法栏宽，恢复时不重建、不重排。
        workspaceWidth: math.max(0.0, windowWidth - door),
        assistantWidth: committed,
        committedAssistantWidth: committed,
        dragStartWidth: 0,
        mode: mode,
        doorAtEnd: true,
        doorOffset: 0,
        previewOverflow: 0,
      );
    case AssistantPaneMode.assistantExpanded:
      return AssistantSplitGeometry(
        contentWidth: contentWidth,
        availableWidth: available,
        workspaceWidth: math.max(0.0, windowWidth - door - committed),
        assistantWidth: math.max(0.0, windowWidth - door),
        committedAssistantWidth: committed,
        dragStartWidth: available,
        mode: mode,
        doorAtEnd: false,
        doorOffset: 0,
        previewOverflow: 0,
      );
  }
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
  AssistantPaneMode _assistantPaneMode = AssistantPaneMode.split;
  double _assistantSplitRatio = 0.5;
  double? _assistantPreviewWidth;

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

  AssistantPaneMode get assistantPaneMode => _assistantPaneMode;

  /// 最后一次提交的助手栏比例，不包含门槽；布局夹取不覆盖它。
  double get assistantSplitRatio => _assistantSplitRatio;

  /// 拖动预览中的栏宽；为空表示没有进行中的拖动。
  double? get assistantPreviewWidth => _assistantPreviewWidth;

  bool get assistantIsResizing => _assistantPreviewWidth != null;

  /// 路由可见栈顶变化后由观察者调用：让外壳重算门与接管状态。
  void notifyVisibilityChanged() => notifyListeners();

  /// 显式切换分屏模式（Home/End、恢复动作与折叠都走这里）。
  void setAssistantPaneMode(AssistantPaneMode mode) {
    final changed =
        _assistantPaneMode != mode || _assistantPreviewWidth != null;
    _assistantPaneMode = mode;
    _assistantPreviewWidth = null;
    if (changed) notifyListeners();
  }

  void restoreAssistantSplit() => setAssistantPaneMode(AssistantPaneMode.split);

  void collapseAssistantToWorkspace() =>
      setAssistantPaneMode(AssistantPaneMode.workspaceExpanded);

  /// 丢弃拖动预览并保留上次提交比例：取消、窗口宽度或可见栈顶变化时使用。
  void cancelAssistantResize() {
    if (_assistantPreviewWidth == null) return;
    _assistantPreviewWidth = null;
    notifyListeners();
  }

  void beginAssistantResize(double assistantWidth) {
    _assistantPreviewWidth = assistantWidth;
  }

  void updateAssistantResize({
    required double physicalDelta,
    required double availableWidth,
    required TextDirection textDirection,
  }) {
    final current = _assistantPreviewWidth;
    if (current == null || availableWidth <= 0) return;
    final delta = textDirection == TextDirection.ltr
        ? physicalDelta
        : -physicalDelta;
    // 保留未经栏宽约束的拖动位置，以便在释放时判断是否真的到达边缘。
    _assistantPreviewWidth = current - delta;
    notifyListeners();
  }

  void endAssistantResize({required double availableWidth}) {
    final preview = _assistantPreviewWidth;
    _assistantPreviewWidth = null;
    if (preview == null || availableWidth <= 0) return;
    if (preview <= AppLayout.paneEdgeSnap) {
      _assistantPaneMode = AssistantPaneMode.workspaceExpanded;
    } else if (availableWidth - preview <= AppLayout.paneEdgeSnap) {
      _assistantPaneMode = AssistantPaneMode.assistantExpanded;
    } else {
      final width = _clampAssistantWidth(preview, availableWidth);
      _assistantPaneMode = AssistantPaneMode.split;
      if (width != assistantSplitWidthFor(availableWidth)) {
        _assistantSplitRatio = width / availableWidth;
      }
    }
    notifyListeners();
  }

  void adjustAssistantSplit({
    required double widthDelta,
    required double availableWidth,
  }) {
    if (availableWidth <= 0 || _assistantPaneMode != AssistantPaneMode.split) {
      return;
    }
    final current = assistantSplitWidthFor(availableWidth);
    final width = _clampAssistantWidth(current + widthDelta, availableWidth);
    if (width == current) return;
    _assistantSplitRatio = width / availableWidth;
    notifyListeners();
  }

  double _clampAssistantWidth(double width, double availableWidth) {
    final minWidth = math.min(AppLayout.paneRightMin, availableWidth / 2);
    final maxWidth = math.max(
      minWidth,
      math.min(activeMaxWidth, availableWidth - AppLayout.paneLeftMin),
    );
    return width.clamp(minWidth, maxWidth).toDouble();
  }

  /// 即使当前在单栏，也能计算恢复时的助手栏尺寸。
  double assistantSplitWidthFor(double availableWidth) => _clampAssistantWidth(
    _assistantSplitRatio * availableWidth,
    availableWidth,
  );

  /// 当前实际交互槽宽：拖动中被夹在可读下限内，不把面板压到 0。
  double assistantSlotWidthFor(double availableWidth) => _clampAssistantWidth(
    _assistantPreviewWidth ?? _assistantSplitRatio * availableWidth,
    availableWidth,
  );

  /// 预览超出可读下限的量：负=助手太窄，正=工作区太窄；非拖动时为 0。
  double assistantPreviewOverflowFor(double availableWidth) {
    final preview = _assistantPreviewWidth;
    if (preview == null) return 0;
    return preview - assistantSlotWidthFor(availableWidth);
  }

  /// 外壳布局入口：一次算出两栏宽度、门槽位置和预览夹取信息。
  AssistantSplitGeometry resolveAssistantGeometry({
    required double windowWidth,
    required double railWidth,
  }) => resolveAssistantSplitGeometry(
    windowWidth: windowWidth,
    railWidth: railWidth,
    mode: _assistantPaneMode,
    ratio: _assistantSplitRatio,
    maxAssistantWidth: activeMaxWidth,
    previewWidth: _assistantPreviewWidth,
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
  Future<T?> open<T extends Object?>(
    DetailPaneEntry entry, {
    DetailPaneReplace replace = DetailPaneReplace.none,
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
      _assistantPreviewWidth = null;
      if (entry.identity == assistantConversationPaneIdentity) {
        _assistantPaneMode = AssistantPaneMode.split;
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
            restoreSplitOnBack &&
            controller.isAssistantConversationVisibleTop &&
            controller.assistantPaneMode != AssistantPaneMode.split;
        return PopScope(
          canPop: !controller.hasContent || (!active && !canRestoreSplit),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (canRestoreSplit) {
              controller.restoreAssistantSplit();
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

/// 「橱窗门」：贯穿上下的 24dp 分隔槽，中间 8dp 门轨。
///
/// 整条槽都能水平起拖，没有左右隐形扩区；折叠时只保留贴边细轨，
/// 点按、向内拖动或 Enter/空格都恢复分屏，Home/End 切单栏。
class AssistantSplitDoor extends StatefulWidget {
  const AssistantSplitDoor({
    super.key,
    required this.controller,
    required this.availableWidth,
    required this.assistantWidth,
    required this.textDirection,
  });

  /// 方向键步进沿用现行 40dp。
  static const keyboardStep = 40.0;

  final DetailPaneController controller;

  /// 可分配正文宽度（已扣门槽）：比例、吸附与键盘步进都按它算。
  final double availableWidth;

  /// 提交比例对应的助手栏宽；折叠态用 0/可分配宽作为拖动起点。
  final double assistantWidth;

  final TextDirection textDirection;

  @override
  State<AssistantSplitDoor> createState() => _AssistantSplitDoorState();
}

class _AssistantSplitDoorState extends State<AssistantSplitDoor> {
  bool _hovered = false;
  bool _dragging = false;

  DetailPaneController get _controller => widget.controller;

  void _adjust(double delta) => _controller.adjustAssistantSplit(
    widthDelta: delta,
    availableWidth: widget.availableWidth,
  );

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final collapsed = _controller.assistantPaneMode != AssistantPaneMode.split;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      if (collapsed) {
        _controller.restoreAssistantSplit();
        return KeyEventResult.handled;
      }
      final towardStart = widget.textDirection == TextDirection.ltr
          ? key == LogicalKeyboardKey.arrowLeft
          : key == LogicalKeyboardKey.arrowRight;
      // 向起始方向移动分隔槽＝收窄助手；向末端方向＝加宽助手。
      _adjust(
        towardStart
            ? -AssistantSplitDoor.keyboardStep
            : AssistantSplitDoor.keyboardStep,
      );
      return KeyEventResult.handled;
    }
    // Home/End 切单栏；与门上的读屏自定义动作同名同义。
    if (key == LogicalKeyboardKey.home) {
      _controller.setAssistantPaneMode(AssistantPaneMode.workspaceExpanded);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _controller.setAssistantPaneMode(AssistantPaneMode.assistantExpanded);
      return KeyEventResult.handled;
    }
    if (collapsed &&
        (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space)) {
      _controller.restoreAssistantSplit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 折叠态细轨上的箭头：指向阅读内侧，RTL 自动镜像。
  IconData _inwardChevron(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final workspaceHidden =
        _controller.assistantPaneMode == AssistantPaneMode.workspaceExpanded;
    if (workspaceHidden) {
      return rtl ? Icons.chevron_right : Icons.chevron_left;
    }
    return rtl ? Icons.chevron_left : Icons.chevron_right;
  }

  void _setDragging(bool value) {
    if (!mounted || _dragging == value) return;
    setState(() => _dragging = value);
  }

  @override
  Widget build(BuildContext context) {
    final mode = _controller.assistantPaneMode;
    final collapsed = mode != AssistantPaneMode.split;
    final label = switch (mode) {
      AssistantPaneMode.split => '调整助手分屏',
      AssistantPaneMode.workspaceExpanded => '恢复助手分屏',
      AssistantPaneMode.assistantExpanded => '恢复工作区分屏',
    };
    final percent = widget.availableWidth <= 0
        ? 50
        : (widget.assistantWidth / widget.availableWidth * 100)
              .clamp(0, 100)
              .round();
    final overflow = _controller.assistantPreviewOverflowFor(
      widget.availableWidth,
    );
    return Focus(
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasPrimaryFocus;
          final active = focused || _hovered || _dragging;
          return Semantics(
            key: const Key('assistant-split-door-semantics'),
            container: true,
            label: label,
            button: collapsed,
            slider: !collapsed,
            focusable: true,
            focused: focused,
            value: collapsed ? null : '助手栏 $percent%',
            increasedValue: collapsed ? null : '助手栏加宽',
            decreasedValue: collapsed ? null : '助手栏缩窄',
            hint: collapsed
                ? '点击、向内拖动或按 Enter 恢复上次分屏比例'
                : '左右拖动或按方向键调整，Home 仅工作区，End 仅助手',
            customSemanticsActions: collapsed
                ? null
                : {
                    const CustomSemanticsAction(label: '仅显示工作区'): () =>
                        _controller.setAssistantPaneMode(
                          AssistantPaneMode.workspaceExpanded,
                        ),
                    const CustomSemanticsAction(label: '仅显示助手'): () =>
                        _controller.setAssistantPaneMode(
                          AssistantPaneMode.assistantExpanded,
                        ),
                  },
            onTap: collapsed ? _controller.restoreAssistantSplit : null,
            onIncrease: collapsed
                ? null
                : () => _adjust(AssistantSplitDoor.keyboardStep),
            onDecrease: collapsed
                ? null
                : () => _adjust(-AssistantSplitDoor.keyboardStep),
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
                  if (collapsed) _controller.restoreAssistantSplit();
                },
                onHorizontalDragStart: (_) {
                  _setDragging(true);
                  _controller.beginAssistantResize(widget.assistantWidth);
                },
                onHorizontalDragUpdate: (details) =>
                    _controller.updateAssistantResize(
                      physicalDelta: details.primaryDelta ?? 0,
                      availableWidth: widget.availableWidth,
                      textDirection: widget.textDirection,
                    ),
                onHorizontalDragCancel: () {
                  _setDragging(false);
                  _controller.cancelAssistantResize();
                },
                onHorizontalDragEnd: (_) {
                  _setDragging(false);
                  _controller.endAssistantResize(
                    availableWidth: widget.availableWidth,
                  );
                },
                child: SizedBox(
                  key: const Key('assistant-split-door'),
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
                            key: const Key('assistant-split-door-track'),
                            duration: AppMotion.resolve(
                              context,
                              AppMotion.quick,
                            ),
                            curve: AppMotion.curve,
                            decoration: BoxDecoration(
                              // 浅绿门轨在白底上几乎不可见，空闲态用半透明森林绿填充 +
                              // 同色细边形成一条清晰的门轨；悬停/聚焦/拖动再加深到品牌绿。
                              color: active
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: .22),
                              borderRadius: BorderRadius.circular(
                                AppLayout.radiusXs,
                              ),
                              border: Border.all(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: .55),
                                width: AppLayout.strokeThin,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (collapsed)
                        Center(
                          child: IgnorePointer(
                            child: SizedBox(
                              key: const Key('assistant-split-door-grip'),
                              width: AppLayout.spaceXxl,
                              height: AppLayout.spaceXxl,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: active
                                        ? AppColors.primary
                                        : AppColors.hairline,
                                  ),
                                ),
                                child: Icon(
                                  // 箭头指向隐藏侧的内容方向：拖进来才会展开，RTL 镜像。
                                  _inwardChevron(context),
                                  size: AppLayout.iconSm,
                                  color: active
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 到达可读下限后，交互槽停在夹取位置，只用不接收命中的提示表示超出。
                      if (overflow != 0)
                        Align(
                          alignment: overflow < 0
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: Container(
                                key: const Key(
                                  'assistant-split-door-edge-hint',
                                ),
                                width: AppLayout.spaceSm,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppLayout.radiusXs,
                                  ),
                                  gradient: LinearGradient(
                                    begin: overflow < 0
                                        ? AlignmentDirectional.centerStart
                                        : AlignmentDirectional.centerEnd,
                                    end: overflow < 0
                                        ? AlignmentDirectional.centerEnd
                                        : AlignmentDirectional.centerStart,
                                    colors: [
                                      Colors.transparent,
                                      AppColors.primary.withValues(alpha: .28),
                                    ],
                                  ),
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

/// 把控制器交给页面（外壳挂载 [DetailPaneScope] 后生效）。
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
    return controller.open<T>(
      DetailPaneEntry(label, builder, identity: identity, maxWidth: maxWidth),
      replace:
          fromWorkspace &&
              replace == DetailPaneReplace.none &&
              !preserveExistingEntries
          ? DetailPaneReplace.all
          : replace,
    );
  }
  // 无外壳（页面单独测试/预览）：保持 push/pushReplacement 的原有语义。
  final route = MaterialPageRoute<T>(builder: builder);
  if (replace == DetailPaneReplace.top) {
    return Navigator.of(context).pushReplacement<T, void>(route);
  }
  return Navigator.of(context).push<T>(route);
}
