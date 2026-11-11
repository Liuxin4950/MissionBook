# 2026-10-29 助手 UI 适配版验收

版本 `0.2.8+10`，分支 `codex/contextual-assistant`。本轮针对用户安装反馈修订新增 AI 模块；既有任务/目标/今天页 UI 保留。与 0.2.7 交付快照对比，55 个非 AI 页面文件完全一致，见 [范围核对](existing-ui-scope.json)。生成图的任务列表/导航/附件只是背景示意，不作为实施内容。

## 自动验证

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 应用全量回归 | 523 通过，1 个真实 API 用例默认跳过 | [flutter-test.log](flutter-test.log) |
| 静态分析 | 无问题 | [flutter-analyze.log](flutter-analyze.log) |
| 变更 Dart 格式 | 51 文件，0 修改 | [changed-dart-format.log](changed-dart-format.log) |
| 实际截图复核 | 4 条场景通过，12 张实际 Flutter 截图 | [ui-captures.log](ui-captures.log) |

完整回归包含：320/390/768/1200 宽入口、1280×800 平板横屏、800×1280 竖屏、600×420 分屏并弹出160高键盘、320宽两倍字号、消息间距、草稿保留、会话搜索/改名、输入激活与保存状态、提案修改后一次保存、语音启动超时和语言列表不返回的系统通道回归。

实际图片：[手机消息](../../assets/assistant-ui-rework-20261029/12-phone-message-spacing.png)、[会话记录](../../assets/assistant-ui-rework-20261029/11-phone-conversation-history.png)、[平板语音](../../assets/assistant-ui-rework-20261029/07-tablet-voice-bubble.png)、[分屏键盘](../../assets/assistant-ui-rework-20261029/10-split-window-keyboard.png)。[生成参考及制作过程](../../制作记录/2026-10-29-助手UI适配修订.md)与实际截图分开，不用生成图证明功能。

Agent 核心未在本轮改动，沿用 0.2.7 的 [112 项核心回归](../2026-10-29-助手预览版/agent-core-test.log)和 [真实 DeepSeek 1 项验证](../2026-10-29-助手预览版/deepseek-live-test.log)。本轮 UI 修改没有再次消耗用户的 API Key，也未将 Key 写入安装包。

## 设备验收

自动化识别为模拟适配/系统通道，不替代 Android 麦克风；请安装后测试授权、录音、最终转写、停止与重试。设备没有可用语音识别服务时应显示错误并能切文字，不能一直等待。输入文字后发送按钮应立即可用，清空后禁用；平板浮层应位于导航侧边，旋转/分屏后仍在可用区内。

真实系统键盘、窗口缩放和语音质量仍需用户反馈。本版本是当前上下文助手 UI 修订预览；聊天图片附件、批量计划和长期总结/目标记忆尚未交付。代码落地和测试不表示用户已经掌握。

## APK 交付

ARM64 release 构建成功（423.0 秒），共享路径 `/sdcard/Download/MissionBook-0.2.8-ai-ui-20261029-arm64.apk`，40,000,765 字节，源/共享文件 SHA-256 均为 `c53d528e8d2d4813dd14f8b916e930764031839e99f52a36f1f31f7201e66d48`，版本和现有签名一致。产物信息与校验见 [delivery.json](delivery.json)，元数据、签名和构建日志在本目录归档。本地预览使用现有调试证书，不是正式发布签名；复制到共享目录不等于自动安装或设备验收。
