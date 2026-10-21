# Effective Dart：官方风格、文档、用法与 API 设计

参考：[Effective Dart](https://dart.dev/effective-dart) · [Style](https://dart.dev/effective-dart/style) · [Documentation](https://dart.dev/effective-dart/documentation) · [Usage](https://dart.dev/effective-dart/usage) · [Design](https://dart.dev/effective-dart/design)

## 优先级与语气

官方术语 `DO` / `DON'T` / `PREFER` / `AVOID` / `CONSIDER` 有不同强度。Agent 不能把所有建议称为“编译器必须”，也不能将 `CONSIDER` 作为无例外审批门槛。Flutter 官方工程建议另有 `Strongly recommend` / `Recommend` / `Conditional` 三档。

## 命名参考表

| 语义对象 | 优先写法 | 容易产生歧义的写法 | 说明 |
| --- | --- | --- | --- |
| Dart 类型（Class/Enum/typedef） | `MissionScheduleRevision` | `mission_schedule_revision` | 类型 `UpperCamelCase` |
| 变量 / 函数 | `plannedDurationMinutes` | `duration`, `PlannedDuration` | 局部值 `lowerCamelCase`；单位属于契约 |
| bool 属性 | `isRunning`, `hasEvidence`, `canResume` | `status`, `runFlag`, `isNotInactive` | 按可判断命题命名、推荐肯定形式 |
| 命令 | `startMission()`, `pauseMission()` | `doMission()`, `setState()` | 侧重副作用时用祈使动词 |
| 查询 | `currentSchedule()`, `calculateFocus()` | `doDuration()`, `get()` | 描述返回信息；官方建议避免冗余 `get` 前缀 |
| 文件 | `mission_schedule_revision.dart` | `MissionScheduleRevision.dart` | `lowercase_with_underscores` |
| 常量 | `maxAttachmentBytes` | `MAX_ATTACHMENT_BYTES` | Dart 规范推荐 lowerCamelCase（与 Java 风格不同） |
| 私有成员 | `_eventsByMission` | `privateEvents` | `_` 是**library-private**，不是类级私有 |
| 类型参数 | `T`, `TValue` | `dataTypeThing` | 清晰、习惯一致，不强加每处同一命名 |
| Record | `(String id, int revision)` | `(String, int)` | 仅临时聚合，长期领域实体优先命名类型 |
| 时间变量 | `occurredAtUtc`, `scheduledDate` | `time`, `date` | 项目级语义约束，非 Effective Dart 条文 |
| 单位变量 | `focusMilliseconds`, `plannedDurationMinutes` | `focus`, `limit` | 项目级语义约束 |

## 重点规则

1. 类型 `UpperCamelCase`；库/文件/目录 `lowercase_with_underscores`；成员与顶层标识符 `lowerCamelCase`。
2. 使用同一概念的一致词汇；避免不必要的缩写；最能区分对象的名词放在后面，避免 `Obj`、`Data`、`Manager` 空泛后缀。
3. Bool 用肯定表达；不要将相反状态混写。`canStart` 不能表示“已经在运行”，它是操作能力而非执行事实。
4. 有副作用的方法优先祈使动词；计算性质的查询更接近名词短语或非祈使词组。
5. public API 优先 `///` 文档；写清前置条件、时区/单位、异常、不可逆性；首句概要独立成段。
6. 代码注释解释为什么与隐含契约，而不只是重复代码字面意义；代码结构可表达的意思用命名表达。
7. 官方 formatter 是 `dart format`，不要以对齐空格或手调尾随逗号对抗它。Dart 3.7 新格式的尾逗号可能由 formatter 自动调整。
8. import/export 保持接口边界；避免不必要地暴露私有实现；`part` 需确有必要。
9. `const`、类型推断、函数 tear-off、集合控制流等按官方 Usage 做语义等价的简化，不为了“新特性”而降低可读性。

## 注释冲突处理（团队例外）

某些团队希望“每行行尾对齐注释”，这不是 Effective Dart 官方强制。若用户明确要求此格式，可以在学习示例中尽量保持短而对齐的行尾说明；**对公开 API 仍优先 `///`**，对生成代码、简单括号与 `dart format` 自动处理区域不强求。代码含义应由标识符首先表达，避免注释与逻辑更新脱节。

## 审查提示

- 标识符是否与业务领域已有标准词汇一致？
- 该名字表示事实、可行性、请求还是推断？
- 可变值、时间单位和合法范围有无自解释的契约？
- 文档是否声称了没有实现的功能（例如“自动验证通过”）？
- `dart format` 后是否出现大量不稳定注释对齐，影响差异审查？
