# Flutter 第一手资料与权威层级

官方文档（已经浏览核对入口）：

- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide) — UI/Data/可选 Domain、职责分离。
- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations) — 强推荐/推荐/条件适用；明确不是框架语法强制。
- [Common architecture concepts](https://docs.flutter.dev/app-architecture/concepts) — 单一事实源、单向数据流、不可变 state。
- [Architecture case study](https://docs.flutter.dev/app-architecture/case-study) — 官方完整参考结构示例。
- [Flutter testing overview](https://docs.flutter.dev/testing/overview) — 单元/Widget/集成测试定义。
- [Widget tests](https://docs.flutter.dev/cookbook/testing/widget/introduction) — `testWidgets`、`WidgetTester`。
- [Accessibility](https://docs.flutter.dev/ui/accessibility) — 出厂前的无障碍检查与平台要求。
- [Assistive technologies](https://docs.flutter.dev/ui/accessibility/assistive-technologies) — Semantics 与屏幕阅读器。
- [Semantics Widget API](https://api.flutter.dev/flutter/widgets/Semantics-class.html) — Widget API（依 SDK 版本差异）。
- [BuildContext API](https://api.flutter.dev/flutter/widgets/BuildContext-class.html) — context 生命周期。

可扩展的第三方技术（若工程采用，必须独立查对应版本）：

- [Drift documentation](https://drift.simonbinder.eu/) — SQLite 映射、事务、迁移，需要具体项目版本核对。
- [SQLite transaction docs](https://www.sqlite.org/lang_transaction.html) — 数据库事务的真正语义。SQLite/Drift 与 Flutter 官方并非同一权威体系。

本包未追踪 GitHub API 或依赖包今天的最新 tag；实施时先读取本地锁文件，避免幻想版本兼容。
