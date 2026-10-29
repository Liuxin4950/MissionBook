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

## Agent 接入测试（分支部分落地）

- 会话存储合同：[drift_session_store_test.dart](data/assistant/drift_session_store_test.dart) 使用隔离内存数据库，覆盖序号/分页、重开、导入、租约竞争和删除。当前 5/5 通过，不代表 v10→v11 迁移、备份或真实进程写锁通过。
- 控制器与工具：[assistant_controller_test.dart](application/assistant/assistant_controller_test.dart) 使用真实 `MissionService`/`GoalService`、内存 SQLite 和脚本模型，覆盖真实日期查询、编辑后创建、取消零写入、完整权限、旧提案冲突、停止及重开会话恢复。当前 7/7 通过，不使用真实 API Key。
- 测试替身：[assistant_fakes.dart](support/assistant_fakes.dart) 只实现凭据存储与脚本模型，不绕过业务服务或事务。
- 当前不能运行全量门禁作为通过证据：助手页面草稿存在静态分析错误；`execution_events_migration_test.dart` 仍断言 v10/九表，尚未补 v11 新装与 v10→v11 迁移；`archive`/`sqlite3` 依赖升级后的备份、Web Worker 与全量回归也待复验。
- 万任务研究探针不在仓库内，只作规模证据；正式测试必须按[上下文契约](../docs/设计/Agent接入App.md#68-代码语义与落地验收)覆盖数据库有界分页、每次请求预算、详情分段和长期记忆。
