# MissionBook 项目约定

## 开发阶段原则

项目处于开发阶段，**只保留最新实现，不做任何旧版本兼容**。这条优先于历史文档、旧测试断言和旧设计截图。

- 数据库（drift）只保留 `onCreate`，**不写 `onUpgrade`**，不保留迁移链，不保留 `drift_schemas/` 历史快照。
- 结构变更后本地库打不开是预期现象，处理方式是**删库重建**，不写迁移代码。
- 旧 API、旧字段、旧页面、旧兼容适配层，直接删除，不留 deprecated 转发。
- 代码与测试冲突时，先判断代码是否为新设计（对照 `docs/架构/设计/全局样式/总览.md` 等现行文档），是则改测试。

## 本地数据位置（Windows）

- 主库：`%APPDATA%\chat.liuxin\Mission Book\mission_book.sqlite`
- 目标导入库：`%APPDATA%\chat.liuxin\Mission Book\mission_book_goal_import.sqlite`（schemaVersion 1）
- 结构变更后重建：关闭应用，删除主库及 `-wal`/`-shm`，重启由 `onCreate` 建当前结构。

## 验证基线

- `flutter analyze` 必须无问题。
- `flutter test` 全量通过（当前 716 项）。
- `packages/agent_core` 的独立测试执行时会卡住，非必要不跑。
