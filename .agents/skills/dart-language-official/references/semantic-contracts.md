# 代码语义化：可审计的契约，而不是统一命名风格

## 语义的五个层级

1. **语言语义（language semantics）**：程序的类型、求值顺序、作用域、异常、异步和类能力由 Dart 定义；依官方语言文档与 SDK 验证。
2. **API 语义（contract semantics）**：参数、返回、异常、副作用、幂等和不变量，由包接口与实现决定；有效命名只能辅助理解。
3. **领域语义（domain semantics）**：例如 Mission 的 `END` 表示报告完成，不能偷换成 Evidence 已提交；由产品规格与测试证明。
4. **数据语义（persistence semantics）**：真相来源、历史可追加性、事务、唯一约束、时间保存、迁移，由数据库语义与项目设计决定。
5. **无障碍语义（Flutter Semantics）**：为屏幕阅读器等辅助工具表达控件角色、标签、状态、操作，不是 Dart 的语言级“语义化”。

## 领域命名模板

| 不良抽象 | 语义更精确的候选 | 需要确认的语义 |
| --- | --- | --- |
| `setMissionDone()` | `reportMissionCompleted()` | 是用户报告还是客观验证？ |
| `addMinutes(int value)` | `grantExtensionMinutes(int positiveMinutes)` | 是否只修改预算，不改变 Focus？ |
| `duration` | `plannedDurationMinutes` / `focusMilliseconds` | 原计划/当前预算/实际投入的区分 |
| `isFinished` | `hasEndEvent` / `isClosed` | 结束报告与后续材料流程不同 |
| `saveEvidence()` | `finalizeEvidenceSubmission()` | 临时草稿与正式提交不同 |
| `validateGoal()` | `parseGoalOutline()` / `validateGoalOutline()` | 解码与领域校验是否分开？ |
| `date` | `scheduledLocalDate` / `occurredAtUtc` | 日历日期不是 UTC instant |
| `retry()` | `createMissionRetryFrom(sourceId)` | 新记录还是重放旧命令？ |

## 审查流程

1. 把名词分为实体/值/事件/快照/投影/命令；列出身份和生命周期。
2. 把 API 规则写成“在前置条件 P 下，执行操作 O 后保存事实 F；否则返回失败 R”。
3. 把 `DateTime` 字段注明绝对时刻或本地日历概念，并明确 UTC/时区、单位。
4. 保证 View/DB 别名与领域名称保持映射一致；若数据库命名为 snake_case，不意味着 Dart 字段要改 snake_case。
5. 只持久化必要事实；投影结果从事实计算，避免双事实源互相矛盾。
6. 将限制写入适当的层次：构造器/类型保护本地不变量；事务+DB 唯一约束保护并发事实；UI 显示操作资格；测试证明整体契约。

## 对抗性测试（语义陷阱）

- 如果操作失败，数据库是否可能写了一半？
- 如果两个来源同时提交，会不会都认为自己是唯一 RUNNING？
- 如果时间回拨，派生时长会不会变负？
- 如果服务/应用重启，是否从持久化事件恢复真实状态？
- 如果文案显示“任务完成”，究竟是用户自报、材料齐备，还是经过验证？
- 如果外部 JSON 缺字段/多字段/null/嵌套超限，会不会“自动纠正”成另一种业务含义？

“命名清晰 + 分析零告警”是必要但不充分条件。应保留可核对的测试证据。
