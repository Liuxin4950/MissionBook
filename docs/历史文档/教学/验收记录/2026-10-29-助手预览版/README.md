# 2026-10-29 助手预览版验收

范围：`codex/contextual-assistant`，接入基线 `74ceabe`；0.2.7 交付时的源码快照见 `source-sha256.txt`。版本 `0.2.7+9`。这是供安装反馈的阶段预览，完整 Agent 开发仍在进行。

## 自动检查

| 检查 | 实际结果 | 日志 |
| --- | --- | --- |
| App 静态分析 | 无问题 | [flutter-analyze.log](flutter-analyze.log) |
| 变更 Dart 格式 | 49 文件、0 修改 | [changed-dart-format.log](changed-dart-format.log) |
| App 全量回归 | 516 通过、1 个真实 API 用例按默认条件跳过 | [flutter-test.log](flutter-test.log) |
| Agent 核心全量 | 112 通过 | [agent-core-test.log](agent-core-test.log) |
| 真实 DeepSeek | 单独出网运行 1 项通过 | [deepseek-live-test.log](deepseek-live-test.log) |

真实模型用例仅使用临时 Key、隔离内存数据库和临时测试任务：查询、编辑批准参数、真实写入、重开恢复、节点改名、取消零写入。Key 不进入仓库、会话库、归档或 APK。

全量包含迁移、正式材料事实、有界分页、Unicode 分段、万任务候选查询、提案编辑及设置交互；Widget 语音使用模拟识别，不能替代设备麦克风验收。前阶段 Web JS release 和浏览器本地查询曾通过，本次 APK 门禁不等于最新 Web、Windows 或其他平台构建验收。

## 安装后的重点路径

1. 在今天/目标主页面长按中央 AI，滑到文字；在任务详情和目标节点入口发起对话，核对当前对象引用。
2. 返回原页面，核对未提交输入、滚动与展开状态；再次展开同一语音对话，核对历史与待确认操作保留。
3. 在助手设置填写设备自己的 Key，保存并测试连接；需要自定义服务时填写完整请求地址、协议、模型编号与容量。
4. 让助手查询或调整一项真实测试任务，先看提案，再修改参数/确认；返回任务核对实际结果。也可取消并确认没有写入。
5. 在系统提示时处理麦克风权限，测试长按滑到语音、停止转写、检查后发送、原位回复与展开。

## 待开发与设备边界

聊天图片与图片材料解析、批量计划、任务独立总结和精简目标记忆仍未完成。细权限分类与主动后台能力仍有待定产品规则，当前不暗中补成已确认需求。既有任务/目标业务和正式材料不被 AI 判断改写。

未连接 ADB，未宣称本次 APK 已安装、冷启动或真实麦克风识别通过；由用户安装后反馈。当前 release 使用既有 debug 签名，属于本地预览分发。

## APK 交付结果

`flutter build apk --release --target-platform android-arm64` 带默认 pub 步骤串行构建成功，耗时 367.4 秒；完整命令结果见 [android-build.log](android-build.log)。本机通过 QEMU 编译 AOT，期间 Gradle 输出 `Already watching path`，最终命令退出 0 且明确生成本次 APK，不能单独把该行当成失败。

- 共享路径：`/sdcard/Download/MissionBook-0.2.7-ai-preview-20261029-arm64.apk`，39,618,049 字节。
- 包名 `chat.liuxin.mission_book`，版本 `0.2.7` / code `9`，最低 API 24，目标 API 36。ARM64 的 `libapp.so` 存在；其他 ABI 的原生依赖被插件带入，不据此宣称支持这些架构的完整运行。
- V2 签名验证通过；证书与下载目录原 `0.2.6` 包一致，具备覆盖更新所需的包名、签名与版本条件。实际安装仍由设备验证。
- 本次产物时间晚于构建开始；ZIP 校验、Key 特征扫描和构建前后源码指纹核对通过。复制后 SHA-256 与源文件完全一致。

元数据：[apk-metadata.log](apk-metadata.log)；签名：[apk-signature.log](apk-signature.log)；文件校验：[apk-sha256.txt](apk-sha256.txt)；交付机器记录：[delivery.json](delivery.json)。

