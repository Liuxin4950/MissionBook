# 页面代码在哪里

更新：2026-10-29。按功能找页面，进入页面文件后，再沿它使用的组件阅读。

## 先找到要修改的功能

| 你要找什么 | 打开这里 | 入口负责什么 |
| --- | --- | --- |
| 今天列表、切换日期、刷新 | [today/today_page.dart](today/today_page.dart) | 查询、页面状态、导航和组合各区域 |
| 今天页顶部与一周日期选择 | [today/today_page.dart](today/today_page.dart) | 同文件的 _TodayHeader 和 _WeekStrip，紧接页面主流程之后 |
| 固定日程、完整日程列表 | [today/schedule_section.dart](today/schedule_section.dart) | 时间轴、计划时段及对应任务行 |
| 自选任务、展开与收起 | [today/today_page.dart](today/today_page.dart) | 同文件的 _FlexibleMissionSection，自选列表和局部展开状态 |
| 今天列表分组、日期和展示文字 | [today/today_display.dart](today/today_display.dart) | 整理已查询的数据，不访问数据库 |
| 全部任务、日期与阶段/目标筛选 | [missions/all/all_missions_page.dart](missions/all/all_missions_page.dart) | 固定任务直接按时间排布，自选与取消任务在下方，保留查询与任务跳转 |
| 固定任务的比例布局、冲突和当前时间线 | [missions/all/mission_timetable.dart](missions/all/mission_timetable.dart)、[timetable_layout.dart](missions/all/timetable_layout.dart) | 复杂时间布局与只读交集计算；没有单独课表任务类型或视图切换 |
| 新建、修改、重试新建 | [missions/form/mission_form_page.dart](missions/form/mission_form_page.dart) | 接收输入草稿、保存、处理错误和离开前确认 |
| 可选任务归属 | [missions/form/mission_ownership_field.dart](missions/form/mission_ownership_field.dart) | 默认独立，按需选择有效目标/节点，归属编号交回表单 |
| 名称输入与折叠方案 | [missions/form/mission_form_page.dart](missions/form/mission_form_page.dart) | 同文件的 _MissionFormFields 及方案折叠区，使用页面持有的输入草稿 |
| 日期、时长、自选或固定时间 | [missions/form/mission_schedule_fields.dart](missions/form/mission_schedule_fields.dart) | 排期输入与日历展开，选值交回页面；文件末尾保留本表单共用的输入样式和标签 |
| 可选/强制材料、要求与截止 | [missions/form/mission_evidence_fields.dart](missions/form/mission_evidence_fields.dart) | 在原表单展开条件输入，可选说明不强制 |
| 文本/图片草稿、提交、放弃与材料阅读 | [missions/evidence/mission_evidence_section.dart](missions/evidence/mission_evidence_section.dart) | 多页共用的复杂材料区域，稳定身份保留草稿；正式状态由服务重读 |
| 任务详情、开始、修改、取消 | [missions/detail/mission_detail_page.dart](missions/detail/mission_detail_page.dart) | 查询、操作提交、通知监听与入口分派 |
| 详情正文、行动步骤、材料要求展示 | [missions/detail/mission_detail_content.dart](missions/detail/mission_detail_content.dart) | 只读取传入的详情，组合正文与底部操作 |
| 详情里的日期和计划时长卡片 | [missions/detail/mission_detail_content.dart](missions/detail/mission_detail_content.dart) | 同文件的 _ScheduleCard，只展示最新排期 |
| 暂停、继续、延长、结束报告 | [missions/execution/mission_execution_page.dart](missions/execution/mission_execution_page.dart) | 执行动作、报告草稿、计时重绘和导航 |
| 独立执行任务页面 | [missions/execution/mission_execution_page.dart](missions/execution/mission_execution_page.dart) | 今天、目标、全部任务及底部当前任务快捷栏共用同一页，不在列表内嵌执行区 |
| 执行页圆环、底部双按钮布局 | [missions/execution/execution_widgets.dart](missions/execution/execution_widgets.dart) | 展示页面传入的时长和按钮，不保存执行事实 |
| 查看一次任务的执行结果和时间线 | [missions/record/mission_record_page.dart](missions/record/mission_record_page.dart) | 展示结束后的只读记录 |
| 目标列表与新建入口 | [goals/list/goals_page.dart](goals/list/goals_page.dart) | 查询正式目标、卡内展开路径、创建和详情导航 |
| 目标分类、编辑与状态 | [goals/list/goals_page.dart](goals/list/goals_page.dart)、[goals/detail/goal_detail_page.dart](goals/detail/goal_detail_page.dart) | 筛选四种状态、编辑文字、搁置、达成、放弃与恢复 |
| JSON 目标大纲导入 | [goals/form/goal_import_section.dart](goals/form/goal_import_section.dart) | 原位选文件/粘贴、校验、完整树预览、明确确认后一次保存 |
| 创建目标 | [goals/form/goal_form_page.dart](goals/form/goal_form_page.dart) | 输入草稿、稳定请求重试、返回保护 |
| 目标详情、路径与说明 | [goals/detail/goal_detail_page.dart](goals/detail/goal_detail_page.dart) | 按编号读取目标，展示节点、说明和原因 |
| 节点树、展开、排序与归档恢复 | [goals/outline/goal_outline_section.dart](goals/outline/goal_outline_section.dart) | 列表/详情共用，独立查询、监听与节点菜单交互 |
| 节点/目标的直接任务与记录标签 | [goals/outline/goal_missions_section.dart](goals/outline/goal_missions_section.dart) | 原位任务摘要、建任务；运行或暂停时进入独立执行页 |
| 目标卡/详情的真实节点记录摘要 | [goals/shared/goal_record_summary.dart](goals/shared/goal_record_summary.dart) | 读取有效节点与直接完成报告，去重显示，不保存进度 |
| 添加和编辑节点 | [goals/outline/goal_node_editor.dart](goals/outline/goal_node_editor.dart) | 原位底部填写框，固定创建请求、失败重试和草稿保护 |
| 浏览已结束与已取消任务 | [missions/history/mission_history_page.dart](missions/history/mission_history_page.dart) | 查询历史列表，打开对应记录或详情 |
| 我的：系统权限、本地备份、关于 | [me/me_page.dart](me/me_page.dart) | 查询设备能力，发起正式备份，展示保存反馈和安装版本 |
| 助手主页面、对话、快捷本地查询与输入 | [assistant/assistant_page.dart](assistant/assistant_page.dart) | 读取控制器快照，组合会话、提案/回执与输入；**草稿，尚未接入 AppShell** |
| 助手可编辑操作卡片与只读查询结果 | [assistant/assistant_operation_card.dart](assistant/assistant_operation_card.dart) | 按真实工具状态显示确认、取消、失败、未知结果和对象入口 |
| 助手会话历史 | [assistant/assistant_history_page.dart](assistant/assistant_history_page.dart) | 切换、改名、删除会话；**草稿，当前静态检查未通过** |
| 助手模型、凭据与操作权限 | [assistant/assistant_settings_page.dart](assistant/assistant_settings_page.dart) | 安全存储凭据、选择 DeepSeek 协议、连接测试与自动执行开关；**草稿，未接通设备验收** |
| 任务/目标内问助手与对象跳转 | [assistant/assistant_scope.dart](assistant/assistant_scope.dart) | 提供控制器，复用 DetailPane 打开助手和真实任务/目标；**尚未装配** |

`form` 是“表单”：创建、修改和重试新建共同使用，因此没有只叫 `create`。
`detail` 是详情，`execution` 是执行，`record` 是一条记录，`history` 是历史列表。

## 目标与任务使用同一套归类规则

按业务功能找目录，普通页面内容留在对应页面文件内；独立状态、复杂交互或真实共用的区域才保留独立文件。目标模块不再平铺页面，也不建立任务模块才有的执行、历史目录。

```text
goals/
  list/goals_page.dart                 列表、筛选和导航
  form/goal_form_page.dart             创建与编辑
  form/goal_import_section.dart        文件或粘贴导入目标
  detail/goal_detail_page.dart         详情阅读与状态操作
  outline/goal_outline_section.dart    列表和详情共用的节点树
  outline/goal_node_editor.dart        节点输入及草稿保护
  outline/goal_missions_section.dart   树中目标或节点的关联任务区
  shared/goal_record_summary.dart      跨页共用的真实记录摘要
  shared/goal_status_display.dart      跨页共用的目标状态文案
```

`outline` 是目标大纲／节点树，它内部的任务区负责摘要和导航；完整任务表单、执行页与记录页仍在 `missions`。`form` 同时收纳手动创建、编辑和导入，`shared` 放真正跨页使用的目标展示组件与文字转换。

## 多个页面共用的代码

放在 [missions/shared](missions/shared)：`shared` 表示多个页面共同使用。

| 文件 | 用途 |
| --- | --- |
| [mission_action_controller.dart](missions/shared/mission_action_controller.dart) | 统一提交开始、暂停、继续、延长和结束；管理等待、冲突及同一操作重试 |
| [mission_execution_display.dart](missions/shared/mission_execution_display.dart) | 共用标题、页面正文布局、动作反馈、事件时间线及时间文字转换 |
| [mission_phase_icon.dart](missions/shared/mission_phase_icon.dart) | 今天、自选、全部与当前任务栏共用的六阶段图标 |
| [mission_phase_display.dart](missions/shared/mission_phase_display.dart) | 统一阶段文案和打开任务的提示 |
| [mission_live_status.dart](missions/shared/mission_live_status.dart) | 列表实时时长标签，定时重绘，不每秒查询或写库 |
| [active_missions_bar.dart](missions/shared/active_missions_bar.dart) | 跨日期显示当前运行或暂停的任务 |
| [mission_retry_button.dart](missions/shared/mission_retry_button.dart) | 打开带来源的全新任务草稿 |

全站通用的主页面头、二级顶栏、表单输入和确认框仍在 [widgets](widgets)，不与任务专用组件混放。

## 分类与筛选控件

目标状态与历史类别是互斥的页面分类，共用 `widgets/app_segmented_control.dart`；全部任务的日期、阶段和目标归属是可以组合的筛选，使用主题中的标签、输入框和卡片。全部任务始终显示日期入口及快捷切换，筛选收起后保留当前条件摘要。筛选只改变展示，计划时段和实际执行仍由原有时间线与业务事实计算。

目标页的列表、空态和上下文操作跟随所选状态；已搁置、已达成、已放弃均只展示本分类内容，不补放进行中目标或创建／导入工作区。创建和导入入口放在进行中分类，切换分类前复用导入区的草稿保护。节点标记保持行首定位，右侧建任务和菜单作为一个操作区在标题与状态区域内垂直居中。

目标树通过一致缩进、连续分支线和浅底根节点表达父子关系，不在每行重复显示层级编号。任务归属弹层可搜索目标、节点或父路径中的多个关键词，并保留完整路径区分同名节点。今天页在周日期栏直接标记今天，跨周时才在日期旁提供今天快捷入口；全部任务日期区直接显示所选日期，并提供固定位置的今天／全部日期选项，不增加固定的“计划日期”标题。时间轴使用 4px 小圆角条保留时段形状；图例、短时任务收在同一分区内，任务列表与统计复用白色分区表面及统一内边距。

## 状态应该去哪里找

- **任务阶段与真实时长**：由 domain 规则读取已保存事件及材料/失败/放弃事实计算；schema v5 保存正式材料，草稿不参与阶段。
- **整页查询、保存与返回保护**：在对应的 `*_page.dart` 中。广播只触发重查，保存仍经过同一个 MissionService。
- **提交等待、冲突、原操作重试**：在 `MissionActionController` 中。
- **区域内部交互**：日历是否展开在 `MissionScheduleFields`；自选列表是否展开在今天页文件内的 `_FlexibleMissionSection`。
- **待保存输入**：名称、目标、时长和时分控制器由表单页面创建和释放；子组件使用同一份控制器。日期和时间策略由子组件通过回调交回页面，保存和丢弃判断都读取页面草稿。

目录归类用于解决“文件平铺太多，找不到页面”；拆文件用于解决具体的复杂度问题。普通页面组件优先留在页面文件中，不因行数或区域数量拆文件；状态变量很多、交互复杂或独立性很高时，才考虑独立文件。显示转换函数明显遮挡页面主流程时，可像 today_display.dart 一样单独放置。今天页保留 today_page.dart、today_display.dart、schedule_section.dart 三个文件。

业务调用链继续看[任务页面与执行状态流转](../../docs/教学/任务页面与执行状态流转.md)。


## 个人资料与设置

- [me/me_page.dart](me/me_page.dart)：本机资料、资料编辑草稿保护、真实目标与已结束任务概览；右上角设置入口。
- [me/settings_page.dart](me/settings_page.dart)：按实际平台和提醒能力展示权限、执行通知与计划提醒，提供备份及关于；返回个人页。
- [local_profile.dart](../application/settings/local_profile.dart)：本机资料值对象；[AppDevice](../application/settings/app_device.dart) 提供资料读写和系统能力，平台实现在 `data/settings`，不增加领域表。

## Agent 页面当前边界

`presentation/assistant/` 是 2026-10-29 分支草稿。页面颜色、字号、顶栏、卡片、按钮和详情导航都读取现有主题与公共组件，但 AppShell 仍是四个主页面，`AssistantScope` 尚未包入工作区，任务/目标详情也没有“问助手”入口。`flutter analyze --no-pub` 当前报告助手历史/设置引用不存在的函数与类型、主页面输入框使用了不支持的 `border` 参数等问题；因此这些文件不能作为已交付页面引用。先按[Agent 接入 App](../../docs/设计/Agent接入App.md#7-实施顺序与验收)完成装配和检查，再记录实际视觉与设备验收。

### 2026-10-26 图形引导与工作区

`goals/list/goals_page.dart` 同时承接手机单列、宽屏创建/导入并排和目标列表/行动路径并排；同一Wrap子树重排，不复制业务或节点树。该文件的私有 `_GoalJourneyHint` 用三个图标和一次顺序显现表达目标→行动→记录。`widgets/app_illustration.dart` 复用于目标、空日程与空历史，只控制首次可见入场及图片尺寸；事实、草稿、查询和保存仍由原页面与服务负责。`goal_import_section.dart` 在开始输入时通知页面保留导入工作区，以免缩成窄窗丢失草稿。
