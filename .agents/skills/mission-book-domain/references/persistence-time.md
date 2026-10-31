> 历史摘录（2026-10-21）：以下阶段数量、STOP 缺失、材料限制、AI 范围和计时公式均可能过时，不可作为当前规格。先按 SKILL.md 阅读现行架构及源码；本文仅保留历史来源。

# Mission Book 时间、事务、SQLite 和平台边界

来源：上传《领域模型》§4/§6/§8、《数据模型》§3–§6、《数据落地与平台》§1–§7。

## 时间与 Focus 精确定义

```text
Actual Start              = START.occurredAt
Actual End                = END.occurredAt（可空）
Original Planned Duration = START 所绑定排期 revision 的 plannedDurationMinutes
Elapsed                   = (END.occurredAt or now) - START.occurredAt
Paused                    = 所有 PAUSE -> RESUME/END/now 片段之和
Focus                     = Elapsed - Paused
Granted Extension         = EXTEND.grantedDurationMinutes 总和
Actual Overtime           = max(Focus - Original Planned Duration, 0)
Current Budget            = Original Planned Duration + Granted Extension
```

数值内部建议整数毫秒计算，展示才换算分钟；无 START 的 Mission 没有执行原计划基准，只展示最新排期计划时长。PAUSED 时即使关闭 app 也不增加 Focus；RUNNING 即使 app 关闭仍按事件时刻持续累计，但 UI 定时器仅用于刷新。

## 时区 / 计划日期

- `occurredAt`、`evidenceDeadlineAt` 为 UTC 绝对时刻；统一毫秒精度。
- `scheduledDate` 是排期 IANA 时区内的日历日期字符串 `YYYY-MM-DD`；不能直接把无时区日期当 UTC 00:00。
- 排期默认截止：在该时区 `scheduledDate` **下一天**的 00:00，按真实时区规则转为保存的 UTC instant；不得简单加 24 小时（夏令时可能导致差别）。
- FIXED `fixedStartAt` 是实际绝对时刻，必须与排期日期/时区匹配；FLEXIBLE 只比较排期时区内的日历日期。
- 当前编辑新的排期 revision 时默认截止按新日期重设，旧历史保留；开始后锁定。
- 系统时间回拨时 UI 查询用 `max(now, latestEvent.occurredAt)` 暂时截断显示，不产生负 Focus；**写事实仍拒绝倒退发生时间**。

## SQLite / Drift 模式

- 八个领域表按阶段创建；不要提前创建隐藏状态表或 AI 评价表。
- 稳定字符串保存 enum（不是 index），ID 为客户端生成唯一字符串。
- 关键唯一约束：`execution_plans.mission_id`；`mission_schedule_revisions(mission_id,revision_number)`；`execution_events(mission_id,sequence)`；START/END 的 per-Mission 唯一；`failure_records(mission_id,trigger)`；`evidence.supersedes_evidence_id` 非 null 值唯一。
- 必须启用外键；不对正式历史设置级联物理删除。SQLite 部分唯一索引/触发器与 Drift 表达方式以实际版本测试确认。
- **跨 RUNNING**、跨表同一 Mission、合法连续事件序列等不能仅靠普通字段校验；在获得串行写权限的事务中重读当前事实、校验、再写入。
- `StartMission`、`ResumeMission`、`EndMission`、`FinalizeEvidenceSubmission`、`ApplyEvidenceDeadline` 必须针对两个竞争客户端/通知重放测试。串行化不能只依赖 UI 按钮 disable。

## 截止与提交的竞争

1. 在事务前完成附件文件准备，不将系统文件选择跨越数据库事务。
2. 获取独占/串行写入权限后在事务内部重新查询 Mission 当前事实。
3. 事务内捕获**一次**业务时间；用它判断截止与赋值 `submittedAt`，不能重用事务前的旧时间。
4. 已到截止：同一事务仅写唯一超时 FailureRecord，**不写首批正式 Evidence**；返回“已超时”。
5. 未到截止：同一事务写整批 Evidence，全部使用同一 submittedAt；任何一条非法则不得半批提交。
6. 事务持久化后再对账通知。通知失败不回滚事实；附件草稿准备失败不造成历史污染。

## 文件/导入/备份/迁移

- 附件最大 20 MiB；来源文件复制到沙盒相对 `attachments/<missionId>/<attachmentId>.<ext>`，拒绝绝对路径、`..` 或 content URI 作为存储键；图片真实解码校验。
- 导入 `goal-outline` JSON 限 UTF-8 2 MiB、500 节点、深度 12；所有未知字段拒绝，必须预览并用户确认后原子提交 Goal + Node Tree。
- schemaVersion=1 为首个实现切片。之后已有数据的每次架构改变必须迁移测试，不能删库重建。
- 数据库快照必须与 WAL 等一致性要求兼容；备份包括正式附件和 manifest，不包含草稿。导入恢复不在当前范围。
- 通知在 Android/Windows 的能力受设备、权限、打包方式影响；不能把通知送达当作真实计时事实。

## 来源之外的实现细节

本 Skill 不强制具体 Drift API、IANA 时区库或 SQLite 互斥实现；它们依赖所采用版本。Agent 在看到实际 `pubspec.lock` 后必须查对应版本文档并执行真实 SQLite 竞争测试；不能只凭以上文字证明事务隔离已经正确。
