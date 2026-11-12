# 目标计划导入架构

> 把外部 AI 生成的课标 JSON 校验、预览、用户确认后原子创建目标、节点树和可执行任务；确认前不写正式业务。

## 目录

| 文档 | 内容 |
| --- | --- |
| [协议与校验](协议与校验.md) | 两条协议字段、`GoalImportLimits` 上限、默认值展开、时刻/时区/截止校验、`MissionCreation` 组装 |
| [暂存事务与规模](暂存事务与规模.md) | 独立暂存库与作业状态、流式解析、原子导入事务、回执与内容去重、复核门槛、取消/恢复/规模预算 |

## 模块职责

目标计划导入把用户选取或粘贴的 JSON 计划转成正式业务事实：一个 Goal、完整 GoalNode 树，以及已排到具体日期的 Mission（各含一份 ExecutionPlan 和 revisionNumber=1 的 MissionScheduleRevision）。它只创建计划信息，不携带 START/END、材料或失败事实；导入后的执行、报告与材料仍由真实操作产生。

模块覆盖两条协议：仅大纲 `mission-book.goal-outline` v1（只建目标与节点）和完整目标包 `mission-book.goal-package` v1（建目标、节点和万级任务）。代码横跨 `application/goals` 的解析与编排、`data/goal_import` 的独立暂存库、`data/repositories` 的原子导入仓储、`domain/rules` 与 `domain/entities` 的协议校验，以及 `presentation/goals/form` 的导入工作区。目标树与节点的日常管理（展开、进度、建任务、归档）见[任务与材料](../任务与材料/README.md)，本模块只负责从文件创建。

## 文件地图

| 文件 | 职责 |
| --- | --- |
| [goal_package_import_service.dart](../../../../lib/application/goals/goal_package_import_service.dart) | 目标包编排：流读、暂存、完整校验、预览、恢复、复核与提交；确认前不写正式业务 |
| [goal_package_parser.dart](../../../../lib/application/goals/goal_package_parser.dart) | 逐块 JSON 解析，只保留单条节点/任务，不建整包 AST；强制协议字段与规模上限 |
| [goal_outline_parser.dart](../../../../lib/application/goals/goal_outline_parser.dart) | 仅大纲 v1 严格解析（2 MiB、500 节点、12 层），确认前不写业务数据 |
| [goal_file_picker.dart](../../../../lib/application/goals/goal_file_picker.dart) | `GoalFilePicker` 契约，只读用户主动选取的 JSON，返回可流读的 `GoalImportSource` |
| [goal_package_rules.dart](../../../../lib/domain/rules/goal_package_rules.dart) | 协议字段校验、默认值展开与 `MissionCreation` 组装；不写库、不判定当前可执行 |
| [goal_package_import.dart](../../../../lib/domain/entities/goal_package_import.dart) | `GoalImportLimits`/`Source`/`Options`/`Preview`/`Result`/`Entry`/`Window`/`Cancellation`/`Exception` |
| [goal_package_repository.dart](../../../../lib/domain/repositories/goal_package_repository.dart) | `GoalImportStage` 暂存边界与 `GoalPackageRepository` 回执/查重/复核/导入契约 |
| [goal_import_database.dart](../../../../lib/data/goal_import/goal_import_database.dart) | 独立持久暂存库 `mission_book_goal_import`：单作业、分页、封存与字节预算 |
| [drift_goal_package_repository.dart](../../../../lib/data/repositories/drift_goal_package_repository.dart) | 业务库写锁内重查回执与排期，目标/节点/任务/回执一次提交 |
| [goal_service.dart](../../../../lib/application/goals/goal_service.dart) | 目标管理入口，暴露可空 `packages`（`GoalPackageImportService`）供导入工作区使用 |
| [goal_import_page.dart](../../../../lib/presentation/goals/form/goal_import_page.dart) / [goal_import_section.dart](../../../../lib/presentation/goals/form/goal_import_section.dart) | 导入工作区入口：原位粘贴/选文件、预览、确认；大纲直接处理，目标包委托下一行 |
| [goal_package_import_section.dart](../../../../lib/presentation/goals/form/goal_package_import_section.dart) | 目标包导入 UI：prepare → preview → review → commit、导入选项与分页预览 |

装配见 [app.dart](../../../../lib/app.dart)：`GoalPackageImportService(stage: GoalImportDatabase(), repository: DriftGoalPackageRepository(_database), onCommitted: ...)` 注入 `GoalService.packages`；提交成功后回调 `GoalService` 与 `MissionService` 的 `refreshAfterExternalCommit`。

## 两条导入路径

```text
仅大纲 goal-outline v1（小文件，内存解析）
  GoalImportSection → GoalOutlineParser.parseText/parseBytes（2 MiB / 500 节点 / 12 层）
    → GoalOutlineImport 树预览 → 用户确认 → GoalOutlineCreation
    → GoalService 单事务创建 Goal + GoalNode（不建任务）

完整目标包 goal-package v1（万级任务，流读 + 磁盘暂存）
  GoalImportSection → GoalPackageImportSection → GoalFilePicker.pickSource / 粘贴
    → GoalPackageImportService.prepare（独立暂存库，详见下文）
    → 预览 → 用户选项 → service.review → service.commit → 原子导入
```

`GoalImportSection` 是共用入口：`service.packages` 为空时只走大纲；非空时把目标包委托给 `GoalPackageImportSection`。两条路径都遵守“确认前零写入正式业务”。

## 目标包数据流概览

```text
用户选文件/粘贴 → GoalImportSource（流，不预分配整包字节）
  → GoalPackageImportService.prepare
    → GoalImportDatabase.begin（独立暂存库，单作业 READING）
    → 逐块流读（65536 字节）→ GoalPackageParser.add（字段/规模上限）→ stage.append（≤100/批）
    → parser.finish → GoalPackageRules.validateRoot → stage.setRoot（VALIDATING）
    → 分页校验节点 validateNode → payloadHash / contentHash（canonicalJson + sha256）
    → repository.receipt（packageId 幂等）→ 分页 resolveMission + creation 校验 → stage.resolveBatch
    → repository.duplicateContent（内容查重）→ stage.seal（READY）→ GoalImportPreview
  → 用户确认选项 → service.review → repository.review（截止/过期/自动开始/冲突）
  → service.commit → repository.importPackage
    → AppDatabase.transaction → 写锁 → 重查回执 → assertReady → 预览一致性
    → 插入 Goal + 分页节点 + 分页任务（Mission/ExecutionPlan/Schedule）→ 最终复核 → ImportReceipt
    → onCommitted → GoalService / MissionService.refreshAfterExternalCommit
  → stage.discard（清理暂存；异常不改已提交事实）
```

字段、上限与校验规则见[协议与校验](协议与校验.md)；暂存库、流式解析、原子事务、回执去重、复核门槛与取消恢复见[暂存事务与规模](暂存事务与规模.md)。

## 陷阱与约束

- 确认前零写入：`prepare`/`review` 只写独立暂存库，正式业务查询不读暂存；只有 `commit` 进入业务库事务。
- 暂存库与业务库分离：`GoalImportDatabase`（`mission_book_goal_import`）单作业（singleton），Web 必须持久存储，落到 inMemory 直接拒绝。
- 规模上限由 `GoalImportLimits` 固定，文件不能覆盖；协议允许万级任务不代表设备验收已通过。
- 幂等靠持久回执：`packageId + payloadSha256`；同编号不同内容报 `PACKAGE_ID_CONFLICT`，同内容不同包由 `duplicateContent` 提示。大纲的 `packageId` 取 `jobId`。
- 原子提交：目标/节点/任务/方案/排期/回执一次事务，写锁后重查；BEGIN 竞争由 `AppDatabase` 统一恢复，不重放已运行的导入（见[调度与执行事务](../任务与材料/调度与执行事务.md)）。
- 导入只创建计划，不写执行事件/材料/失败；FIXED 任务落在当前时段且允许自动开始时，提交后现有调度器可能立即 START，不能保证“导入后永远待开始”。
- 时间门槛在 `review` 与最终提交各按当前时钟检查一次；创建时间保持同一值。
- 跨模块装配、导入关闭顺序见[调用与失败恢复关系](../../调用与失败恢复关系.md)；术语见[术语](../../术语.md)。历史设计与外部 AI 提示词见[归档](../../../设计/目标计划导入/总览.md)。