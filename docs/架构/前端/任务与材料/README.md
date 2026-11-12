# 任务与材料架构

> 应用服务表达意图；任务仓储外观统一提供命令、查询、材料与排期能力，所有写入在同一数据库连接内校验事实。

## 目录

| 文档 | 内容 |
| --- | --- |
| [调度与执行事务](调度与执行事务.md) | 候选筛选、STOP/START 提交边界、编辑版本时钟、不可变详情与页面边界 |
| [记录独立维护与材料快照](记录独立维护与材料快照.md) | 记录边界、当前数据结构、接口与总结链路 |

## 文件地图

| 文件 | 职责 |
| --- | --- |
| [evidence_deadline_scheduler.dart](../../../../lib/application/missions/evidence_deadline_scheduler.dart) | App 拥有的前台截止调度、变化订阅、恢复与释放 |
| [planned_mission_scheduler.dart](../../../../lib/application/missions/planned_mission_scheduler.dart) | 前台计划开始/停止编排、变化订阅、重试与释放 |
| [mission_service.dart](../../../../lib/application/missions/mission_service.dart) | 用户、助手、提醒共用的任务入口，纯查询与显式维护分名 |
| [mission_repository.dart](../../../../lib/domain/repositories/mission_repository.dart) | 组合读取、命令、材料和排期能力契约 |
| [drift_mission_repository.dart](../../../../lib/data/repositories/drift_mission_repository.dart) | 连接、写锁、时钟及具体职责协作者外观 |
| [mission_queries.dart](../../../../lib/data/repositories/mission_queries.dart) | 读取和详情拼装 |
| [mission_commands.dart](../../../../lib/data/repositories/mission_commands.dart) | 创建、修改、取消与归属 |
| [mission_scheduling.dart](../../../../lib/data/repositories/mission_scheduling.dart) | 排期提案及自动开始/停止 |
| [mission_execution.dart](../../../../lib/data/repositories/mission_execution.dart) | 事件、历史补记和执行报告事务 |
| [mission_evidence.dart](../../../../lib/data/repositories/mission_evidence.dart) | 材料提交、已有记录关联、修正和截止 |
| [mission_history_page.dart](../../../../lib/presentation/missions/history/mission_history_page.dart) | 执行与取消历史；按日期分组并惰性构建记录卡片 |
| [scheduled_execution_rules.dart](../../../../lib/domain/rules/scheduled_execution_rules.dart) | 固定时段终点与自动停止边界，仅已保存 EXTEND 延后 |
| [execution_time_rules.dart](../../../../lib/domain/rules/execution_time_rules.dart) | 同一执行计时计算，固定任务绑定计划窗口，自选任务绑定 START |
| [evidence_mapping.dart](../../../../lib/data/repositories/evidence_mapping.dart) | 来源记录与提交快照的低层写入映射 |
| [drift_record_repository.dart](../../../../lib/data/repositories/drift_record_repository.dart) | 独立记录内容及关联编排，不写任务 END |
| [all_missions_page.dart](../../../../lib/presentation/missions/all/all_missions_page.dart) | 全部任务独立页，周导航、阶段/目标筛选和当前范围批量操作 |
| [mission_week_timetable.dart](../../../../lib/presentation/missions/all/mission_week_timetable.dart) | 七列周表、当天安排弹层、自然纵向滚动和可见性时钟 |
| [week_timetable_layout.dart](../../../../lib/presentation/missions/all/week_timetable_layout.dart) | 周一周界、逐日投影和重叠入口分组，不保存业务事实 |
| [timetable_conflicts.dart](../../../../lib/presentation/missions/all/timetable_conflicts.dart) | 日时间轴和周表共享的冲突明细，保留隐藏任务说明 |

## 调用链

```text
结束/补记 → 任务报告控件 / 助手 → MissionService.reportExecution
  → 独立提交到期 STOP → 任务命令事务
    → 回执识别 / 重读序号及排期 → 保存报告 + 必要 END → 提交 → 通知重读

新增材料 → MissionService.submitEvidence → 材料命令
已有记录关联 → RecordService → MissionService → attachRecordEvidence → 同一材料命令
  → 锁定并重读 → 截止与身份校验 → insertEvidence → 重读完整详情 → 回执
```

报告的相同身份与内容可重试；成功保存后时钟回拨不导致幂等重试被当作新的未来声明拒绝。冲突、未完成原因与时间更正仍按任务事实校验。

材料在任意执行阶段均可保存；其存在不代表任务完成。首次提交成功后，系统时间不得早于最新已保存执行事件，否则新材料以 `EvidenceConflict` 拒绝；已成功批次按提交编号识别并重试，不受回拨后的新校验影响。关联已有记录保存提交时的材料快照，保留来源编号；重复关联不重新捕获内容。记录内容和归属独立维护，原记录删除不影响任务材料。

任务执行页可直接进入该任务的记录列表，执行中创建文字、照片或文件记录时以 `missionId` 通过 `RecordService` 保存，并在同一材料命令内提交快照。任务结束后生成的任务评价读取有效快照；原记录以后编辑或删除不改变评价依据。节点/目标 AI 总结只聚合直接任务与子节点摘要，不读取直接归属的原始记录。详细记录边界见[记录与材料快照](记录独立维护与材料快照.md)。

超过截止后的材料仍可保存，并保留 EVIDENCE_DEADLINE_MISSED 事实。回执只要发现该事实就持续返回 deadlineMissed，重复调用不会改成普通 submitted。UI 明确显示“材料已保存，但已超过提交期限”。修正采用 supersedes 追加引用，不覆盖旧材料。

## App 截止调度

```text
App 启动 / 回前台 / 业务 changes / 到点 Timer
  → EvidenceDeadlineScheduler.refreshSafely（并发合并）
    → MissionService.reconcileEvidenceDeadlines（事务补算及提交后通知）
    → findPendingEvidence（纯读取）→ 最近强制材料期限 → 下一次 Timer
```

前台 `PlannedMissionScheduler` 与 Android 后台 isolate 是两个独立实例，均通过 `MissionService.reconcileScheduledMissions` 进入同一仓储维护入口，先独立提交 STOP，再尝试 START。前台实例订阅业务变化、应用恢复和到点计时，关闭时等待在途维护；后台实例只执行一次 `refresh()` 并退出。截止调度同样由 App 拥有：后台取消前台计时，恢复时主动补算；关闭等待在途维护完成后释放。查询期间跨过期限可立即复查一次，持续过期的异常快照或读取失败按 30 秒重试，不能反复安排零延时计时器。今天页一次加载先维护一次，再做当日列表和待补列表的两个纯查询。

`findPendingEvidence` 先在 SQL 层按首个执行事件绑定的排期修订、结束事件、材料策略、失败/豁免和截止前有效材料筛选候选，随后调用完整详情装配，并以唯一 `deriveMissionPhase` 保留 `evidencePending` 最终判定。SQL 条件只减少无关详情读取，不另建可写阶段，也不改变截止维护与 STOP/reportPending 事实。

## 调度与快照细节

候选筛选、STOP 与 START 的提交边界、编辑版本时钟、不可变详情和页面边界见[调度与执行事务](调度与执行事务.md)。

## 规则来源与约束

### 固定任务计时

2026-11-02 按用户最新要求：固定任务从 fixedStartAt 计时，终点为 fixedStartAt + plannedDurationMinutes + 已保存 EXTEND 分钟；打开应用、调度唤醒延迟或 PAUSE 都不顺延终点。PAUSE 仍从专注中扣除；主动 END 和到点 STOP 冻结计时，STOP 不代表用户报告完成。

```text
前台 App 装配 / 系统唤醒 → PlannedMissionScheduler → reconcileScheduledMissions
  → 写锁、重读、检查当前仍在计划窗口
  → 同一 _execute 命令路径 → 固定 START.occurredAt = 计划起点 → 完整时间线校验及写入

计划起点 + 原计划 + EXTEND → fixedTimeSlotEnd
  → scheduledExecutionEnd → 到期追加 STOP → deriveMissionPhase → reportPending
  → calculateExecutionTimes(schedule: ...) → 日程 / 执行 / 当前任务栏 / 历史 / 通知 / 助手投影
```

普通固定 START 也在事务中检查当前窗口，禁止提前或整个时段已过后重新获得一整段固定计时；现在补做沿用显式改为自选并开始的事务。整段错过而没有 START 的任务保留原待处理流程，已有 RUNNING 冲突仍不被自动抢占。

旧版本晚触发的 START 不覆写日志；所有生产计时入口携带原排期，从计划起点计算并在固定终点封顶。历史末次动作晚于应停止时刻时，追加 STOP 仍遵守日志时序，但显示时长不因该迟到事实延长。系统回拨继续提示校时，纯历史完成自报没有 START，不产生应用计时。

日程的当前时段、剩余分钟和进度通过同一 fixedTimeSlotEnd 读取 EXTEND，不再只使用原计划终点。

创建和排期字段校验使用领域唯一规则；历史补记资格由 historical_completion_rules 共享；安排提案内部与现有日程冲突由 schedule_proposal_rules 处理，采用半开时段 [start,end)，相邻时段不冲突。

仓储协作者为同一个 library 的 part，持有同一仓储外观；不要在协作者内另建数据库。写操作必须先取得写锁、再读取预期序号及排期；固定 START/STOP 按计划窗口确定生效时刻，其他动作使用事务时钟。纯查询不能附带维护写入。

术语和阶段见[术语](../../术语.md)与[全局架构](../../README.md)；测试证据见[整改记录](../../../审查/2026-10-31-全局样式与架构整改.md)。

## 记录边界与数据结构

见[记录独立维护与材料快照](记录独立维护与材料快照.md)，包含当前数据结构、接口与总结链路。

表现层 `lib/presentation/records/` 按职责分目录：`list/` 放记录主页面及同 library 的编辑、详情、关联选择和条目 part（`part` 必须与主 library 同目录）；`analysis/` 放总结面板与总结偏好设置；`settings/` 放记忆管理和联网搜索设置；`shared/` 放 `RecordScope` 与材料来源选择。文件名与业务行为不变。

## 页面职责

目标路径的节点摘要通过节点菜单调用 `showAnalysisSummary`；真实记录入口使用 `RelatedRecordsEntry`，查询和进入列表使用相同的目标/节点条件。记录列表按内容宽度和文字缩放选择单列/双列。

目标列表由 `GoalsPage` 管理状态分类及当前展开目标；`GoalRecordSummary` 用细进度条和计数显示真实任务完成进度：节点至少有一项直接任务且所有直接任务都有 END(COMPLETED) 报告才计为完成，无任务节点不计完成。Drift 查询通过反向存在检查排除仍有未完成任务的节点；轻量仓储则由同一领域规则从详情快照计算。节点标题下用短状态区分“已完成”和“部分完成”，右侧数量与箭头独立展开任务；没有直接任务时隐藏状态和数量，叶节点标题仍可展开关联记录。目标卡进度使用加长细条和浅绿 x/y 数字胶囊，完整口径保留在读屏标签，整卡 InkWell 包含标题与进度区，按压底色覆盖完整圆角表面。展开目标的进度行最右侧显示“添加节点”加号，调用同一 GoalOutlineSectionState.addRootNode；目录面板直接呈现搜索及节点列表。手机点击目标标题就在该目标下展开 `GoalOutlineSection`，目标卡右侧箭头进入详情；宽内容区采用目标列表和路径双栏。详情优先呈现路径，说明默认折叠，编辑与状态切换合并在目标操作菜单中。

```text
目标标题 → 就地展开路径
  目标进度行加号 → GoalOutlineSectionState.addRootNode → GoalNodeEditor.show
  节点标题或左侧箭头 → 展开/收起子节点
  节点任务数量及箭头 → 展开/收起本节点直接任务和记录入口
  节点加号 → MissionFormPage.forGoal（预先关联目标和节点）
  节点菜单 → 编辑、子节点、排序、摘要、归档及恢复
  任务整行 → 按真实阶段进入执行、完成确认、执行记录或详情
```

节点超过 6 项时提供名称/说明搜索，命中项带上真实祖先，搜索期间暂时展开匹配分支，清除后恢复原折叠选择。任务仍由工作区一次查询后按节点分组；运行中及待确认等阶段优先，同阶段按排期排列，历史阶段日期倒序，每页 10 项。新建返回后展开本节点内容。归档继续通过菜单确认和原服务提交，移除与树横向滚动冲突的滑动归档入口。

节点标题及树箭头都能展开/收起子节点；任务数量按钮独立控制本节点任务，叶节点也可点标题展开任务或记录。标题和短状态在同一最小 48dp 的内容区，常规字号的根节点含内外间距约 60dp；任务数量和维护按钮保持 48dp 触控。内容宽度不足 360dp 时，“建任务”保留在原维护菜单，宽面板继续显示加号。节点背景由整块圆角 Material 绘制，整卡 InkWell 承接标题点击与长按编辑，使按压底色覆盖完整表面；子节点箭头、数量和菜单分别处理自身动作。搜索框使用全局 14 号输入、12 号提示、radiusMd 圆角、spaceSm 竖向内边距，输入及清除按钮保留 48dp 触控，边框表面上下各内收 spaceSm，常规字号可见高度 32dp；焦点描边使用 primary，随系统大字自然增高。节点展开后的任务、分页和记录区域只保留两侧 spaceSm，不再叠加 markerExtent 和 spaceMd 缩进；浅色任务表面区分归属，树层级仍由外层节点缩进表达；分页和记录入口保持同一层级，目标直属任务保持原有宽度。节点菜单提示位于触发按钮上方，避免遮挡下方节点。节点说明保留在节点编辑和摘要数据中，不在任务列表前额外铺开。树层级与任务归属同时由节点缩进和内容起始列表达。

父级重建不会再对未变化的服务和目标编号重复查询目录与任务；页面隐藏期间收到业务通知时延迟到重新显示再刷新。当前展开的大目录仍逐行挂载全部可见节点，后续仍需惰性列表/分层窗口化及大规模实机验证。

执行历史一次遍历生成日期标题和记录项，再交由 SliverList 构建可见卡片；图片 Future 缓存最多保留 36 项。完整历史数据仍一次查询，尚未实现摘要分页。

任务详情负责计划及任务操作，执行记录负责实际结果与时间线。两处时间更正继续调用原报告弹层和事务；任务评价移到菜单弹层。任务材料保留各项自己的来源入口，不再额外堆叠一个材料来源记录列表入口。显示规范见[全局样式](../../设计/全局样式/README.md)。

## 全部任务的整周视图

今天页右上角进入独立 `AllMissionsPage`，计划日程右侧“查看全部”仍进入独立的当日日程。全部任务默认展示北京时间当前周的周一至周日；上一周、下一周按七个日历日移动，日历选择定位到所选日期所在周，返回本周保留阶段与目标条件。日历运算使用 UTC 日历字段，事实区间继续按 `defaultScheduleTimeZone` 投影，不用设备本地午夜代表业务周界。

`MissionWeekTimetable` 保留窄时间栏，其余实际内容宽度等分七列。手机、平板、桌面都完整显示七天，不建立横向滚动、内部纵向滚动或周视图 tabs。宽窗口自然增加列宽，窄列标题换行并在高度不足时截断，长按提示保留完整信息；点击日期查看当天全部安排，点击单项进原详情/执行页。窄屏顶栏只用筛选图标，批量操作收在顶栏菜单，正文不额外占一行。星期/日期使用共享 calendarLabel 紧凑角色，收紧行间距和选中底色，完整日期头保留至少 48dp 点击高度，系统大字自然增高。

七天共用时间窗口和每分钟比例，通常覆盖 8–20 点，并向外扩到实际存在的凌晨、夜间和跨日时段；系统字号保留，纵向内容随字号自然增高。只在今天所属列绘制当前线。固定计划按任务名称稳定分配四组低饱和颜色，自选实际区间单独使用提醒棕，自选时间和取消项分别在周表下按日期阅读。无任务日期仍保留列，筛选后空态与整周空态分开。

```text
MissionService.findAllDetailsAndReconcile → 原 MissionDetail 快照
  → timetableOverlapsRange：当前周范围（起点包含、终点不包含）
  → TimetableWeek → 7 × TimetableDay：逐日裁切、原冲突检测
  → weekTimetableBlocks：仅合并同日重叠呈现入口
  → 七列周表 / 日期弹层 → 原详情或执行入口
```

重叠安排合并为“n项安排”入口，展开后逐项阅读，不把窄列再细分或互相遮挡；计划冲突仍由 `TimetableDay` 计算，实际执行与计划重叠不冒充计划冲突。阶段或目标筛选只改变可见项，隐藏项仍参与冲突检测；`showTimetableConflicts` 同时服务日时间轴与周表，注明日期、真实交集和被隐藏的任务。

顶栏批量操作和周表共用范围函数；操作前按当前时钟重新读取覆盖范围，避免实际执行跨入新周后显示与操作范围不同。任务编号来自详情快照并去重，沿用原维护提案、确认及事务。筛选面板保留“本周、所选周、全部日期、以前未开始”，全部日期按日期列表阅读，大量历史结果沿用分页；不再在历史分组里重复建立多个日时间轴。重置恢复本周、全部阶段与全部归属，目标查询失败重试仍保留。

整周只拥有一个 30 秒展示时钟，应用不可见或 `TickerMode` 禁用时停止，释放时取消。它只刷新当前线和自选实际区间，不查询数据库或追加执行事实。完成统计仍明确展示最近 7 天与近 30 天，完成日与日程统一按北京时间读取。

## 当日日程双模式

`TodayPage(fullSchedule: true)` 提供共享 AppSegmentedControl 的“日程列表 / 时间轴”，默认选择时间轴；选择在当前页面的刷新、日期切换与窗口变化期间保留。列表继续使用 ScheduleSection 全量/分页模式，时间轴直接复用 MissionTimetable 和 TimetableDay.fromScheduled，二者共用 `_scheduled` 当日排期快照、原时钟和 `_openDetail` 入口，不新增查询、任务状态或数据库写入。

当日日程时间轴保留原日视图的比例、当前时间线、冲突提示、跨日裁切、并排冲突列与窄屏横向滚动；图内隐藏重复模式切换，较短时段的列表入口交回页面原列表。新增模式栏的高度计入图表视口预算；系统大字不缩放，极短屏和内容超出时仍允许正常滚动。没有固定任务时保留原空态与创建入口。


## 任务维护与撤销历史

[MissionMaintenanceRepository](../../../../lib/domain/repositories/mission_maintenance_repository.dart) 由现有 DriftMissionRepository 实现；[mission_maintenance.dart](../../../../lib/data/repositories/mission_maintenance.dart) 是同一 library 的协作者，不创建数据库连接。MissionService、任务详情菜单、全部任务筛选范围的批量入口和助手 manageMissions 共用该契约。

```text
页面 / 助手参数 → prepareMaintenance → 固定范围、完整快照和指纹
  → 用户确认（助手遵循当前权限）
  → applyMaintenance → 写锁 → 重查整个范围与指纹
    → cancel / delete / reset → 同事务回执 → 通知查询和调度重读
```

cancel 只取消未开始任务，其他阶段计入跳过；delete 物理删除任务、排期、方案、执行、失败、报告、任务材料及本任务撤销归档，保留独立来源记录和聊天，其他尝试仅解除被删除来源的外键。目标及祖先摘要失效，删除任务自身的总结队列和版本；共享附件协调器在提交后仅清理没有其他引用的文件。文件清理失败不把已提交删除误报为失败，下次初始化继续清理。

reset 仅面向已结束任务。原执行事件、失败、用户报告、材料、任务/方案/排期快照写入现有 operation_receipts，kind=missionExecutionArchive；这些历史不再作为当前时间线输入。当前执行、报告和材料清空，追加同一日期的自选排期，回到未开始，原固定窗口不会使其立即自动开始。用户可随后修改或改期；强制材料截止仍需按真实要求重新确认，不凭空延后。原事件及材料提交编号保留撤销标记，旧操作不得重新应用。

详情菜单“查看撤销历史”展示原事件、报告及材料图片；助手可读取 revoked 历史。附件引用集合包含撤销归档中的材料键，清理不会提前删除历史图片。再次开始仍走唯一执行规则与完整 deriveMissionPhase。这里没有新增可写 phase、回收站或数据库结构变更。

目标详情与目标列表共用进度展示和节点工作区，详情的新增节点加号也位于进度行右侧。新增操作经工作区的 addRootNode 进入同一节点编辑器。从课标文件批量创建目标、节点与任务见[目标计划导入](../目标计划导入/README.md)。
