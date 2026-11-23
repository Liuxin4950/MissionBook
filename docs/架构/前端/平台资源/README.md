# 平台资源架构

> 平台资源包含相机、离线语音及系统提醒；设备生命周期和业务写入入口分别维护。

## 目录

| 文档 | 内容 |
| --- | --- |
| [提醒恢复与资源释放](提醒恢复与资源释放.md) | 损坏提醒归档、系统撤销、编号重建、有界队列、后台只读与关闭顺序 |
| [Windows 桌面助手](Windows桌面助手.md) | 可选安装目录、启动恢复、悬浮球与共享会话 |
| [Android 悬浮助手与离线语音统一实施计划](../../../设计/Android悬浮助手与离线语音统一实施计划.md) | 截图后恢复、圆形快捷入口、语音后端预检与原生录音状态；规划稿，尚未实现 |
| [Android 桌面任务小组件](Android桌面任务小组件.md) | 三种尺寸、只读日程快照、日期刷新和点击导航 |

## 恢复与释放

损坏提醒文件的归档、系统撤销、编号重建、有界队列、后台只读和关闭顺序见[提醒恢复与资源释放](提醒恢复与资源释放.md)。

## 文件地图

| 文件 | 职责 |
| --- | --- |
| [attachment_file_service.dart](../../../../lib/application/attachments/attachment_file_service.dart) | 记录与材料共用的附件选择、校验和存储端口 |
| [attachment_platform.dart](../../../../lib/data/attachments/attachment_platform.dart) | 原生与 Web 附件实现装配 |
| [photo_capture_panel.dart](../../../../lib/presentation/attachments/photo_capture_panel.dart) | 权限、取景、拍照、确认、重试与生命周期 |
| [sherpa_speech_engine.dart](../../../../lib/data/speech/sherpa_speech_engine.dart) | 握手、共享初始化、请求超时、故障重建及关闭 |
| [speech_worker_protocol.dart](../../../../lib/data/speech/speech_worker_protocol.dart) | isolate 消息协议，便于协议级测试 |
| [sherpa_worker.dart](../../../../lib/data/speech/sherpa_worker.dart) | worker 内真实 FFI 模型初始化、识别与释放 |
| [app_notification_service.dart](../../../../lib/application/notifications/app_notification_service.dart) | 任务事实驱动提醒对账与通知动作 |
| [reminder_store.dart](../../../../lib/application/notifications/reminder_store.dart) | 送达状态和通知编号契约 |
| [planned_mission_background.dart](../../../../lib/planned_mission_background.dart) | Android 后台引擎装配入口 |
| [android_notification_dispatcher.dart](../../../../lib/data/notifications/android_notification_dispatcher.dart) | 常驻标记、系统计时、通知动作与外观交接 |
| [xiaomi_execution_payload.dart](../../../../lib/data/notifications/xiaomi_execution_payload.dart) | 由同一执行摘要生成澎湃 OS 3 计时模板 |
| [NotificationAppearance.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/NotificationAppearance.kt) | 通知外观代次、原生秒表和超级岛图片/动作交接 |
| [XiaomiFocusSupport.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/XiaomiFocusSupport.kt) | 系统支持、焦点权限与应用配置的独立查询 |
| [AssistantOverlayService.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantOverlayService.kt) | 用户授权的 Android 跨应用助手气泡与前台通知 |
| [AssistantCaptureConsentActivity.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantCaptureConsentActivity.kt) | 每次截屏前启动系统 MediaProjection 授权 |
| [AssistantScreenCaptureService.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantScreenCaptureService.kt) | 普通单帧或自动轮询长截图捕获、重叠拼接、图片压缩、投影释放和助手交接 |
| [MainActivity.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/MainActivity.kt) | 系统桥、设备能力查询、备份/文件选择及助手截屏缓存交接与回收 |
| [CaptureEditorView.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/CaptureEditorView.kt) | 顶部截图工具栏、局部/全屏及长截图入口 |
| [CaptureSelectionView.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/CaptureSelectionView.kt) | 当前真实画面与遮罩、框选/移动/四角调整 |
| [CaptureSelection.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/CaptureSelection.kt) | 可独立验证的矩形像素几何 |
| [OverlayEdgeGeometry.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/OverlayEdgeGeometry.kt) | 左右边缘收起与呼出的坐标规则 |
| [OverlayPanelPlacement.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/OverlayPanelPlacement.kt) / [AssistantOverlayPanel.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantOverlayPanel.kt) | 在头像以外的可用区域定位；分别呈现工具、草稿与对话 |
| [LongCaptureMatcher.kt](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/LongCaptureMatcher.kt) | 相邻帧滚动位移、固定栏识别及不可靠拼接拒绝 |

## 相机状态流

```text
启动 / 恢复 → 申请设备与初始化 → 读取相机能力 → 取景
                                      ├ 点按预览 → 支持的自动对焦点
                                      ├ 双指缩放 / 倍率滑杆 → 设备变焦范围
                                      └ 拍照 → 保存草稿
                                      └ 保存失败 → 保留同一照片 → 重试保存 / 重拍
暂停 / 离开 → generation 失效 + 释放控制器 → 迟到拍照结果丢弃
```

点按对焦仅在平台报告 focusPointSupported 时启用；变焦控件仅在相机最小/最大倍率可读且范围有效时显示。预览支持双指缩放，滑杆用于精细调整，倍率限制在设备能力范围内。Web 相机实现不支持点按对焦，按其返回的变焦能力决定是否显示滑杆。全屏拍照使用黑色媒体画布、顶部圆形返回、底部渐变操作区和中央白色快门；默认变焦使用透明线条轮盘，沿弧线显示预设倍率，左右拖动连续变焦、轻触切换预设、长按打开精细 Slider；取景区点按对焦显示透明线条对焦环并提供读屏提示。选择图片、不记录图片、失败重试和重拍都保持至少 48dp 触控，不改变原有自动确认与失败保留语义。

保存进行中用独立确认标记阻止重复加入；后台释放取景控制器不解锁正在保存的照片。全屏自动确认失败也保留照片和重试操作。权限拒绝、受限与不再询问均给中文提示，可重试。自动化使用 CameraPlatform 替身验证能力门控、焦点归一化坐标和倍率写入；真实镜头对焦、双指手势、倍率响应及照片质量仍需目标设备验收。

## 语音状态流

```text
prepare → 共享 _preparing → spawn + 有界握手 → worker 初始化 → ready
transcribe → 请求身份 + 超时 → 识别结果
超时 / worker 退出 → 拒绝未完成请求 + 释放端口 → 下次 prepare 重建
任何阶段 dispose → generation 失效 + 幂等关闭 → 迟到 worker 不复活
```

启动、识别和关闭各有超时边界。并发 prepare 只初始化一次；测试注入 workerMain 验证协议，生产仍使用真实 FFI worker。

## 系统能力

DeviceCapabilities 以唯一的 DevicePlatform 标识平台；通知、准时提醒和执行通知分别使用可空状态，未知不能显示为已授权。设置页按平台与对应权限状态展示入口。

小米设备还分别返回 `islandSupported`、`focusPermission` 和 `focusConfigured`；最后一项仅说明包内配置了非空 App ID，不代表小米审核或系统展示已通过。原生能力查询在后台线程执行。

## Android 跨应用助手

- [AssistantWorkspaceHost](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantWorkspaceHost.kt) 让 MainActivity、悬浮和监督服务按需持有同一个主 FlutterEngine。[App 工作区](../../../../lib/app_services.dart)在页面构建前装配同一份业务资源，与计划任务唤醒引擎分开。最后一个持有者释放时先等工作区关闭。备份恢复先禁用监督、撤掉旧桥接，再重建工作区；有代次的回调不能落到新工作区。
- [悬浮服务](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantOverlayService.kt)由本机开关和系统悬浮权限控制。进入或离开 MissionBook 不隐藏头像；打开完整会话、任务或记录只收面板，手动截图才临时隐藏头像。点头像先展开独立圆形动作球，聊天内容按高度滚动。窗口在同一屏幕坐标内避开头像、系统栏和键盘。
- [截图服务](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantScreenCaptureService.kt)仅开放手动单次授权，保留原编辑器的选区、全屏、长截图及一次性草稿交付。Android 14+ 选择单应用后按系统回调尺寸同步调整虚拟屏与图像缓冲，首帧迟到时有限重试。主动画面授权和取样已搁置。原生临时图交付后删除，未消费缓存到期清理。
- [应用使用情况](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantUsageMonitorService.kt)需开启本机开关并授予 Android 使用情况访问。定时读取用于本地排期提醒，不调模型。发送悬浮消息时尝试现读，把当前 App 名称和估算连续时长交给本轮会话模型，不另选模型，不发送历史清单或截图。锁屏、暂停、无权限或查不到时不提供。授权偏好不进备份，前台信号不是任务执行事实。
- [可见录音窗口](../../../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantOverlayVoiceActivity.kt)仅由点按开始，提交短 PCM 到现有配置转写，结果回填同一草稿，取消不发送。未发草稿只保证同工作区进程内保留。原生 UI、投影、语音、系统手势和后台恢复仍以目标设备体验为准。

手动截图的授权/编辑 Activity 只负责申请投影、选择区域和结束自身；完成或取消时直接 `finish()` 返回截图前的应用，不调用 `MainActivity.assistantIntent()`。截图服务完成编码后仍通过 `AssistantOverlayService` 将图片交给当前悬浮草稿，并重新显示悬浮聊天，因此截图不会强制打开 MissionBook AI 页面。


## 系统提醒调用链

```text
系统提醒 / 页面 → AppNotificationService → MissionService → 任务事务
                       ↓                  ↓
                 提醒状态契约         系统分发契约
                       ↓                  ↓
                 文件持久化         Android / Windows 实现
后台引擎入口 → 装配数据库、任务服务、调度器和平台分发器 → 同一任务事务
```

完整备份恢复前，App 解绑旧工作区通道监听、等待调度和提醒操作退出，并清除下一次计划唤醒；重建工作区后由正常启动重新对账。正常退出也等待通知动作队列结束后才关闭共享数据库，避免通知动作在数据库关闭后继续写任务。恢复流程见[数据备份与恢复](../数据备份与恢复/README.md)。

提前预告打开任务详情，执行中的通知提供停止或继续操作。到点任务通过统一任务维护入口执行，调用方必须明确传通知动作，空动作打开详情，未知动作返回失效；提醒记录只保存当前排期的送达状态和通知编号。

通知文案只呈现对象、当前状态、时间和必要操作。悬浮入口常驻通知为“助手悬浮球”和关闭动作，截屏及后台启动通知只显示当前操作。任务提醒标题使用任务名，正文显示开始时间或阻塞原因。执行通知以状态、专注时间和总时长紧凑呈现，移除重复 subText；原生展开与超级岛沿用同一短状态。校时、重试及待确认仍明确保留。

## 常驻提醒

Android 的课前、运行、暂停、到点待确认通知均设置 `ongoing=true`、`autoCancel=false`。点击正文只打开任务；任务开始后清理课前提醒，取消/改期撤销旧提醒，提交 END 后撤销执行通知。常驻并不持有新的后台循环，系统一键清空不参与任务或排期事实写入，也不取消未来闹钟。

按 [Android 14 行为说明](https://developer.android.com/about/versions/14/behavior-changes-all#non-dismissable-notifications)，ongoing 通知在“全部清除”时保留，但解锁后用户仍可单独划掉；应用不通过反复补发与用户争夺通知栏。精确闹钟、通知权限及厂商后台设置仍按现有能力查询处理。

## 澎湃 OS 3 超级岛计时

```text
完整 MissionDetail.phase / calculateExecutionTimes
  → executionReminder（Focus、投影时刻、额度、动作身份）
  → AndroidNotificationDispatcher：prepare 外观代次 → 插件 show
    → xiaomiExecutionPayload：展开态与摘要态使用同一计时起点
    → NotificationAppearance：后台查能力 → 检查当前代次/可见通知
      → 保留原 PendingIntent 与按钮 → 原生秒表 / 小米扩展参数
```

只有系统支持 OS3 岛、焦点通知获准、包内 App ID 已配置三者同时成立时添加小米扩展。其他情况继续显示普通常驻计时通知。运行使用 `sameWidthDigitInfo.timerInfo` 和 `highlightInfo.timerInfo`，正计时起点为投影时刻减去已累计 Focus；暂停、STOP 后待确认或时钟回拨显示冻结数字。系统走秒，没有每秒 Dart Timer 或每秒通知重发；固定任务的 STOP 仍由现有计划调度与事务负责，不由通知补写。

外观代次与任务序号不同：`prepare` 为本次显示分配 token；`invalidate` 撤销 token，迟到的能力查询/重试不能复活通知；后续合法显示可以重新使用同一通知编号。小米动作直接引用插件生成的 `Notification.Action`，继续走原业务权限与幂等校验。

小米卡片与岛使用一致的存活期，取十二小时与“当前额度加一小时”的较大值，避免岛默认一小时超时造成长课提前消失；秒数限制在接口 32 位整数范围。任务终态仍主动撤销，不等系统超时。

接入依据：[小米开发指南](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2131)及其《小米超级岛模板库 20260129》（展开计时第 34–37 页、等宽数字第 106–107 页）。本地客户端模式无需引入 MIPUSH，但需要按[接入流程](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2132)开通超级岛服务、配置证书和 App ID，并取得调试白名单或正式权限。

开通后，通过本机构建环境的 Gradle 属性配置：

```powershell
$env:ORG_GRADLE_PROJECT_xiaomiAppId = '<小米平台分配的 App ID>'
$env:ORG_GRADLE_PROJECT_xiaomiBuildTypeDebug = 'true'
flutter build apk --release --target-platform android-arm64
```

这两个属性分别生成 Manifest 的 `com.xiaomi.xms.APP_ID`、`com.xiaomi.xms.BUILD_TYPE_DEBUG`。当前项目 release 也使用 debug 证书，调试标记默认 true；后续换正式证书时同时将该属性改为 false，并在小米平台配置对应指纹。未配置 App ID 时值为空，应用不假设拥有超级岛权限。截止本轮用户尚未开通服务，已按其要求完成应用侧适配。

## 验证边界

[相机测试](../../../../test/presentation/evidence_camera_panel_test.dart)使用官方 CameraPlatform 替身，覆盖权限、控制器释放、后台迟到结果、保留照片重试、点按对焦及变焦滑杆。[语音测试](../../../../test/data/speech/sherpa_speech_engine_test.dart)使用真实 isolate 和协议替身，覆盖并发初始化、无握手、崩溃、超时及关闭重建。

这些测试未加载真实模型和摄像头。真实麦克风、人声识别、FFI 兼容、系统权限弹窗、通知后台唤醒及设备照片质量仍需目标设备验证。

常驻通知在 Android 16 模拟器实际点击“全部清除”后验证四种状态保留，并验证未来提醒仍在队列、END/取消后撤销及迟到外观失效。超级岛协议投影已有运行、冻结和时钟回拨测试；模拟器不支持小米超级岛，厂商外观与鉴权仍待已开通的小米设备验收。具体数据与复验步骤见[本轮通知记录](../../../审查/2026-11-04-常驻提醒与超级岛.md)。

跨应用悬浮聊天面板最大宽 328dp。点击侧边把手会先恢复完整头像，再按新位置放面板；向内拖动也复用同一恢复逻辑。聊天正文和输入用 12sp，保留系统字体缩放；发送按钮触控区保持 48dp，生成中在原位切成停止按钮，不在消息列表另放操作。

悬浮入口的工具层与聊天层分离：`AssistantOverlayService` 点击主球先显示 `AssistantOverlayQuickMenu`，文字、语音、截图和更多四个动作球在主球的屏幕内侧排成圆弧，左右镜像，从主球中心向各自位置展开。接近屏幕上下边缘时移动整组按钮以免裁掉。更多层仍可打开会话、截图和切换应用感知；聊天继续由 `AssistantOverlayPanel` 和同一 `AssistantWorkspaceHost` 承担。侧边收起保留 48dp × 64dp 的透明触控区，可见绿色把手为 4dp × 42dp。
