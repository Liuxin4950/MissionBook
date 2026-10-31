# 测试目录与维护约定

`test/` 保存自动化规则、服务、数据库和 Widget 测试；需要设备或模拟器上的真实相机等能力时，使用根目录的 [`integration_test/`](../integration_test/)。数据库测试使用内存库或测试独占的临时目录，不打开用户数据库。测试日志属于本机输出，不提交到源码目录。

## 时间相关测试

任务日期和组件读取的“今天”必须使用同一份可控时刻。只固定仓储时钟还不够：MissionService、AppShell / TodayPage、任务表单以及被直接测试的执行页各自使用时钟时，都要显式传入测试的 `clock`。页面初始日期与“当前时刻”用途不同，测试日期转换时不能用 `initialDate` 绕过时区计算。

- 测试数据使用固定 UTC 时刻，日期预期按业务时区明确写出；不要读取 `DateTime.now()` / `TZDateTime.now()` 拼装预期或临时把任务日期改成运行当天。
- 需要推进时间时，修改测试局部的 `now`，各层通过同一个 `() => now` 读取它；不要修改系统时间或建立全局可变时钟。
- 日期转换至少覆盖上海跨午夜；跨年用例同时检查 UTC 前一天和上海新一天，防止误用 UTC 日期、设备本地日期或真实运行日期。
- `tester.pump(Duration(...))` 推进组件定时器；它不会自动推进自行注入的业务时钟。需要同时检验时长与重绘时，应明确推进两者。

例子见[双栏与上海跨年测试](presentation/detail_pane_flow_test.dart)、[表单默认日期测试](presentation/create_mission_page_test.dart)。

## 交互与断言

先按现行规格确认预期，再检查组件和数据库结果。页面路由标签不能代替实际流程：END 后仍需交材料时，工作区保持原实例；用户点击“查看完整执行记录”才打开记录页，返回仍能回到原工作区。

对草稿保护、提交、幂等和导航，检查操作前后保存的事实、可见内容及必要的返回链。不要仅修改失败断言或减少检查来取得通过。查找入口失败时先说明缺少哪个入口，再滚动和点击，避免只得到 `Bad state: No element`。

## 执行与记录

先恢复锁定依赖，再运行受影响测试、静态分析和全量回归：

```bash
flutter pub get
flutter test --no-pub test/presentation/detail_pane_flow_test.dart
flutter analyze --no-pub
flutter test --no-pub
```

日期相关改动还应在另一宿主时区运行相关测试，例如：

```bash
TZ=America/Los_Angeles flutter test --no-pub test/presentation/detail_pane_flow_test.dart test/presentation/create_mission_page_test.dart test/presentation/today_page_test.dart
```

设备测试需明确目标，例如 `flutter test integration_test/evidence_camera_test.dart -d <device-id>`。普通 `flutter test` 不等于完成相机、系统通知、原生升级或后台重启验收。

交付记录分别写清静态分析、测试通过/失败数、运行范围与未验证的平台行为。历史提交中的“全部通过”只代表当时的运行结果，当前状态以本轮实际结果为准。

## 助手与平台资源回归

助手会话、工具授权、旧快照冲突和中断恢复使用真实应用服务、隔离数据库与脚本模型；不依赖真实 API Key。相机测试使用官方 CameraPlatform 替身；离线语音测试使用真实 isolate 与协议 worker，验证超时、退出、释放和重建。

新增边界测试入口：`presentation/evidence_camera_panel_test.dart`、`data/speech/sherpa_speech_engine_test.dart`、`application/analysis_preferences_test.dart`、`application/user_error_message_test.dart`、`data/record_context_test.dart`。具体清单和本轮实际结果见[整改记录](../docs/审查/2026-10-31-全局样式与架构整改.md)。

目标包协议夹具保留在 `docs/历史文档/设计/目标计划导入/examples/`；其路径归档不改变 JSON 协议。旧测试数字和历史失败不作为当前门禁结果。

本轮新增的截止调度、模型网关、空会话、图片恢复及通知入口回归见[2026-11-01 复审记录](../docs/审查/2026-11-01-复审与会话生命周期修复.md)。
