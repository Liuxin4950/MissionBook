import 'package:flutter/material.dart';

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
  DetailPaneEntry(this.label, this.builder, {this.onRequestLeave});

  /// 语义标签（如“任务详情”），读屏/测试用它识别入口身份。
  final String label;

  /// 与 MaterialPageRoute 的构建器同型：右栏完全复用 push 形态的页面组件。
  final WidgetBuilder builder;

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

  /// 面板是否有内容：决定外壳并排、让位还是继续显示。
  bool get hasContent => entries.isNotEmpty;

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
    if (navigator == null || _disposed) return null;
    if (replace == DetailPaneReplace.all && !await _confirmLeaveAll()) {
      return null;
    }
    if (replace == DetailPaneReplace.top) {
      final guard = entries.isEmpty ? null : entries.last.onRequestLeave;
      if (guard != null && !await guard()) return null;
      if (_disposed || !navigator.mounted) return null;
      if (entries.isNotEmpty) entries.removeLast();
      entries.add(entry);
      notifyListeners();
      final route = MaterialPageRoute<T>(builder: entry.builder);
      entry.route = route;
      final result = await navigator.pushReplacement<T, void>(route);
      entries.remove(entry);
      if (!_disposed) notifyListeners();
      return result;
    }
    if (replace == DetailPaneReplace.all) {
      if (_disposed || !navigator.mounted) return null;
      navigator.popUntil((route) => route.isFirst);
      entries.clear();
    }
    entries.add(entry);
    notifyListeners();
    final route = MaterialPageRoute<T>(builder: entry.builder);
    entry.route = route;
    final result = await navigator.push<T>(route);
    // 路由被 pop（返回链回退、保存后返回）时同步入口登记。
    entries.remove(entry);
    if (!_disposed) notifyListeners();
    return result;
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
  const DetailPaneHost({super.key, required this.controller});
  final DetailPaneController controller;

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
            await controller.maybePop();
          },
          child: pane,
        );
      },
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
  DetailPaneReplace replace = DetailPaneReplace.none,
}) {
  final controller = DetailPaneScope.maybeOf(context);
  if (controller != null) {
    return controller.open<T>(
      DetailPaneEntry(label, builder),
      replace: replace,
    );
  }
  // 无外壳（页面单独测试/预览）：保持 push/pushReplacement 的原有语义。
  final route = MaterialPageRoute<T>(builder: builder);
  if (replace == DetailPaneReplace.top) {
    return Navigator.of(context).pushReplacement<T, void>(route);
  }
  return Navigator.of(context).push<T>(route);
}
