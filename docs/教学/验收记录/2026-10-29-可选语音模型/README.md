# 2026-10-29：离线语音复核与可选模型下载

## 独立复核

- 实际源码默认使用 `record` 录 PCM16 + sherpa_onnx 1.13.8 SenseVoice；`initBindings()`、识别器和流都在 worker isolate 内，主 isolate 传路径、采样及文字。搜索当前 lib/Android 主路径未找到系统识别弹窗调用；speech_to_text 依赖已移除。
- 旧交付 `MissionBook-0.2.9-local-asr-arm64.apk` 实际 SHA-256 为 `59b945bfa4d510ab2a04f4211089c5bb559991403dd7f63ddaffdd0f78b9c8b5`，与交接一致。
- ADB 只有 `emulator-5554`，物理手机不在列表。不能把模拟器或样例音频当作手机人声、准确率、连续发热验收。
- 修正文档中的旧引擎版本及模型权重 Apache-2.0 误标。纯标点过滤只是空结果保护，没有实现 VAD；不承诺所有噪声都不会生成文字。

## 当前实现

- 0.2.10+12。权重和 tokens 从 pubspec assets 移除，新克隆无需预先下载即可构建。
- 设置页“语音输入 → 离线语音”展示“未下载（可选）”，用户主动下载才联网，约 230 MB。使用上游维护者固定版本的 HTTPS 地址；不隐式切换镜像。
- 显示下载进度、取消、失败原因及重试；离开区域取消进行中的下载。流式写 `.part`，准确字节数和 SHA-256 均通过后才发布两个文件；取消/失败清理临时文件。
- 已在私有目录部署的旧模型校验后复用；未下载时点语音先提示设置入口，不启动麦克风。助手打开/预热不下载，转写服务模式不预热本地模型。下载资源从 Android 自动备份和设备迁移中排除。

## 本轮自动验证

- `flutter analyze --no-pub`：通过。
- 下载存储、SHA-256 拒绝同长度损坏、断流/超长/HTTP 错误、取消/重试/连点共享、旧模型复用、设置进度和离开取消、原语音状态及助手入口：33 项针对性检查通过。
- 前一轮 540 项全量通过为交接历史，本轮没有把它冒称为重新执行的结果。
- 显式模拟器集成命令：

```powershell
flutter test integration_test/speech_engine_test.dart -d emulator-5554 --dart-define=ASR_DOWNLOAD_TEST=true --reporter expanded
```

- 独立空临时目录，真实网络获取 **239549735 字节**并通过两个文件的 SHA-256；不是复用旧模型冒充下载。
- 下载与校验：**100356ms**。真实 worker 加载 **932ms**，识别 **219ms**，输出 **“开饭时间早上9点至下午5点。”**，中文关键内容断言通过，命令退出 0。
- 测试结束释放引擎、清理独立临时目录；生产代码不包含该自动下载入口。日志见 [asr-download-integration.txt](asr-download-integration.txt)。

## 交付及页面验证

- 构建命令 `flutter build apk --release --target-platform android-arm64,android-x64 --split-per-abi` 成功退出 0。普通 `--target-platform android-arm64` 仍混入其他架构的第三方库，因此交付使用真正按 ABI 分离的 ARM64 包。
- ARM64：**68764686 字节（65.6 MiB，约 66 MB）**，仅 arm64-v8a 原生库；APK ZIP 清单确认没有 `model.int8.onnx`、`tokens.txt`。旧包 279304283 字节，新包缩小约 75%。版本名 `0.2.10`；基础 build number 12，Flutter ABI 分包实际 ARM64 versionCode **2012**、x86_64 **4012**，后续更新应沿用分包方式并递增基础版本号。
- 签名校验通过，仍为 **Android Debug 证书**，属于安装试用包。证书 SHA-256：`f86e34a88cba8bc592864601ffb52c6fcfb153fb38137a3c834cb5be307ea826`。
- 交付：`C:\Users\Liuxin\Downloads\MissionBook-0.2.10-optional-asr-arm64.apk`，工作区同名副本在 `build/app/outputs/flutter-apk/`。APK SHA-256：`aa8fdee780e3ff62d86b852537557a44eae75dc484da3d558eeeb7888b07b269`。
- x86_64 release 包在模拟器安装 Success、冷启动成功。实际从 AI → 语音点开，显示未下载及语音设置入口，未弹系统识别窗口，麦克风权限仍未申请（granted=false）；见 [no-model.png](no-model.png)。
- 实际打开设置并滚动到语音输入，默认显示“离线模型未下载（可选）”，见 [settings.png](settings.png)。点击下载实际显示字节进度，见 [progress.png](progress.png)；点击取消后恢复可下载状态并显示“下载已取消，可随时重新下载”，见 [cancel.png](cancel.png)。
- 物理手机仍未接回；ARM64 手机安装、人声准确度、无网实机操作、连续使用和发热仍未验收。所有改动留在 main 工作区，未提交、未推送。
