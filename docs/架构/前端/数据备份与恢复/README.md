# 数据备份与恢复架构

> 软件设置与助手设置共用完整备份页；导出一致快照，恢复先校验、后替换，并重新装配工作区。

## 模块职责

备份包含当前数据库全部业务表及正式引用的附件，也包含撤销归档引用的原件。业务数据与材料原件是恢复必需的整体，始终一起导出；API Key 与助手设置、本机资料与偏好、离线语音模型由用户在导出前的范围选择页逐项勾选，默认带走前两类、不带模型。恢复按整份快照替换目标设备的业务数据，并写回包内实际存在的本机资源；包里没有的类别保留目标设备当前值。数据库结构的唯一来源仍为当前 AppDatabase。

## 文件地图

| 文件 | 职责 |
| --- | --- |
| [backup_service.dart](../../../../lib/application/backup/backup_service.dart) | 导出、恢复计划与结果契约；BackupResource 定义可勾选类别；ManagedBackupService 接入装配层停机和重建 |
| [local_resources_base.dart](../../../../lib/data/backup/local_resources_base.dart) | 本机资源收集与写回契约，以及包内固定入口名 |
| [local_resources_io.dart](../../../../lib/data/backup/local_resources_io.dart) | 安全存储整份替换、资料/动效/偏好文件原子写回、模型按固定清单落盘 |
| [local_resources_web.dart](../../../../lib/data/backup/local_resources_web.dart) | 浏览器只带走助手设置，文件类资源不适用 |
| [database_backup_service.dart](../../../../lib/data/backup/database_backup_service.dart) | 事务内捕获数据库快照，事务外编码并在附件互斥下读原件与本机资源，独立压缩 ZIP |
| [backup_archive.dart](../../../../lib/data/backup/backup_archive.dart) | ZIP 清单、大小、路径及 CRC 检查；将导出 INSERT 的受限字面量解析为数据 |
| [database_backup_restorer.dart](../../../../lib/data/backup/database_backup_restorer.dart) | 隔离库校验、目标快照检查、新附件键映射与事务替换 |
| [backup_validation_database.dart](../../../../lib/data/backup/backup_validation_database.dart) | 按平台选择 NativeDatabase.memory 或现有 sqlite3.wasm 的内存库 |
| [backup_file_picker.dart](../../../../lib/data/backup/backup_file_picker.dart) | 原生系统文件选择与 Web 文件选择的编译期入口 |
| [data_backup_page.dart](../../../../lib/presentation/me/data_backup_page.dart) | 统一范围说明、导出和导入页面 |
| [backup_scope_page.dart](../../../../lib/presentation/me/backup_scope_page.dart) | 导出前勾选本机资源；说明业务数据与原件为何不可取消 |
| [backup_restore_card.dart](../../../../lib/presentation/me/backup_restore_card.dart) | 选择、校验、数量与本机资源预览、替换确认与失败反馈 |
| [app.dart](../../../../lib/app.dart) | 暂停旧工作区服务，恢复后以新 Key 重建数据库、导航和助手服务 |
| [MainActivity.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/MainActivity.kt) | Android 复用系统文档选择通道；ZIP 限额由归档解码统一约束 |

## 数据流

```text
软件设置 / 助手设置 → DataBackupPage
  导出 → BackupScopePage 勾选本机资源（取消则不导出）
       → BackupExporter.create(resources)
       → AttachmentCoordinator.synchronized
       → 数据库一致事务捕获行、会话和附件引用 → 提交并释放数据库锁
       → 事务外生成 SQL / JSON、读取正式附件、按勾选收集本机资源 → compute 压缩 → 系统保存

  导入 → 选择 ZIP → compute 解码和受限 INSERT 解析
       → 当前结构的隔离内存库 → 外键 / JSON / 附件引用 / 完整任务阶段 / 会话序号校验
       → 只读预览（备份与当前数量），保存目标业务快照指纹
       → 用户确认替换 → App 暂停语音、助手、分析及提醒调度
       → 共享 AttachmentCoordinator.synchronized
          → 附件写入全新键
          → 数据库写锁 → 目标指纹检查 → 当前结构参数化批量恢复
          → 外键检查 → 单个事务提交
          → 事务提交后写回包内本机资源（安全存储整份替换、偏好文件原子写、模型按清单落盘）
       → App 重建工作区 → 正常启动恢复分析队列与系统提醒
```

任务恢复校验通过 DriftMissionRepository.findAllDetails 读取完整 MissionDetail 并访问 phase，使用现行完整派生入口，包含 STOP 与 reportPending。恢复保存原始事实，不补写执行事件。

导出期间共享附件互斥持续到原件读取完成，避免删除清理抢先移除快照引用的文件；其他数据库连接仍可在慢附件读取期间写入。导出内容保持捕获时的快照，不承诺包含之后的新修改。恢复暂停服务的关闭关系见[平台资源](../平台资源/提醒恢复与资源释放.md)。

## 格式与失败边界

- 只接受 formatVersion 1、sqlite-sql 且 databaseVersion 等于当前 schemaVersion 的完整备份，表集合和每行列集合须与当前结构一致。当前为 schema 16；没有历史数据库迁移、格式猜测或合并恢复分支。版本不一致时明确提示备份数据库版本与当前应用不一致，不静默改写或合并旧结构。
- 解码前先只读 ZIP 中央目录，拒绝目录条目与 UNIX 符号链接条目。archive 对链接条目会在 decodeBytes 内立即解压，等解码返回再检查就已经绕过声明大小防护，因此该检查必须发生在任何解压之前。
- 备份 SQL 仅作为数据载体。只解析本应用导出的 INSERT 字面量；备份中的 DDL、索引和触发器不进入连接。恢复使用当前应用自身建库代码及触发器。
- 隔离校验不写目标库和正式附件。预览后目标业务事实变化时整批拒绝；分析队列领取状态和助手写租约不计入用户业务快照。
- 附件使用新键保存，再在数据库事务中替换引用；任务材料、独立记录及撤销归档一起映射。附件失败保留原库；数据库失败回滚原数据及触发器，并回收本次新附件。中途退出留下的无引用附件由现有协调器清理。
- 导入的助手写租约清空，由新运行时重新领取。旧页面、会话缓存及服务不会继续使用恢复前的数据；旧工作区的通道解绑在重建前完成。
- 本机资源按勾选导出：`local-resources.json` 保存助手设置（含 API Key）与资料/动效/提醒偏好，`speech/` 仅在勾选且本机已安装并通过校验时保存模型原件。恢复类别按包内真实内容判定，不采信清单自述；未包含的类别不动目标设备值。安全存储整份替换，备份里没有的键一并清除。模型只接受固定清单内的文件名，落盘后不写校验标记，由下次 findInstalled 按真实字节重新校验 sha256。
- 业务数据已提交后本机资源写回失败时，明确提示"业务数据已恢复、资源写回失败"，不谎报原数据已保留。
- ZIP 限制为 768 MiB，展开总量 1 GiB、最多 20000 个文件；单附件沿用现有 20 MiB 限制，单模型文件 512 MiB，清单与本机资源 JSON 各 4 MiB。上限按勾选模型时约 228 MiB 原件放宽，展开总量仍有硬上限。超限或损坏整批拒绝。

## 验证与相关文档

| 入口 | 内容 |
| --- | --- |
| [备份导入恢复验收](../../../审查/2026-11-03-备份导入恢复.md) | 自动化、真实备份隔离恢复及设备边界 |
| [恢复持久化测试](../../../../test/application/backup_restore_test.dart) | 原子恢复、预览冲突、附件/数据库失败、结构与文件损坏 |
| [恢复页面测试](../../../../test/presentation/backup_restore_page_test.dart) | 实际 ZIP 到 SQLite、取消与确认、重复点击及大字号 |
| [助手与总结](../助手与总结/总览.md) | 会话和后台分析生命周期 |
| [平台资源](../平台资源/README.md) | 现行提醒与后台入口 |
