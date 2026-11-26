# Mission 任务地点属性：设计评审与实施方案

> 状态：2026-11-26 已实现地点功能。schemaVersion 19 按用户决定采用当前结构重建，不维护旧数据库迁移和旧备份兼容；地点功能工作树尚未提交。

## 结论与范围

将可选地点直接放在 Mission 上，持久化到 missions.location，符合当前“任务基本信息”职责，是本需求最小的合理模型。继续用 Goal → Node → 独立 Mission 表示学期、课程和每节课，不增加课程体系、地图表、通用 metadata、placeId 或 requiresLocation 开关。

地点表示本任务当前约定的发生地点；FIXED/FLEXIBLE 表示执行时间方式，两者独立。地点不是执行步骤，也不是任务发生时真实到场位置的证据。null 表示未记录地点，不区分“确实不需要”和“尚不确定”，本轮不增加这一区分。

用户给出的 Mission.phase 仅是概念图：现有 phase 从完整事实派生，不在 missions 表增加可写阶段。地点变化不应创建 START/END/STOP、修改执行事实或追加排期版本。

已新增字段：

~~~dart
final String? location;
~~~

~~~dart
TextColumn get location => text().nullable()();
~~~

## 已核实的生产路径

| 路径 | 当前事实 | 最小调整 |
| --- | --- | --- |
| [Mission](../../lib/domain/entities/mission.dart) | 普通不可变实体，没有手写 copyWith、Equatable、toJson/fromJson | 构造函数与字段新增 location；不为字段另建实体框架 |
| [MissionService](../../lib/application/missions/mission_service.dart) | create → prepareCreation → createPrepared；edit 准备完整排期后交仓储；再次尝试可复制源上下文 | 创建、编辑与重试传递地点，明确定义省略和清空 |
| [映射](../../lib/data/repositories/mission_mapping.dart) | missionToCompanion / missionFromRow 双向转换 | 增加字段映射，并重新生成 app_database.g.dart |
| [任务命令](../../lib/data/repositories/mission_commands.dart) | 创建比较、编辑变更检测、旧快照检查、事务写入 | 全部纳入地点；只改地点仍更新任务版本时间、发送原有 changes |
| [仓储外观与指纹](../../lib/data/repositories/drift_mission_repository.dart) | _editFingerprint / _planFingerprint 决定同一请求的内容身份 | 纳入地点和更新意图；相同操作编号不能把不同地点当作同一请求 |
| [表单](../../lib/presentation/missions/form/mission_form_page.dart) | 普通创建、目标节点创建、编辑、再次尝试共用表单；有草稿和未知结果保护 | 共用地点输入、预填、变更检测、释放控制器、保存重试 |
| [目标包规则](../../lib/domain/rules/goal_package_rules.dart) | resolveMission → creation 独立于 MissionService | 在两处传递地点；导入预览和协议同步，避免静默丢字段 |
| [批量导入仓储](../../lib/data/repositories/drift_goal_package_repository.dart) | 根据校验结果组装任务，再批量 missionToCompanion | 验证暂存、重校验、重复内容判断和正式批量写入都保留地点 |
| [ScheduledMission](../../lib/domain/entities/scheduled_mission.dart) | 已直接持有 Mission 与最新排期 | 无需再复制 location 字段，直接 item.mission.location |

“所有入口支持”包含普通表单、目标/节点入口、再次尝试、AI 单项创建/更新、AI 批量 CREATE、目标包导入、备份恢复及原操作恢复路径。只改实体和表单会遗漏后五类。

## 地点值与编辑语义

- 建议为单行文本，去首尾空白，换行归为空格；空串/全空白最终保存为 null。建议上限 200 个 Unicode 码点，所有写入入口共用同一清理和校验，超长新值明确报错，不静默截断数据库值。
- 编辑请求省略地点：保持原值；提供非空文本：替换；显式清空：保存 null。不能用“新值 ?? 旧值”表达三种情况。
- 沿用现有工具的可选字符串习惯：AI 参数省略表示保留，空字符串表示清空；模型无需为每个普通任务补地点，不自行推断具体教室。
- 业务层可以像现有 updateContext 一样增加明确的地点更新意图，避免新增通用补丁框架；地点更新不应与 description/why 的清空捆绑。
- 再次尝试的表单建议预填源地点并允许修改/清空；AI 重试省略地点可沿用源值，显式清空不能再次被“默认继承”恢复。
- 单纯改期保留地点；地点修改不改变时间策略；新建没有地点照常保存。
- 不自动把“二教”改成“第二教学楼”，不把课程节点说明解析成确定教室。若需要一次补齐现有课程，可由用户选择目标/节点任务后沿用已有批量/编辑能力另行处理，不能猜历史地点。

当前仓储在出现任何执行事件后拒绝整份任务编辑，取消任务也不能编辑。第一轮建议保留这个既有边界，明确执行中任务只展示地点；如果要支持“上课后临时换教室”，应新增仅允许修改地点的窄命令，仍锁定排期和执行事实，不直接放宽现有 edit 的整个保护。此项可作为独立小扩展，不是字段实现自动获得的能力。

地点在 Mission 上只保留当前值，不提供地点变更历史或“实际去过哪里”的审计。如果未来需要这些事实，再按相应需求设计，不能将本轮字段解释为已经具备历史追踪。

## 数据库与备份

本轮将 schemaVersion 从 18 提升到 19，并沿用项目当前开发阶段的破坏性重建策略。用户已明确准备重新开始体验，因此不维护 v18 → v19 原位迁移、不保留旧数据库行，也不增加旧备份转换器。新建或重建后的 `missions.location` 是可空文本，历史不存在的地点自然为 null。

备份导出会按当前表结构自动包含 `location`；恢复器继续执行当前严格的 schema、表集合和列集合检查，旧 schema 备份不承诺兼容。新 schema 的带地点/无地点往返由备份回归覆盖。

## 今天页与原生小组件

实际是两条读取分支，不存在 TodayMissionItem → today_widget_bridge 的依赖：

~~~text
[已实现] missions.location ↔ Mission.location
                              ↓
                     [已有] ScheduledMission
                        ↙                  ↘
[已实现] TodayMissionItem    [已实现] _widgetRow JSON
               ↓                             ↓
      固定/自选今天列表              Kotlin Row → WidgetItem
                                                ↓
                                    WidgetRowPlan → RemoteViews
~~~

- Flutter：[today_display.dart](../../lib/presentation/today/today_display.dart) 的 _missionItem 与 TodayMissionItem 加地点；[schedule_section.dart](../../lib/presentation/today/schedule_section.dart) 固定任务行、[today_page.dart](../../lib/presentation/today/today_page.dart) 自选任务行与读屏标签显示地点。同步[详情内容](../../lib/presentation/missions/detail/mission_detail_content.dart)和日/周表的直接展示，避免入口之间字段消失。
- 地点行有值才参与布局，一行省略号，读屏保留完整文本；地点不挤占标题和原起止时间，空值不留空行。Flutter 首页 _previewLimit 当前按标题/时间两部分估算行高，要计入新增地点行。
- 小组件：[桥接器](../../lib/data/notifications/today_widget_bridge.dart) 同时更新 rows 和 featured 的地点字段；[TodayWidgetProvider.kt](../../android/app/src/main/kotlin/chat/liuxin/mission_book/TodayWidgetProvider.kt) 的 Row/解析/WidgetItem/绑定，以及[布局规划器](../../android/app/src/main/kotlin/chat/liuxin/mission_book/TodayWidgetLayoutPlanner.kt)的 WidgetRowPlan、容量和读屏摘要都须传递。
- 三套行 XML（普通、compact、featured）都要处理有/无地点；宽槽可将标题/地点放在中间的纵向区域，时间与状态保留原位置。小组件规划器必须按新内容高度算容量，空间不足减少展示条数并沿用“另有 N 项”，不靠继续压小字体。
- 地点默认随任务详情显示，建议沿用现有总详情开关、不另加地点配置；单独关闭时间/状态不应误清空地点。实现前同步外观契约并针对总开关组合明确测试。
- 快照新增可选字段即可，旧缓存缺失时读 null，不需要改用户任务。小组件快照 schemaVersion 与数据库 schemaVersion、外观 v2 是三个不同版本概念，不能同步机械加一。更新后复用已有缓存刷新和后台发布机制。
- 设置内预览与桌面使用相同原生 renderer，预览样例增加有/无地点组合；这里只是带标签的样例，不能冒充实际用户数据或设备验收。

“显示地点不依赖 ExecutionPlan”可以直接达成，但不能说当前查询完全不读取它：[findScheduledOn](../../lib/data/repositories/mission_queries.dart) 仍调用 _detailsForRows 拼完整详情，包括方案、事件和材料，再派生 phase。本轮无需因地点重写查询；若要进一步降低查询量，应另评估投影并保留完整 deriveMissionPhase 所需事实。

## AI 工具与导入协议

| 场景 | 建议行为 |
| --- | --- |
| getMission/getSchedule/相关任务上下文 | 通过 missionIndexProjection / missionProjection 及独立日程返回地点；地点是短关键事实，不必再读取执行方案或地图 |
| createMission | 接受可选 location，进入原 MissionService 创建事务；未提供则 null |
| updateMission | 支持地点替换和清空；省略保留，仍走原快照、幂等与权限控制 |
| retryMission | 按上述源地点规则预填/修改/清空，不复制旧执行事实 |
| planMissions CREATE | schema、prepareCreation、固定提案、计划卡展示与编辑、保存及回执全部传递地点 |
| planMissions RESCHEDULE | 只改时间，保留并展示原地点；本轮不借此工具修改地点，额外 location 应明确拒绝，提示用 updateMission |
| 目标包 JSON | location 与 title/description 同层，修改协议、resolveMission、creation、暂存重校验和预览；旧包缺失为 null |

相关源码：[工具目录](../../lib/application/assistant/assistant_tool_catalog.dart)、[工具执行](../../lib/application/assistant/assistant_tool_execution.dart)、[计划准备](../../lib/application/assistant/assistant_schedule.dart)、[任务投影](../../lib/application/missions/mission_projection.dart)、[统一读取](../../lib/data/assistant/drift_unified_reader.dart)、[计划卡](../../lib/presentation/assistant/operations/assistant_schedule_card.dart)。getSchedule 还有独立的轻量条目输出，不能只改 missionProjection 后就认为它已经覆盖。

新增 location 不更改上一轮 PLAN/EXECUTE、完全权限或悬浮确认语义。地点文字按数据展示，不当作 Agent 指令。当前其他字段的读取预算和工具恢复机制继续使用，不新建地点专属工具体系。

[目标包 Schema](目标计划导入/mission-book.goal-package.v1.schema.json) 对字段有约束，需要同步新增可选属性和生成说明。建议本次扩展 v1 的可选字段：新应用继续接受缺失地点的旧包；不能承诺旧应用导入带地点的新包也能保留该字段，需写明最低支持应用版本。既有课程的地点默认仍为 null，本轮不会从旧备注或图片中抽取教室。

## 未来地图关联

未来 location 继续保存用户看见的任务地点文字/快照，placeId 只在用户选中或可靠匹配结构化地点时关联；没有 placeId 的普通地点照常显示。手动改文字后清除旧关联或重新校验，不能留下相互矛盾的两份位置。

本轮不增加 placeId、CampusPlace、CampusRoute、图片记忆或路线接口。未来地图原图和结构化地点分开保存，解析结果保留来源、地图版本与人工校验状态；图上的 x/y 通常是图像坐标，不能直接解释为米或真实距离。平面校园图也不保证包含室内教室、楼层与道路通行信息，无法确认时保持未知，不能凭图片补成事实。

## 实施结果与验收

| 顺序 | 完整工作单元 | 必须验证 |
| --- | --- | --- |
| 1 | Mission、Missions、双向映射、schema 19 | 新结构包含可空 location；旧数据按用户决定不保留 |
| 2 | 创建/编辑命令与表单、再次尝试、目标包导入、指纹/冲突 | 有值/空值/清空、只改标题/日期保留地点、重试身份、并发旧快照、导入预览到保存 |
| 3 | AI 读取/写入、批量计划和可编辑计划卡 | schema与校验一致，读到真值、提案不写、授权才写、清空/重试/改期保留 |
| 4 | 今天页、详情、日/周表与原生小组件全链 | 固定/自选、有/无/长地点、大字号、RTL、三尺寸、featured与rows、设置预览一致 |
| 5 | 相关回归、Android Kotlin 编译及目标设备验收 | 真 Launcher 修改地点后刷新，缩放/重加/冷启动/暗色/点击进入；不能仅凭 Dart 测试判定完成 |

每单元同步当前模块文档、教学变更记录和实现/验证进度。核心相关测试入口包括 mission_editing_test、goal_package_import_test、backup_restore_test、assistant_plan_test、today_display_test、schedule_section_test、today_widget_bridge_test 以及原生 TodayWidgetLayoutPlannerTest。应增加地点专项目标断言，而非只检查构造函数能接受参数。

已实现 Mission.location、数据库字段、创建/编辑/重试、AI、导入、今天页、周表和 Android 小组件链路。旧数据库升级采用当前项目的破坏性重建策略，不提供历史数据兼容；新备份会包含 location，旧备份按严格 schema 检查拒绝。地点专项测试已加入，最终测试与 Android 编译结果以本轮命令为准，真实 Launcher/设备验收仍需单独完成。
