# 页面代码在哪里

更新：2026-10-24。按功能找页面，进入页面文件后，再沿它使用的组件阅读。

## 先找到要修改的功能

| 你要找什么 | 打开这里 | 入口负责什么 |
| --- | --- | --- |
| 今天列表、切换日期、刷新 | [today/today_page.dart](today/today_page.dart) | 查询、页面状态、导航和组合各区域 |
| 今天页顶部与一周日期选择 | [today/today_page.dart](today/today_page.dart) | 同文件的 _TodayHeader 和 _WeekStrip，紧接页面主流程之后 |
| 固定日程、完整日程列表 | [today/schedule_section.dart](today/schedule_section.dart) | 时间轴、计划时段及对应任务行 |
| 自选任务、展开与收起 | [today/today_page.dart](today/today_page.dart) | 同文件的 _FlexibleMissionSection，自选列表和局部展开状态 |
| 今天列表分组、日期和展示文字 | [today/today_display.dart](today/today_display.dart) | 整理已查询的数据，不访问数据库 |
| 新建、修改、重试新建 | [missions/form/mission_form_page.dart](missions/form/mission_form_page.dart) | 接收输入草稿、保存、处理错误和离开前确认 |
| 名称和目标输入框 | [missions/form/mission_form_page.dart](missions/form/mission_form_page.dart) | 同文件的 _MissionFormFields，使用页面持有的输入草稿 |
| 日期、时长、自选或固定时间 | [missions/form/mission_schedule_fields.dart](missions/form/mission_schedule_fields.dart) | 排期输入与日历展开，选值交回页面；文件末尾保留本表单共用的输入样式和标签 |
| 任务详情、开始、修改、取消 | [missions/detail/mission_detail_page.dart](missions/detail/mission_detail_page.dart) | 查询、操作提交、通知监听与入口分派 |
| 详情正文、行动步骤、材料要求展示 | [missions/detail/mission_detail_content.dart](missions/detail/mission_detail_content.dart) | 只读取传入的详情，组合正文与底部操作 |
| 详情里的日期和计划时长卡片 | [missions/detail/mission_detail_content.dart](missions/detail/mission_detail_content.dart) | 同文件的 _ScheduleCard，只展示最新排期 |
| 暂停、继续、延长、结束报告 | [missions/execution/mission_execution_page.dart](missions/execution/mission_execution_page.dart) | 执行动作、报告草稿、计时重绘和导航 |
| 执行页圆环、底部双按钮布局 | [missions/execution/execution_widgets.dart](missions/execution/execution_widgets.dart) | 展示页面传入的时长和按钮，不保存执行事实 |
| 查看一次任务的执行结果和时间线 | [missions/record/mission_record_page.dart](missions/record/mission_record_page.dart) | 展示结束后的只读记录 |
| 浏览已结束与已取消任务 | [missions/history/mission_history_page.dart](missions/history/mission_history_page.dart) | 查询历史列表，打开对应记录或详情 |

`form` 是“表单”：创建、修改和重试新建共同使用，因此没有只叫 `create`。
`detail` 是详情，`execution` 是执行，`record` 是一条记录，`history` 是历史列表。

## 多个页面共用的代码

放在 [missions/shared](missions/shared)：`shared` 表示多个页面共同使用。

| 文件 | 用途 |
| --- | --- |
| [mission_action_controller.dart](missions/shared/mission_action_controller.dart) | 统一提交开始、暂停、继续、延长和结束；管理等待、冲突及同一操作重试 |
| [mission_execution_display.dart](missions/shared/mission_execution_display.dart) | 共用标题、页面正文布局、动作反馈、事件时间线及时间文字转换 |
| [mission_phase_display.dart](missions/shared/mission_phase_display.dart) | 统一阶段文案和打开任务的提示 |
| [mission_live_status.dart](missions/shared/mission_live_status.dart) | 列表实时时长标签，定时重绘，不每秒查询或写库 |
| [active_missions_bar.dart](missions/shared/active_missions_bar.dart) | 跨日期显示当前运行或暂停的任务 |
| [mission_retry_button.dart](missions/shared/mission_retry_button.dart) | 打开带来源的全新任务草稿 |

全站通用的顶栏、确认框仍在 [widgets](widgets)，不与任务专用组件混放。

## 状态应该去哪里找

- **任务阶段与真实时长**：由 domain 规则读取已保存事件计算；本次没有更改规则和数据库。
- **整页查询、保存与返回保护**：在对应的 `*_page.dart` 中。广播只触发重查，保存仍经过同一个 MissionService。
- **提交等待、冲突、原操作重试**：在 `MissionActionController` 中。
- **区域内部交互**：日历是否展开在 `MissionScheduleFields`；自选列表是否展开在今天页文件内的 `_FlexibleMissionSection`。
- **待保存输入**：名称、目标、时长和时分控制器由表单页面创建和释放；子组件使用同一份控制器。日期和时间策略由子组件通过回调交回页面，保存和丢弃判断都读取页面草稿。

目录归类用于解决“文件平铺太多，找不到页面”；拆文件用于解决具体的复杂度问题。普通页面组件优先留在页面文件中，不因行数或区域数量拆文件；状态变量很多、交互复杂或独立性很高时，才考虑独立文件。显示转换函数明显遮挡页面主流程时，可像 today_display.dart 一样单独放置。今天页保留 today_page.dart、today_display.dart、schedule_section.dart 三个文件。

业务调用链继续看[任务页面与执行状态流转](../../docs/教学/任务页面与执行状态流转.md)。
