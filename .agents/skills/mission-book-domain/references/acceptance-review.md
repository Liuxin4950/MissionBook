# Mission Book Agent 变更审查与验收

## 规范查阅顺序

1. 《领域模型》：术语、状态、操作合法性、END 分流、时间、截止。
2. 《数据模型》：事实字段、来源、查询投影、禁止重复持久化。
3. 《数据落地与平台》：SQLite、迁移、附件、导入、重启、通知、Windows/Android。
4. 《本地应用规格》：当前应交付闭环及最终完成定义。
5. 《界面与交互》：页面操作，不能覆盖领域规则。
6. 《未来方向》：当前不实现的 AI/Plan 等能力。

> 这些文件在用户本次上传时为目标设计文档；本 Skill 不代表已经有实现进度。若进入真实仓库，应读仓库版本。

## 审查 Checklist

- [ ] 操作前置状态与 `MissionPhase` 查询一致且由事实派生。
- [ ] Event 仅 START/PAUSE/RESUME/EXTEND/END 且单 Mission sequence 连续。
- [ ] START/RESUME 串行写事务内检查全局 RUNNING 唯一。
- [ ] END 用户自报与 Evidence/AI Evaluation 分离；NOT_COMPLETED 写失败记录。
- [ ] REQUIRED_EVIDENCE 到期按提交事务时刻判定且补算幂等。
- [ ] OPTIONAL_EVIDENCE `submitOptionalEvidence` 字段只在允许组合使用。
- [ ] PAUSED/EXTEND/Focus 原计划/当前预算口径测试准确。
- [ ] 重启状态完全从事件和正式事实恢复；通知不成为领域唯一状态源。
- [ ] 旧 ScheduleRevision、ExecutionEvent、Evidence、FailureRecord 不可覆盖或删除。
- [ ] SQLite 有外键、唯一索引和真实数据库迁移测试。
- [ ] 草稿不伪装正式 Evidence，文件提交与数据库事务的失败策略清晰。
- [ ] GoalNode 同 Goal、无环、归档子树与历史关联保持。
- [ ] 平台缺少权限时保留手动业务能力，UI 准确反映可用性。
- [ ] 不自动增加 AI 评价、计划、记忆等未交付对象。

## 反例级测试集

| 测试 | 预期 |
| --- | --- |
| 两个 Mission 同时 START | 恰好一个 RUNNING；另一个拒绝且无不完整事件 |
| 用户连点暂停两次 | 只有一次 PAUSE；第二次返回可解释的拒绝/幂等结果 |
| PAUSE 20min 后 RESUME | Focus 只统计 RUNNING 时段 |
| EXTEND +30min 在 PAUSED | 执行仍 PAUSED，原 plannedDuration 不变 |
| REQUIRED END(COMPLETED) 在截止后 | END + 唯一超时 FailureRecord 同事务；CLOSED；自报仍 COMPLETED |
| 提交材料时达到截止，和补算并发 | 只可能首次材料提交或截止失败之一，不可能两者都成功 |
| 任意证据修正 | 原证据和首次时间保留，无修正链分叉 |
| 后台 notification 延迟 START | 重查最新事件/排期后执行，不按过时 ViewModel 内存状态写入 |
| UI 截止时间跨夏令时转换 | 使用排期 IANA 时区的下一个日历日 00:00，不盲加 24h |
| 未开始任务取消 | CANCELLED，无 END，无 FailureRecord |

## Agent 报告格式

使用“事实（引用哪份规格、哪条内容） -> 推理（实现应该如何满足） -> 风险（尚未验证的边界） -> 代码文件 -> 验证命令/真实结果 -> 未完成验证项”的形式。不能把静态分析通过称为全部验收通过。
