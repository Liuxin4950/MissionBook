# Dart/Flutter 语言版本检查和变更兼容

核对文档日期 2026-10-21，不固定声称当日安装的最新版本。版本以本地项目为准。

## 语言能力最低版本（已核对官方）

| 能力 | 最低语言版本 | 来源 |
| --- | --- | --- |
| sound null safety | Dart 2.12 起启用；Dart 3 不再支持以前的语言版本 | https://dart.dev/null-safety ; https://dart.dev/resources/language/spec |
| records, patterns, switch expressions, class modifiers | Dart 3.0 | https://dart.dev/resources/language/evolution |
| 新版 tall style `dart format` | Dart 语言版本 >=3.7 | https://dart.dev/tools/dart-format |
| `formatter.page_width` | >=3.7 | https://dart.dev/tools/dart-format |
| `formatter.trailing_commas: preserve` | >=3.8 | https://dart.dev/tools/dart-format |
| 新 analyzer plugin API | SDK 3.10 起 | https://dart.dev/tools/analyzer-plugins |

**Extension types 的最低版本、宏能力以及新语法变化必须按项目 SDK 和相应功能官方文档逐条复核，不能由本表推断。**

## 验证顺序

```bash
flutter --version

dart --version

flutter pub get

# 验证 formatter 是否可用及当前项目语法配置。
dart format --output=none --set-exit-if-changed .

# 需在 Flutter package 内执行。
flutter analyze --fatal-infos

flutter test
```

通过 `pubspec.yaml` `environment.sdk` 确定包的语言版本约束，文件级 `// @dart=...` 如果存在也需要审查。执行中 `dart` 可能指向与 `flutter` 绑定 SDK 不同的位置；以当前仓库实际运行结果为准。CI 建议固定 Flutter SDK 版本，避免自动“latest”造成格式化漂移。

## 兼容迁移原则

先稳定语义，再升级工具链；全库 formatter 升级应独立于业务改动，以便 diff 审核。对 lint 的每一项新增规则确认它在目标 SDK 中存在；旧版 SDK 可能不识别新分析选项。
