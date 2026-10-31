# MissionBook

MissionBook 是 Flutter 本地应用，用目标、大纲、任务、执行事实和材料组织日常行动，并提供可配置的 AI 助手、总结与记忆。Windows、Android 和浏览器分别保存本地数据，目前没有云端自动同步。

当前源码已接通任务创建与排期、执行和结果确认、历史补记、五种材料与追加修正、独立记录及关联、目标大纲与目标包导入、筛选统计、系统提醒、本地备份、助手工具调用和分层总结。具体平台验证范围见[本轮整改与验证](docs/审查/2026-11-01-复审与会话生命周期修复.md)。

## 文档入口

- [现行文档](docs/README.md)：当前架构、术语、样式和调用链。
- [整改清单](docs/审查/2026-11-01-复审与会话生命周期修复.md)：上传审查意见的逐项处置、回归入口及验收边界。
- [学习进度](docs/教学/学习进度.md)和[变更记录](docs/教学/变更记录.md)：区分代码落地、验证与用户掌握。
- [历史文档](docs/历史文档/README.md)：保留旧需求、方案、课程和视觉材料，仅供追溯；其中的阶段数量、材料限制和未实现能力可能已过时。

用户最新决定优先；文档描述需要核对当前源码与测试。旧领域文档不能作为阻止新能力或回退现有行为的依据。

## 运行

```powershell
flutter pub get
flutter run -d windows
# 或先用 flutter devices 查看已连接设备，再指定 -d <device-id>
```

浏览器预览：

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8085 --cross-origin-isolation --no-web-resources-cdn --no-pub
```

打开 [MissionBook](http://127.0.0.1:8085)。固定访问地址以复用该来源的浏览器数据；浏览器数据与原生应用独立。

Android 离线语音使用 SenseVoice int8，在“助手设置 → 语音输入 → 下载离线模型”主动下载约 230 MB；支持进度、取消和重试。模型不进入 Git、不随 APK 打包，新克隆可直接构建。Windows 暂不启用该本地引擎，可使用文字或自行配置录音转写。详见[模型说明](assets/models/sensevoice/README.md)。

## 验证

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test tool packages/agent_core/lib packages/agent_core/test
flutter analyze --no-pub --fatal-infos
flutter test --no-pub --coverage
# packages/agent_core 内运行：dart analyze --fatal-infos；dart test
```

测试使用隔离数据，不打开用户数据库。真实相机、麦克风、通知后台唤醒和原生文件选择器仍需目标设备验收，见[测试约定](test/README.md)。

## 目录

```text
lib/
  core/             全局主题与公共基础
  domain/           业务对象、纯规则及仓储契约
  application/      服务、助手编排和展示投影
  data/             Drift、附件、模型与平台适配
  presentation/     页面与共享组件
packages/agent_core/ 独立模型与工具运行基座
test/               自动化回归
integration_test/   设备测试
drift_schemas/      已有数据库版本快照
docs/               现行文档与隔离保存的历史资料
```

提交源码、锁文件、正式文档和应用资源。构建产物、日志、模型、凭据、本机数据库和临时输出不提交。不要为尚未实现的能力预建空表或空接口。
