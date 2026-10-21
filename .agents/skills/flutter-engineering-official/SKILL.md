---
name: flutter-engineering-official
description: Apply official Flutter framework recommendations for Widget composition/lifecycle, state management, MVVM and repositories, accessibility Semantics, async UI, navigation, testing and CI. Use when creating, modifying or reviewing Flutter apps, packages and plugins across mobile and desktop. Distinguish official recommendations from language requirements.
compatibility: Flutter SDK recommended; Python 3 required only for the optional quality-check script.
metadata:
  version: "1.0.0"
  reviewed: "2026-10-21"
  language: "zh-CN"
---

# Flutter 工程规范与语义可访问性

## 触发条件

编写/修改 `Widget`、页面、主题、状态、导航、应用架构、数据库接入、测试、跨平台或无障碍时激活。编码层面同时激活 `dart-language-official`。

## 执行顺序

1. 识别目标平台、项目 Flutter/Dart SDK 版本、应用已有架构、状态管理与依赖；不得凭空替换路由/状态管理/ORM。
2. 根据 `references/widget-lifecycle.md` 设计 Widget 生命周期、不可变输入、焦点、`BuildContext`、async、资源释放。
3. 根据 `references/architecture-state.md` 判断 UI/ViewModel/Repository/Service 是否合理；复杂跨源业务可以考虑 Domain/UseCase，但不是每个小功能都强行加层。
4. 如果有任何用户操作/自绘图标/状态变化，依据 `references/accessibility-semantics.md` 核查 **Flutter `Semantics` 无障碍信息**，不要把其与业务数据“语义命名”混淆。
5. 按 `references/testing-quality.md` 添加针对性的单元、Widget、集成测试；运行本地质量门禁，若无法运行明确说明。
6. 产出中分开 `(FRAMEWORK_BEHAVIOR)`、`(OFFICIAL_RECOMMENDATION)`、`(TEAM)`、`(DOMAIN)`。不要把 `ChangeNotifier`、MVVM、Riverpod 或某一目录结构表述为 Flutter 编译器强制。

## 最低验收底线

- UI 显示派生状态，业务事实只经有权限的写入层变更；Widget 构建不能发起数据库事实写入。
- `build()` 不执行非幂等副作用；异步回调跨帧读取 `context` 前检查 `mounted`（依上下文类型选择）。
- 控制器、订阅、定时器等由拥有者释放；可取消的任务要释放或去重。
- 交互控件可被访问：可读标签、动作、状态与合适触达范围；避免重复语义节点。
- 不以截图成功或 `flutter analyze` 成功替代实际测试；必须验证行为、持久化及跨重启场景。

## 按需参考

- `references/widget-lifecycle.md` — Widget/State/BuildContext/Key/异步
- `references/architecture-state.md` — 分层、状态与依赖方向
- `references/accessibility-semantics.md` — Semantics、无障碍行为与 Widget 测试
- `references/testing-quality.md` — 测试金字塔、CI 与覆盖责任
- `references/sources.md` — Flutter 第一手来源
- `assets/analysis_options.yaml` — 可复制配置（须添加 dev_dependency）
- `assets/flutter_quality.yml` — GitHub Actions 示例
- `assets/examples/accessible_mission_button.dart` — 无障碍按钮实例
- `scripts/check_quality.py` — Python 3 跨平台门禁脚本（不做自动修复）
