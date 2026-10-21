---
name: dart-language-official
description: Apply and review official Dart language syntax, static semantics, type/null safety, patterns, records, library/API design, Effective Dart naming, docs, formatting and linter practices. Use when writing, fixing, refactoring, teaching or reviewing any Dart code, including Flutter and tests. Verify SDK constraints before suggesting new syntax.
compatibility: Dart SDK and optional Flutter SDK recommended; reference-only operation works offline.
metadata:
  version: "1.0.0"
  reviewed: "2026-10-21"
  language: "zh-CN"
---

# Dart 语言语法与代码语义规范

## 启动条件

适用于任何 Dart 文件的新建、修改、重构、审查、技术解释以及 SDK 迁移。此 Skill 与 Flutter 或项目业务 Skill 可并用。

## 强制执行流程

1. **先检查版本。** 读取 `pubspec.yaml` 的 `environment.sdk`、`dart --version`、`flutter --version`（如有）。对 `records`、`patterns`、`class modifiers`、`extension types`、formatter 特性核对语言最低版本。环境不可执行时，标记“未编译验证”。
2. **先识别含义，再写语法。** 澄清实体身份、是否可空、单位、时区、错误语义、操作副作用、返回契约、身份/值对象、状态机、同步/异步、可变/不可变。名称必须与领域术语对应。
3. **语法审查。** 依 `references/syntax-index.md` 逐类覆盖相关 Dart 语言规则；需要时阅读 `references/types-nullability.md`、`references/async-errors.md`；不要套用 Java/Kotlin/TypeScript 语法。
4. **风格/API 审查。** 依 `references/effective-dart.md` 审查命名、库、格式、文档、API 设计。语言可编译不意味着符合 Effective Dart。
5. **验证。** 先 `dart format --output=none --set-exit-if-changed .`，再 `dart analyze --fatal-infos`，再运行相关测试。Flutter 仓库按 Flutter Skill 使用 `flutter analyze` / `flutter test`。若未安装 SDK，不虚构结果。
6. **报告。** 明确标注 `(LANGUAGE)` 编译器/语言规定、`(OFFICIAL_GUIDANCE)` 官方建议、`(TEAM)` 可更改的本仓库约定、`(DOMAIN)` 业务约束；注明验证命令与结果、无法验证的条件。

## 高优先级规则

- `(LANGUAGE)` 尊重类型系统、空安全、可见性、覆盖签名、模式穷尽性和类修饰符边界；以当前 SDK 的实际诊断为准。
- `(OFFICIAL_GUIDANCE)` 类型 `UpperCamelCase`；函数/变量 `lowerCamelCase`；文件/包 `lowercase_with_underscores`；私有成员前缀 `_`（**库私有**，不是类私有）。
- `(OFFICIAL_GUIDANCE)` `DO`/`DON'T` 优先于 `PREFER`/`AVOID`；有冲突时阅读原始完整上下文，不以“官方必须”概括建议。
- `(OFFICIAL_GUIDANCE)` public API 用 `///` 文档，描述含义和不变量；避免重复代码字面信息。普通 `//` 不替代 doc comment。
- `(TEAM)` 非明确请求，不要求每一行都带注释；需要逐行注释时优先使用整齐尾随注释且保留 formatter 可管理性。不能牺牲清晰度强制尾随注释。
- `(TEAM)` 禁用未经论证的 `dynamic`、未审查的 `!`、不可解释的布尔开关与魔法数；优先具名的类型、枚举和命令。
- `(DOMAIN)` 状态与时间类派生数据先识别事实来源，禁止为 UI 方便平行保存第二套可写状态。

## 按需读取索引

- 语法全貌、语言特性链接与版本：`references/syntax-index.md`
- 代表性语法和操作语义配方：`references/language-recipes.md`
- 类型、Null Safety、类型转换、泛型：`references/types-nullability.md`
- Future/Stream/isolates/异常：`references/async-errors.md`
- Effective Dart 命名、文档、API：`references/effective-dart.md`
- 语义契约与审查示例：`references/semantic-contracts.md`
- SDK 与 Formatter 兼容：`references/versioning.md`
- 官方文档与适用性：`references/sources.md`
- 可运行性需用实际 SDK 检查的示例：`assets/examples/dart_semantics_example.dart`
- 静态分析模板：`assets/analysis_options.yaml`

## 可接受的任务输出

代码应提供完整上下文；命名与返回类型可解释；错误传播明确；测试覆盖合法/非法/边界输入；列出构建/分析结果，不以“已核对”替代命令记录。无法确认的语言特性先查官方页再使用。
