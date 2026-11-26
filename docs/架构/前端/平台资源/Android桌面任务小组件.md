# Android 桌面任务小组件

> Android Launcher 只展示由 MissionBook 真实排期事实派生的只读快照，不在原生层复制任务状态机。2026-11-23 起外观升级为设备级 v2 配置，桌面渲染与设置内预览共用同一份原生布局计划。

## 尺寸与视觉

| 入口 | 参考尺寸 | 内容 |
| --- | --- | --- |
| 小 | 109×109dp | 日期、一个焦点任务（进行中/待确认优先） |
| 中 | 220×109dp | 日期、按容量与 `rowLimit` 显示任务，宽槽用时间—任务—状态三槽 |
| 大 | 220×220dp | 同上，行数更多；放不下时尾部「另有 N 项」或题头 `+N` |

- 暖白纸页与森林绿：外底 `#F7F8F5`、正文面 `#FFFFFF`、浅绿 `#EEF2EC`、森林绿 `#244D3D`、主/次文字 `#282E2A/#626A64`、细线 `#E0E5DD`；组件深色独立为 `#1B251F/#202C24/#26382E/#EEF2EC/#B8C9BE/#A7C9B3/#E7C48B`，不引入 App 全局暗色主题。
- 四种样式：**纸页清单**（默认，开放任务行 + 两侧缩进的细分隔线）、**课程卡片**（接近纸白的浅底 + 左侧 3dp 书脊 + 行角 8dp）、**极简**（无行底色条，仅文字与缩进分隔）和 **任务时间轴**（细轨、圆节点、当前时段强调面）。设置页预览图由同一份 `RemoteViews` 生成，避免 Flutter 与桌面各自绘制造成样式漂移。分隔线不贯穿卡片边缘；行底色收至弱对比，避免多块实色造成视觉割裂。平板橱窗门闲置时为低对比发丝线，悬停/聚焦/拖动才加强品牌色，折叠把手改为窄圆角矩形以降低突兀感。样式不重置用户已调数值与信息开关。
- 详细规范、字段取值域与通道回执见[小组件外观契约 v2](../../../设计/小组件外观契约v2.md)。

## 外观配置

设置入口在「我的 → 设置 → 界面 → 桌面小组件」，原位展开编辑器，没有必经新路由：预览（小/中/大 + 浅深示例）→ 样式与颜色 → 字号（`headerSp` 11–17 / `taskSp` 11–20 / `metaSp` 10–16）→ 间距（外边距、行内、行间隔）→ 显示内容（详细信息、时间模式、阶段、日期、更多、行数上限）→ 恢复默认/保存。

- 一份配置作用于这台设备上的所有实例，按实例真实尺寸适配；不逐实例配置、不做主题下载、任意透明背景或新后台服务。
- 数值与开关只改草稿并刷新预览（`previewAppearance`，合并刷新 + latest-wins），**保存**才写一次偏好；无改动禁用保存，保存成功就地反馈，`partialFailure`/`failed` 显示「已保存，桌面暂未更新」并提供只用缓存重绘。
- 离开编辑器前对未保存修改走确认；加载失败给重试；保存失败保留草稿；无组件也可保存作为将来默认值。Web/Windows 不显示入口、不调用 Android 通道。

## 布局规划器

`TodayWidgetLayoutPlanner` 是不依赖 Android View 的纯 Kotlin 模块，**先计算再构建**：

```text
尺寸(px) + 密度 + 系统 fontScale + 字体度量 + v2 外观 + 快照条目 + 快照状态
  → WidgetPlan（题头/行/尾部/空态/溢出/度量/颜色角色/行版式/书脊/分隔线）
    → RemoteViews 渲染（桌面）
    → TodayWidgetPreviewPayload（设置内预览的同一份回执）
```

- 容量从实际高宽扣外侧留白、按字体度量的题头（下限 24dp）与尾部（下限 20dp）、行高与行间隔；逐个尝试 `n` 取最多可显示行。行触控下限 32dp，只有不减少行数且不隐藏尾部时才补到 48dp。
- 尾部「另有 N 项」按总数计算；尾部会挤掉一行而题头装得下时改用题头 `+N`；`n=0` 只保留可点的题头入口。小号最多一行，中/大取 `min(rowLimit, 容量, 快照条数)`。
- 宽槽（可用宽 ≥220dp 且按字体度量能给标题约 160dp）用时间—任务—状态三槽，否则标题 + 辅助行的上下布局；`timeMode=range` 放不下先降级为开始时间，再不足优先保留阶段；`showDetails=false` 只留任务名；自选任务不填假时间；不按墙钟重算阶段。
- 「没有当日快照」（等待同步）与「有快照且零项」（今日暂无任务）是不同空态；空间不够不冒充空日。

## 数据流

```text
MissionService.changes / App 恢复 / 组件首次添加或上海日期轮换
  → TodayWidgetBridge（前台）或 todayWidgetBackgroundMain（无界面引擎）
    → MissionService.findScheduledOn(YYYY-MM-DD)
      → 排期、事件、材料与报告事实 → deriveMissionPhase（含 STOP 后的 reportPending）
    → 只投影今日和明日、至多五条/日、id/title/start/end/phase、焦点标记
      → MethodChannel mission_book/today_widget
        → TodayWidgetProvider.publish
          → AtomicFile(noBackupFilesDir/today-widget-v1.json)
          → 规划器 → RemoteViews 三种 provider
```

`findScheduledOn` 仍是唯一排期查询入口；取消任务不进入列表，`closed`/`reportPending` 只作为派生显示文字。外观的读取/保存/预览都是独立通道方法，不触发任务查询、维护或写入。

## 外观持久化与回退

- v2 外观保存在 `noBackupFilesDir/today-widget-appearance-v2.json`（`AtomicFile`），原生是默认值、取值域、持久化和最终回执的权威；未知枚举、非整数、越界、`version≠2` 或缺失 `version` 一律拒绝写入。
- 首次升级时若 v2 文件不存在，读取旧 `SharedPreferences("today_widget_appearance")` 的 `theme/textSize` 迁移：旧「标准」映射默认 12/12/11，旧「大字」映射 15/15/13，主题保留；迁移结果立即写成 v2。文件损坏时使用默认值、标记 `recovered=true` 并重写合法文件；更高版本只读默认、不覆盖。
- 保存与桌面更新是两件事：`setAppearance` 先原子保存，再以同一快照请求重绘，回执用 `noInstances`/`requested`/`partialFailure`/`failed` 区分；`updateAppWidget` 只代表请求已交给系统，不代表 Launcher 已绘制。单个实例异常不影响其它实例。

## 刷新与失败

- 前台任务提交通过 `MissionService.changes` 合并刷新；恢复前台也刷新一次；组件尺寸变化（API 31+ `OPTION_APPWIDGET_SIZES`，过滤非法值、去重、最多 16 个）与既有尺寸回调都会按新尺寸重新规划。
- 首次添加某尺寸、缺少今日或明日快照时，由 `JobScheduler` 安排有限时的无界面读取；小组件失败不回滚已提交的任务事务。
- 原生缓存写入受 128 KiB 限制并使用 `AtomicFile`；读取失败显示「等待同步，点按打开」，不把旧日期冒充今天。
- 上海次日零点使用不精确 `AlarmManager`，并响应开机、应用更新、时间/时区变化；不承诺毫秒级刷新。
- 小组件被全部移除时取消轮换闹钟并删除私有快照；快照与外观文件都不进入应用备份。

## 文件地图

| 文件 | 职责 |
| --- | --- |
| [today_widget_bridge.dart](../../../../lib/data/notifications/today_widget_bridge.dart) | Dart 只读快照协议与外观通道转发 |
| [today_widget_appearance.dart](../../../../lib/data/settings/today_widget_appearance.dart) | v2 外观模型、取值域、保存回执与预览 DTO |
| [today_widget_appearance_sheet.dart](../../../../lib/presentation/me/today_widget_appearance_sheet.dart) | 设置内外观编辑器（草稿、保存、重绘、离开守卫） |
| [today_widget_preview.dart](../../../../lib/presentation/me/today_widget_preview.dart) | 展示原生同 renderer 生成的小/中/大预览图与来源信息 |
| [TodayWidgetProvider.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/TodayWidgetProvider.kt) | 三种 `AppWidgetProvider`、RemoteViews 渲染、尺寸解析、原子缓存、日期轮换、通道处理 |
| [TodayWidgetAppearance.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/TodayWidgetAppearance.kt) | v2 外观模型、校验、AtomicFile 持久化、v1 迁移与恢复 |
| [TodayWidgetLayoutPlanner.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/TodayWidgetLayoutPlanner.kt) | 纯布局规划器与预览回执组装 |
| [MainActivity.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/MainActivity.kt) | 小组件点按意图交给 Flutter 今天页/任务详情 |
| [today_widget.xml](../../../../android/app/src/main/res/layout/today_widget.xml) | 共享卡片容器（题头/行容器/尾部/空态） |
| [today_widget_row.xml](../../../../android/app/src/main/res/layout/today_widget_row.xml) | 小号纵向任务行 |
| [today_widget_row_compact.xml](../../../../android/app/src/main/res/layout/today_widget_row_compact.xml) | 中号、大号三槽任务行 |

## 自动化与验收边界

- JVM 单测：`cd android && ./gradlew :app:testDebugUnitTest --offline --tests 'chat.liuxin.mission_book.TodayWidget*'`（规划器 27 项 + 外观 19 项，覆盖容量、条数夹取、字段开关、时间降级、字号 1.0/1.3/2.0、三槽与上下切换、迁移与非法拒绝）。
- Flutter：`flutter test test/presentation/today_widget_appearance_test.dart test/data/today_widget_bridge_test.dart`（模型/回执/预览/守卫/非 Android 入口）。
- 未验收：真实 Launcher 的选择器预览、三种尺寸与缩放的视觉、深色/大字、冷启动点按、日期跨夜、组件移除与重加、HyperOS 平板上的实际表现。APK 构建成功不能替代这些验证；Flutter 的通道替身也不代表真实桌面已绘制。


## 地点展示

Dart 快照的每个 row 可带 `location`。Android 解析为 `Row.location` 和 `WidgetItem.locationText`，有地点时使用 stacked 行增加一行带省略号的地点文字；无地点隐藏该行。地点纳入无障碍摘要和预览 payload，不写回任务库。
