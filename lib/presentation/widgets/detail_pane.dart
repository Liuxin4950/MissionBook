import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_layout.dart';

/// 稳定标记：只有助手会话路由允许使用可调分屏，普通详情保持既有布局。
const assistantConversationPaneIdentity = 'assistant-conversation';

/// 助手分屏的显示形态；折叠只改变布局，不从导航栈移除页面。
enum AssistantPaneMode { split, workspaceExpanded, assistantExpanded }

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
  bool _disposed = false;
  bool _changing = false;
  static const _assistantEdgeSnap = 96.0;
  AssistantPaneMode _assistantPaneMode = AssistantPaneMode.split;
  double _assistantSplitRatio = 0.5;
  double? _assistantPreviewWidth;

  /// 只在助手会话是栈顶时可调；普通详情不继承分屏展示模式。
  bool get isAssistantConversationActive =>
      entries.isNotEmpty &&
      entries.last.identity == assistantConversationPaneIdentity;

  AssistantPaneMode get assistantPaneMode => _assistantPaneMode;

  /// 最后一次提交的助手栏比例，不包含栏间距；布局夹取不覆盖它。
  double get assistantSplitRatio => _assistantSplitRatio;

  void restoreAssistantSplit() {
    if (_assistantPaneMode == AssistantPaneMode.split) return;
    _assistantPreviewWidth = null;
    _assistantPaneMode = AssistantPaneMode.split;
    notifyListeners();
  }

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
    if (_assistantPaneMode != AssistantPaneMode.split) {
      final draggedInward =
          _assistantPaneMode == AssistantPaneMode.workspaceExpanded
          ? preview > 0
          : preview < availableWidth;
      if (draggedInward) restoreAssistantSplit();
      return;
    }
    if (preview <= _assistantEdgeSnap) {
      _assistantPaneMode = AssistantPaneMode.workspaceExpanded;
    } else if (availableWidth - preview <= _assistantEdgeSnap) {
      _assistantPaneMode = AssistantPaneMode.assistantExpanded;
    } else {
      final width = _clampAssistantWidth(preview, availableWidth);
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
    if (availableWidth <= 0) return;
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

  double assistantWidthFor(double availableWidth) =>
      switch (_assistantPaneMode) {
        AssistantPaneMode.workspaceExpanded => 0,
        AssistantPaneMode.assistantExpanded => availableWidth,
        AssistantPaneMode.split => _clampAssistantWidth(
          _assistantPreviewWidth ?? _assistantSplitRatio * availableWidth,
          availableWidth,
        ),
      };

  /// 到达可读栏宽下限后，拖动提示仍跟随指针；放手前不压扁面板。
  double assistantDividerOffsetFor(double availableWidth) =>
      (_assistantPreviewWidth ?? assistantSplitWidthFor(availableWidth)).clamp(
        0.0,
        availableWidth,
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

/// 右栏宿主：常驻挂载嵌套 Navigator，空栈时隐身让位。
///
/// 常驻是缩放迁移的关键：窗口变窄变宽只换这个宿主的位置，
/// 整条导航栈（含表单里未保存的输入）原样保留，不重建页面。
class DetailPaneHost extends StatelessWidget {
  const DetailPaneHost({
    super.key,
    required this.controller,
    this.restoreSplitOnBack = false,
  });
  final DetailPaneController controller;
  final bool restoreSplitOnBack;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pane = Offstage(
          offstage: !controller.hasContent,
          child: Navigator(
            key: controller.navigatorKey,
            // 空栈垫底的初始路由；清空返回链时保留它作为终点。
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const SizedBox.shrink()),
          ),
        );
        // 系统返回先走右栏返回链（表单的未保存确认在链里生效），
        // 栈空才交回外壳；否则会直接退出应用。
        return PopScope(
          canPop: !controller.hasContent,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (restoreSplitOnBack &&
                controller.isAssistantConversationActive &&
                controller.assistantPaneMode != AssistantPaneMode.split) {
              controller.restoreAssistantSplit();
              return;
            }
            await controller.maybePop();
          },
          child: pane,
        );
      },
    );
  }
}

/// 同一个键盘焦点在普通分隔线与边缘恢复控件之间保留。
class AssistantSplitHandle extends StatelessWidget {
  const AssistantSplitHandle({
    super.key,
    required this.controller,
    required this.availableWidth,
    required this.assistantWidth,
    required this.textDirection,
  });

  static const _keyboardStep = 40.0;
  final DetailPaneController controller;
  final double availableWidth;
  final double assistantWidth;
  final TextDirection textDirection;

  void _adjust(double delta) => controller.adjustAssistantSplit(
    widthDelta: delta,
    availableWidth: availableWidth,
  );

  @override
  Widget build(BuildContext context) {
    final mode = controller.assistantPaneMode;
    final collapsed = mode != AssistantPaneMode.split;
    final label = switch (mode) {
      AssistantPaneMode.split => '调整助手分屏',
      AssistantPaneMode.workspaceExpanded => '恢复助手分屏',
      AssistantPaneMode.assistantExpanded => '恢复工作区分屏',
    };
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      includeSemantics: false,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight) {
          if (collapsed) {
            controller.restoreAssistantSplit();
          } else {
            final towardStart = textDirection == TextDirection.ltr
                ? key == LogicalKeyboardKey.arrowLeft
                : key == LogicalKeyboardKey.arrowRight;
            _adjust(towardStart ? _keyboardStep : -_keyboardStep);
          }
          return KeyEventResult.handled;
        }
        if (collapsed &&
            (key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.space)) {
          controller.restoreAssistantSplit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasPrimaryFocus;
          return Semantics(
            container: true,
            label: label,
            button: collapsed,
            slider: !collapsed,
            focusable: true,
            focused: focused,
            value: collapsed
                ? null
                : '助手栏 ${(assistantWidth / availableWidth * 100).round()}%',
            increasedValue: collapsed ? null : '助手栏加宽',
            decreasedValue: collapsed ? null : '助手栏缩窄',
            hint: collapsed ? '点击或向内拖动，恢复上次分屏比例' : '可左右拖动，方向键调整',
            onTap: collapsed ? controller.restoreAssistantSplit : null,
            onIncrease: collapsed ? null : () => _adjust(_keyboardStep),
            onDecrease: collapsed ? null : () => _adjust(-_keyboardStep),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onTap: () {
                  Focus.of(context).requestFocus();
                  if (collapsed) controller.restoreAssistantSplit();
                },
                onHorizontalDragStart: (_) =>
                    controller.beginAssistantResize(assistantWidth),
                onHorizontalDragUpdate: (details) =>
                    controller.updateAssistantResize(
                      physicalDelta: details.primaryDelta ?? 0,
                      availableWidth: availableWidth,
                      textDirection: textDirection,
                    ),
                onHorizontalDragCancel: controller.cancelAssistantResize,
                onHorizontalDragEnd: (_) => controller.endAssistantResize(
                  availableWidth: availableWidth,
                ),
                child: SizedBox(
                  key: collapsed
                      ? const Key('assistant-split-restore')
                      : const Key('assistant-split-handle'),
                  width: AppLayout.touchTargetMin,
                  height: AppLayout.touchTargetMin,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: collapsed || focused
                            ? scheme.primary
                            : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppLayout.radiusPill,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppLayout.spaceSm,
                          horizontal: AppLayout.spaceXs,
                        ),
                        child: Icon(
                          collapsed
                              ? Icons.splitscreen_rounded
                              : Icons.drag_indicator,
                          size: AppLayout.iconMd,
                          color: collapsed || focused
                              ? scheme.onPrimary
                              : scheme.primary,
                        ),
                      ),
                    ),
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
