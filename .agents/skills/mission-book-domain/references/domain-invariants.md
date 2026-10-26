# Mission Book 领域不变量与术语审查表

来源：2026-10-21 上传《领域模型》§1–§9、《数据模型》§1–§6、《产品纲领》§4–§6。**这些文件是目标需求，不代表当前代码已实现。**

## 八个当前核心对象

`Goal`、`GoalNode`、`Mission`、`MissionScheduleRevision`、`ExecutionPlan`、`ExecutionEvent`、`Evidence`、`FailureRecord`。当前没有内置 AI 的 `Evaluation`、`Plan`、`ContextState`、`Reflection` 或掌握度评分。`ExecutionHistory` 是已有 ExecutionEvent 的时间线，不另建核心表。

## 六个派生 MissionPhase

| Phase | 唯一事实来源 | 注意事项 |
| --- | --- | --- |
| NOT_STARTED | 未取消、无 START | 可有多个排期版本；FIXED 到点且仍在计划时段内自动开始，错过整个时段不补造历史 |
| RUNNING | 有 START，无 END，忽略 EXTEND 后最后切换为 START/RESUME | 全局最多一个 RUNNING |
| PAUSED | 有 START，无 END，忽略 EXTEND 后最后切换为 PAUSE | 可以有多个 PAUSED；不累计 Focus |
| EVIDENCE_PENDING | END=COMPLETED，策略要求后续材料且首批未提交、未跳过、未超时 | 不等于任务仍在运行 |
| CLOSED | 有 END，且符合结束/材料提交/可选跳过/强制超时 | `COMPLETED` 不等于验证通过 |
| CANCELLED | 开始前 `cancelledAt` | 无 END，不写失败记录 |

**没有独立可写 `phase` 字段。** 每一个查询/Widget/通知统一用事实投影函数；禁止缓存变成新的可写事实源。

## 事件契约

| Command | 允许前置 Phase | 事实改变 | 禁止的隐含效果 |
| --- | --- | --- | --- |
| StartMission | NOT_STARTED | START + 绑定最新排期 revision | FIXED 不能提前 START，到点由同一事务自动开始；不能挤走另一 RUNNING |
| PauseMission | RUNNING | PAUSE | 不产生 END |
| ResumeMission | PAUSED 且无其他 RUNNING | RESUME | 不修改原 START |
| ExtendMission | RUNNING 或 PAUSED | EXTEND(正整数分钟) | **不**恢复运行、不改原 plannedDuration |
| EndMission | RUNNING 或 PAUSED | END + 完成报告；按需要写 FailureRecord | 不生成 Evaluation；未完成原因不写 END.reason |
| CancelMission | NOT_STARTED | `cancelledAt` | 不制造 END 或 FailureRecord |
| FinalizeEvidenceSubmission | EVIDENCE_PENDING 且截止尚未生效/可选材料 | 事务内保存首批非空 Evidence -> CLOSED | 不把草稿直接当正式历史 |
| SkipOptionalEvidence | EVIDENCE_PENDING 且 optional | `evidenceWaivedAt` | 强制材料不得跳过 |
| ApplyEvidenceDeadline | required & 到截止且仍 pending | 唯一 FAILURE，关闭 | 不覆盖 END 自报结果 |

事件类型只有 START、PAUSE、RESUME、EXTEND、END；按 `sequence` 从 1 连续增长。每 Mission 最多 START/END 各一次。旧按钮/通知 action 必须事务内重验状态，不以 ViewModel 当前 bool 为事实。

## END 分流矩阵（必须做表驱动测试）

| END report | verificationPolicy | submitOptionalEvidence | 结果 |
| --- | --- | --- | --- |
| NOT_COMPLETED | 任意 | 不适用 | CLOSED + NOT_COMPLETED FailureRecord |
| COMPLETED | SELF_REPORT | null | CLOSED |
| COMPLETED | OPTIONAL_EVIDENCE | false | CLOSED |
| COMPLETED | OPTIONAL_EVIDENCE | true | EVIDENCE_PENDING |
| COMPLETED | REQUIRED_EVIDENCE | null，未到截止 | EVIDENCE_PENDING |
| COMPLETED | REQUIRED_EVIDENCE | null，已到截止 | CLOSED + deadline FailureRecord |

`submitOptionalEvidence` 仅在 `END + COMPLETED + OPTIONAL_EVIDENCE` 时为非 null bool，其余必须为 null。

## Goal 与 GoalNode

- Goal 状态：ACTIVE/PAUSED/ACHIEVED/DROPPED；只有 ACTIVE 允许创建关联新 Mission，但旧 Mission 仍执行/留历史。
- GoalNode 构成同 Goal 的无环树；删除是归档整棵子树，非物理删除；关联历史保留。
- 覆盖率只按有效节点中存在 `END(COMPLETED)` 的直接关联 Mission 计数；不能推断目标达成或知识掌握。0 有效节点显示“暂无节点”，不显示 100%。

## Evidence

- Draft 只是未正式提交的 UI 编辑数据，可在异常退出后丢失；Formal Evidence 按批次追加、不可覆盖或删除。
- 首批至少一条有效材料，同事务落库并共享 `submittedAt`；只有 `EVIDENCE_PENDING` 可首提。
- 更正正式材料是 `supersedesEvidenceId` 链，指向同 Mission 的当前有效项；不可分叉、跨任务、循环。修正不改首提时间/Phase/原始截止结果。
- `END=COMPLETED` 与 Evidence 提交、AI Evaluation 完全不同；结果页不能显示“AI 审核通过”。

## 失败记录

- `NOT_COMPLETED` 在 END 同事务记录失败，触发时刻即 END 时刻。
- required Evidence 超时 `occurredAt=max(deadline, END.occurredAt)`；重复截止补算只保存一个对应 trigger。
- CANCELLED 不是执行失败；材料超时不篡改用户已报告 COMPLETED。

## 先修复规格冲突，再改实现

凡真实操作无法按照这些规则表达，先查领域模型文档唯一来源；如确需改变产品需求，应发起规格变更，将领域规则、数据库、页面与验收一起更新。不要绕过规则填补假状态。
