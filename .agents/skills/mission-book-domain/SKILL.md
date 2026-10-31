---
name: mission-book-domain
description: Review MissionBook facts, derived phases, command transactions, evidence, scheduling, notifications and their UI against current code and the user's latest requirements.
metadata:
  version: "1.1.0"
  reviewed: "2026-10-31"
  scope: "project-only"
---

# MissionBook 领域与持久化审查

## 来源与边界

这是项目辅助审查索引，不是 Dart/Flutter 官方规范，也不是冻结的产品规格。用户已明确旧领域文档部分过时或错误；用户最新决定优先。先读 `docs/README.md`、`docs/架构/总览.md` 与涉及模块，再核对当前源码和调用链。`docs/历史文档/` 及本技能 references 的旧摘录仅供追溯，不能覆盖现行实现或阻止新需求。

## 当前检查入口

- 事件、阶段与计时：`execution_event.dart`、`mission_phase.dart`、`execution_event_rules.dart`、`execution_time_rules.dart` 及 `MissionDetail`。
- 任务写入：`MissionService`、`DriftMissionRepository` 及其 command / execution / scheduling / evidence 协作者。
- 材料与记录：`docs/架构/前端/任务与材料/总览.md`；材料可以在执行前保存，关联已有记录要经过统一材料命令。
- 助手与总结：`docs/架构/前端/助手与总结/总览.md`；已有 AI 能力需按真实代码审查，不能按旧“未来能力”排除。
- 数据库：`AppDatabase.schemaVersion` 与实际迁移，不假设固定八张表或旧版本。

## 关键约束

- MissionPhase 由完整事实派生，不建立可写 phase。当前六种事件包含 STOP，七种阶段包含 reportPending；限定的 derivePreEndMissionPhase 不代替完整查询。
- STOP 是到点冻结计时，END 是用户确认结果。用户完成报告、材料充分性、模型评价与用户掌握分别判断。
- PAUSE 不累计 Focus；EXTEND 不隐式恢复计时，时钟回拨不生成负时长。
- 事件、材料修正和排期保留历史；原始记录内容与任务材料引用区分，不能重复复制正文。
- 写事务取得锁后重读事实及预期序号，重复动作复用身份与回执。系统通知和助手调用业务服务，不旁路写事实。
- 到期 STOP 的独立提交不能随旧报告冲突回滚。超时材料保存后保留失败事实，幂等重试返回相同语义。
- 普通查询保持纯读取；会维护事实的应用查询明确使用 AndReconcile 命名。
- 不为未实现能力预建空表、空接口。已有能力重构保留持久化协议和用户数据兼容。

## 验证与输出

先说明具体操作的前置条件、事实改变、事务、幂等身份与失败结果。按受影响风险选择边界、并发、重启、时钟回拨和资源释放测试；不要机械为可逆的纯样式修改增加测试。

引用实际拥有行为的源码及回归结果。测试通过、平台构建、真实设备验收和用户掌握分别说明，不用历史文档或纯枚举测试冒充完整闭环。
