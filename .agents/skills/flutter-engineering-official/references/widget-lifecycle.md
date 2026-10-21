# Flutter Widget / State / BuildContext / 资源生命周期

官方参考：[Flutter UI introduction](https://docs.flutter.dev/ui) · [State management fundamentals](https://docs.flutter.dev/get-started/fundamentals/state-management) · [BuildContext API](https://api.flutter.dev/flutter/widgets/BuildContext-class.html) · [State.mounted](https://api.flutter.dev/flutter/widgets/State/mounted.html)

## 框架实际约束与推荐

- `(FRAMEWORK_BEHAVIOR)` Widget 描述 UI 配置，`StatefulWidget` 对应的 `State` 才负责该 Widget 的有状态生命周期。`build()` 可能重复运行；不能依赖每次只执行一次。
- `(OFFICIAL_RECOMMENDATION)` 依赖数据的更新应驱动 UI 重建，不要把大量业务状态存为 Widget 的临时状态后写回数据库。
- `(TEAM)` `build` 只做声明式组合、布局和轻量格式化；不要在其中执行追加事件、数据库写、请求新的 Future 或一次性通知。
- `(FRAMEWORK_BEHAVIOR)` `initState`、`didChangeDependencies`、`didUpdateWidget`、`dispose` 目的不同；订阅依赖变化时需替换旧订阅；释放控制器、监听器、动画控制器和定时器。
- `(FRAMEWORK_BEHAVIOR)` 异步间隙之后 `BuildContext` 可能已失效。在 `State` 内使用 `if (!mounted) return;`；闭包持有 `BuildContext` 时使用 `if (!context.mounted) return;`，以实际访问对象为准。
- `(TEAM)` 事件回调避免并发双击；UI loading 仅提升体验，**不能**代替数据库唯一约束和事务内校验。
- `(TEAM)` 优先使用有现成 semantics、焦点和键盘行为的 Material/Cupertino Widget；自绘动作必须补全可访问性。
- `(TEAM)` 对重排列表、状态保留按 Flutter Key 语义选择稳定 key，不用 `UniqueKey()` 掩盖状态身份问题。

## 常见错误

```dart
@override
Widget build(BuildContext context) {                // 构建函数可能反复执行。
  repository.insertStartEvent();                    // 错误：Widget 重建可能多次写入事实。
  return const Text('执行中');                       // 文案不保证事件真的提交。
}
```

## 正确依赖方向示意

```text
User gesture -> ViewModel command -> Workflow/Repository -> persisted facts
       ↑             ↓                                ↓
       └----- immutable UI projection <- query/observe result
```

## `setState` / 响应式状态管理

- `setState` 适用于局部短暂 UI 状态，不是错误 API；复杂业务跨多个页面可由 ViewModel/Repository 管理。
- `ChangeNotifier`/`ValueListenable` 是官方 SDK 选择之一，Riverpod/Bloc 是第三方选项。Flutter 官方并**不**要求必须选择某一个包。
- 避免 `setState` 在 Widget 已 dispose 后执行；检查请求结果时间顺序，避免旧请求覆盖新结果。

## Widget Review

核查提交前 ViewModel 创建/释放责任、屏幕转场时订阅是否继续、排序时 Key 是否稳定、导航返回是否污染业务状态、系统时区变化后是否重新正确投影时间。
