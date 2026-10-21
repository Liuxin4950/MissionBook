# Flutter Semantics（无障碍语义）与业务语义严格区分

来源：[Flutter accessibility](https://docs.flutter.dev/ui/accessibility) · [Assistive technologies](https://docs.flutter.dev/ui/accessibility/assistive-technologies) · [Semantics API](https://api.flutter.dev/flutter/widgets/Semantics-class.html) · [SemanticsTester](https://api.flutter.dev/flutter/flutter_test/SemanticsTester-class.html) · [Web accessibility](https://docs.flutter.dev/ui/accessibility/web-accessibility)

## 两种完全不同的“语义”

- **Dart 语义**：代码/数据的类型和行为规则，如 `isRunning`、`Future<void>` 或事务。
- **Flutter `Semantics`**：向屏幕阅读器/辅助技术提供可访问的控件名字、提示、值、角色与动作。不提供业务状态合法性保证。

## 可执行检查规则

1. 优先原生语义完备控件：`TextButton`、`FilledButton`、`IconButton(tooltip:...)`、`Checkbox`、`Switch`、`TextField`。
2. 无文本图标操作应具有准确可访问名称：`IconButton(tooltip: '暂停任务', ...)`。标签与实际操作一致，不把“停止”错误表述成“结束 Mission”。
3. 复杂自绘控件必要时使用 `Semantics(label:, button:, enabled:, value:, hint:, onTap:, ...)`，避免 `Semantics` 和子控件各自生成重复名字/动作，必要时审查 `ExcludeSemantics` / `MergeSemantics` 行为。
4. 保证屏幕阅读器顺序与视觉层次一致；布局、对比度、字体缩放、焦点/键盘操作、触控区域均须验收。
5. 对运行中、暂停、材料待交等状态，独立朗读能理解当前**事实**；不要用 AI 已验证/合格标签误导。
6. 模态对话框能获得焦点，关闭后返回合理位置；屏幕阅读器不应读到后台隐藏控件。
7. 在 Android 设备使用 TalkBack 验收；Windows 平台还要针对实际辅助技术、窗口与键盘导航实测。单靠 Flutter Widget test 不能证明实际平台可访问性。

## Widget 代码示例

见 `assets/examples/accessible_mission_button.dart`：选用原生 `FilledButton.icon`，按钮标签包含操作，不额外加重复 `Semantics`。若需要自定义分组信息，再为分组加合理语义节点。

## Widget 测试建议

- `find.text('暂停任务')` 能找到明确文案，但这不等于 screen reader 真正播报正确。
- 对关键自绘组件使用 Semantics tester/`ensureSemantics`，比较预期标签、角色与启用状态；测试 API 需要按所安装 Flutter SDK 核对。
- 使用真实设备对比测试，确保读屏不会产生重复标签、漏掉操作或错报执行状态。

## 注意 Flutter Web

Flutter Web 以内部 Semantics tree 转化为辅助 DOM；启用方式、辅助特性及 `SemanticsRole` 能力随 Flutter SDK 改变。本地 Windows+Android 项目当前不应为了 Web API 引入不必要适配。
