# MissionBook

Mission Book 是一个以人的长期成长为核心的 AI 辅助规划、执行、验证与反思系统。

仓库处于重新实现阶段。截至 2026-10-29，现有主线已接通任务创建、编辑、取消、执行报告、五种正式材料与修正、目标/节点、大纲与目标包导入、筛选统计、系统通知和本地备份；历史与跨页同步继续以真实事实重新查询。当前 `feat/agent-app-integration` 分支开始接入独立 Agent：已有会话/操作回执的 schema v11 草稿、设备凭据适配、业务工具、控制器和助手页面草稿，但尚未装配到主导航，静态分析未通过，迁移、全量回归、真实模型与设备验收均未完成，不能作为可交付功能。实现、验证与边界以[学习进度](docs/教学/学习进度.md)为准，Agent 设计见[接入方案](docs/设计/Agent接入App.md)，统一规格见 [docs/README.md](docs/README.md)。

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

### 本机浏览器预览

```bash
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8085 --cross-origin-isolation --no-web-resources-cdn --no-pub
```

打开 [MissionBook](http://127.0.0.1:8085)。浏览器与原生应用各自保存数据，不自动同步；固定访问地址后可刷新读回。浏览器复用当前已接通的任务功能，具体实测范围以学习进度为准；配置、资源重编译及早期持久化验证见 [Web 浏览器预览](docs/开发/Web浏览器预览.md)。

## 文档

学习式开发从 [学习开发教纲](docs/教学/教纲.md) 开始：逐课查看做什么、为什么、设计取舍和验收；当前起点与证据见 [学习进度](docs/教学/学习进度.md)，调整原因见 [变更记录](docs/教学/变更记录.md)。讲解方式遵守 [开发执行计划](docs/教学/开发执行计划.md)。先做独立任务的持久化执行闭环，再逐步加入材料、截止、大纲、统计与通知。最终支持 Windows 和 Android，两端数据独立。

优先看图理解整版产品：[完整功能图解](docs/教学/完整功能图解.md)提供七张生图，覆盖功能全貌、关键业务分流、完整架构与开发顺序。

| 文档 | 内容 |
|---|---|
| [索引](docs/需求文档v1.0/索引.md) | 阅读顺序与关键规则入口 |
| [产品纲领](docs/需求文档v1.0/产品纲领.md) | 为什么做 |
| [领域模型](docs/需求文档v1.0/领域模型.md) | 术语、六个派生阶段与业务规则 |
| [数据模型](docs/需求文档v1.0/数据模型.md) | 要保存的事实 |
| [本地应用规格](docs/需求文档v1.0/本地应用规格.md) | 这一版做什么 |
| [界面与交互](docs/需求文档v1.0/界面与交互.md) | 页面与交互链 |
| [数据落地与平台](docs/需求文档v1.0/数据落地与平台.md) | 存储、导入、备份与平台要求 |
| [未来方向](docs/需求文档v1.0/未来方向.md) | 当前不实现的能力 |

外部 AI 可以按《数据落地与平台》中的 Goal Outline 协议生成大纲，用户预览确认后导入；JSON 不是运行时业务数据源。

界面视觉与布局参考 [UI 设计稿说明](docs/ui设计手册/README.md)；图中的旧功能示意按当前文字规格替换。

## Git 文件管理

提交源码、`pubspec.lock`、正式文档和应用资源。构建缓存、安装包、日志、本地环境配置，以及 `data/`、`runtime/`、`backups/` 等本地数据目录由 `.gitignore` 排除。

需要长期共享的设计定稿放入 `docs/`，应用实际使用的资源放入 `assets/`。环境配置示例使用 `.env.example` 等不含私密信息的模板。

忽略规则只影响之后的跟踪，不能缩小已有 Git 历史。已跟踪的临时输出需要停止跟踪，本地文件可以继续保留。

## 目录约定

```text
lib/                         Flutter 源码
  core/                      主题等已有公共能力
  domain/                    业务对象与仓储接口
  data/local/                Drift 数据库、表与配套生成代码
  presentation/              页面
test/                       与 lib 职责对应的测试
integration_test/           设备或模拟器上的真实平台能力测试
drift_schemas/              数据库结构版本快照
assets/branding/            应用使用的品牌资源
docs/
   需求文档v1.0/             产品与业务规格
   教学/                     执行计划、课程、进度、变更及图解
     assets/                 正式教学配图
   ui设计手册/               UI 说明与设计规则
     assets/初稿v1.0/        初版视觉参考
     assets/正稿v1.1/        当前设计参考及 design-tokens.json
     prototypes/            正式逐页说明、提示词、局部交互预览与文件清单
```

平台工程目录保留 Flutter 默认位置。根目录保留启动与应用装配文件；不为尚未实现的功能预建目录。生成代码保留在 Drift 源文件旁，结构快照保留在 `drift_schemas/`。正式文档不能依赖仅存在于本机的临时输出；既有缺失来源见[变更记录](docs/教学/变更记录.md)。

测试分工、可控时钟、交互断言和运行方式见[测试维护约定](test/README.md)。
