# MissionBook

Mission Book 是一个以人的长期成长为核心的 AI 辅助规划、执行、验证与反思系统。

仓库处于重新实现阶段，`lib/` 目前已接入统一主题和“今天、目标、历史、我的”四个占位页面的导航框架。统一规格见 [docs/README.md](docs/README.md)，规格描述目标行为，实际进度以代码和验收为准。

## 核心闭环

```text
手动创建 Mission（可关联 Goal / GoalNode）
→ Start / Pause / Resume / Extend / End
→ 自报结束，或稍后提交正式材料后结束
→ Result 查看执行事实（智能评价暂未接入）
→ 重启后继续查看正确的记录、时间和正式附件
```

## 运行

```powershell
flutter run -d windows
```

或运行其他已经配置好的 Flutter 设备：

```powershell
flutter devices
flutter run -d <device-id>
```

## 文档

学习式开发从 [开发执行计划](docs/开发执行计划.md) 开始：先做独立任务的持久化执行闭环，再逐步加入材料、截止、大纲、统计与通知。最终支持 Windows 和 Android，两端数据独立。

| 文档 | 内容 |
|---|---|
| [索引](docs/v1.0/索引.md) | 阅读顺序与关键规则入口 |
| [产品纲领](docs/v1.0/产品纲领.md) | 为什么做 |
| [领域模型](docs/v1.0/领域模型.md) | 术语、六个派生阶段与业务规则 |
| [数据模型](docs/v1.0/数据模型.md) | 要保存的事实 |
| [本地应用规格](docs/v1.0/本地应用规格.md) | 这一版做什么 |
| [界面与交互](docs/v1.0/界面与交互.md) | 页面与交互链 |
| [数据落地与平台](docs/v1.0/数据落地与平台.md) | 存储、导入、备份与平台要求 |
| [未来方向](docs/v1.0/未来方向.md) | 当前不实现的能力 |

外部 AI 可以按《数据落地与平台》中的 Goal Outline 协议生成大纲，用户预览确认后导入；JSON 不是运行时业务数据源。

界面视觉与布局参考 [UI 设计稿说明](docs/ui设计手册/README.md)；图中的旧功能示意按当前文字规格替换。

文档检查：

```powershell
python tool/check_docs.py
```
