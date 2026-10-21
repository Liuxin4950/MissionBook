---
name: mission-book-domain
description: Enforce Mission Book's project-specific Goal/Mission/ExecutionEvent/Evidence domain contracts, derived MissionPhase, deadlines, append-only history, Drift SQLite transactions, time zones and offline restart behavior. Use whenever an agent edits Mission Book domain logic, repositories, migration, notifications, tests, or relevant UI.
metadata:
  version: "1.0.0"
  reviewed: "2026-10-21"
  scope: "project-only"
---

# Mission Book 领域语义守卫

## 来源与边界

**此 Skill 是用户项目规则，不是 Dart/Flutter 官方规范。** 根据本次上传的《产品纲领》《本地应用规格》《领域模型》《数据模型》《数据落地与平台》《界面与交互》编写，均描述目标规格而非已实现功能。规范文档应作为仓库唯一事实源；本 Skill 是辅助检索索引，如规范升级，以项目最新文件为准。

## 先检查

1. 确认仓库存在 `领域模型.md` / `数据模型.md` / `数据落地与平台.md` 等规范的实际版本；不依赖本包静态摘录取代最新项目文件。
2. 阅读 `references/domain-invariants.md` 以核对 `MissionPhase`、事件合法性、失败与材料的区别。
3. 跨数据库、计时、时区、系统通知或附件的变更阅读 `references/persistence-time.md`。
4. 对应业务操作明确前置条件、事实变更、事务边界、并发重入与失败结果；表单/Widget 不能直接改写事件或派生阶段。
5. 测试至少覆盖边界、非法状态、重复调用、并发点击、时钟回拨、重启、超时竞争。

## 不容破坏的语义

- `MissionPhase` 是事实派生结果，**不能新建可写 `phase` 字段**。
- `END(COMPLETED)` 只是用户报告完成，不等于 Evidence 已提交，更不等于 Evaluation 或技能掌握。
- 执行事件只有 `START / PAUSE / RESUME / EXTEND / END`；失败记录不伪造 END，不可用 `CANCEL` 冒充执行事件。
- `PAUSED` 不累计 Focus；`EXTEND` 调整预算但不改写原计划或恢复计时。
- 一个 Mission 最多 START/END 各一次；全局最多一个 RUNNING；在串行写事务内重读事实并验证。双击、通知重放必须幂等。
- `REQUIRED_EVIDENCE` 过期与首次提交互斥；超时失败记录的落库不能因“提交材料失败”而回滚。
- 八张领域表仅按规格逐步添加，不提前实现 AI Evaluation 或 Plan 占位对象。

## 按需参考

- `references/domain-invariants.md`
- `references/persistence-time.md`
- `references/acceptance-review.md`
- `assets/examples/mission_phase_projection.dart`（刻意限定输入域，以业务事实作为纯函数示例）

输出应列出引用的规格章节、受影响的领域不变量、对应自动化测试及无法确认的行为。不得因“先让测试绿”篡改业务模型。
