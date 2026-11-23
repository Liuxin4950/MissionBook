# Android 桌面任务小组件

> Android Launcher 只展示由 MissionBook 真实排期事实派生的只读快照，不在原生层复制任务状态机。

## 尺寸与视觉

| 入口 | 默认网格 | 内容 |
| --- | --- | --- |
| 小 | 2×2 | 日期、一个进行中/待确认/下一项任务 |
| 中 | 4×2 | 日期、最多两项任务及时间/阶段 |
| 大 | 4×4 | 日期、最多五项任务，超出显示剩余数量 |

小、中、大组件按 Launcher 实际 `OPTION_APPWIDGET_SIZES` 和最小边界重算行数；小卡使用焦点任务卡，中/大卡按剩余高度显示更多行，文字大小支持标准/大字。统一使用浅冷蓝紫表面、浅色行卡片、深色主文字和紫色强调线；设置中可选跟随系统、强制浅色/深色。跟随系统保留 `values`/`values-night` 资源，显式主题用原生颜色覆盖。所有标题、行、空态和“更多”入口均可点按：标题打开今天页，任务行打开对应任务详情。

## 数据流

```text
MissionService.changes / App 恢复 / Android 组件首次添加或上海日期轮换
  → TodayWidgetBridge（前台）或 todayWidgetBackgroundMain（无界面引擎）
    → MissionService.findScheduledOn(YYYY-MM-DD)
      → 当前排期、事件、材料和报告事实 → deriveMissionPhase
    → 只投影今日和明日、最多五项/日、id/title/start/end/phase
      → MethodChannel mission_book/today_widget
        → TodayWidgetProvider.publish
          → AtomicFile(noBackupFilesDir/today-widget-v1.json)
          → RemoteViews 三种 provider
```

`findScheduledOn` 仍是唯一排期查询入口：按任务最新排期后筛选上海日历日期；取消任务不进入小组件列表。`closed`、`reportPending` 等阶段仅是派生显示文字，不产生新的可写状态。固定任务的 `start/end` 按排期自身时区格式化，自选任务不伪造时间。

## 刷新与失败

- 前台任务提交通过 `MissionService.changes` 合并刷新请求；恢复前台也刷新一次。样式偏好通过 `getAppearance`/`setAppearance` 写入 Android `SharedPreferences`，保存后只重绘既有 RemoteViews。
- 首次添加某尺寸、缺少今日或明日快照时，由 `JobScheduler` 安排有限时的无界面读取。后台计划执行也会尝试刷新；小组件失败不回滚已提交的任务事务。
- 原生缓存写入受 128 KiB 限制并使用 `AtomicFile`；读取失败显示“等待同步，点按打开”，不把旧日期冒充今天。
- 上海次日零点使用不精确 `AlarmManager`，并响应开机、应用更新、时间/时区变化；不承诺毫秒级刷新。
- 小组件被全部移除时取消轮换闹钟并删除私有快照；快照位于 `noBackupFilesDir`，不进入应用备份。

## 文件地图

| 文件 | 职责 |
| --- | --- |
| [today_widget_bridge.dart](../../../../lib/data/notifications/today_widget_bridge.dart) | Dart 只读快照及前台/无界面通道协议 |
| [TodayWidgetProvider.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/TodayWidgetProvider.kt) | 三种 `AppWidgetProvider`、原子缓存、日期轮换、后台 JobScheduler |
| [MainActivity.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/MainActivity.kt) | 小组件点按意图交给 Flutter 今天页/任务详情 |
| [today_widget.xml](../../../../android/app/src/main/res/layout/today_widget.xml) | 共享卡片容器 |
| [today_widget_row.xml](../../../../android/app/src/main/res/layout/today_widget_row.xml) | 小号纵向任务行 |
| [today_widget_row_compact.xml](../../../../android/app/src/main/res/layout/today_widget_row_compact.xml) | 中号、大号的时间列与任务行 |

## 限制与验收边界

小组件不读取 SQLite，不保存任务事实，不混入跨日待补材料；它只读取已提交事实的短快照。Android Launcher 是否显示在选择器、真实桌面三种尺寸、深色主题、冷启动点按、日期跨夜和组件移除，必须在目标设备上验收；APK 构建成功不能替代这些验证。
