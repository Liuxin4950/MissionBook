# 2026-10-29 手机语音试用

- 设备：用户通过 USB 授权连接的 Android 16 手机，型号 25060RK16C。
- 首次安装：设备未检测到 `chat.liuxin.mission_book`；release APK 安装返回 Success，0.2.8+10 启动成功，实际页面见 `installed.png`。使用现有 Android Debug 证书，属于试用包，不是正式生产签名。
- 用户实际点击语音：麦克风已授权，但立即 `error_client`，见 `before-fix.png`。设备日志为 `E/SpeechRecognizer: no selected voice recognition service`。
- 根因：`voice_recognition_service` 为 null；设备可查询到 `com.xiaomi.mibrain.speech/.asr.AsrService`。应用原先只创建默认识别器。
- 修复：Android 系统桥只读默认识别项；仅默认项缺失时启用 speech_to_text 自带 `androidIntentLookup`，查询可用识别服务。已有默认服务的手机保持原路径，不修改设备全局设置。查询有 1 秒上限，旧宿主失败回到原路径。
- 第一次修复后：安装 Success，APK SHA-256 `4C8BB57EC3E024CD7DD25B5EB5F573C35525732AD86AFFEB7D422D773F18DF5A`。设备真实报错从 error_client 变成 error_permission；应用与识别服务麦克风均已授权，RecognitionService 仍拒绝第三方调用，不能将第一处修复称为语音可用。
- 第二处兼容：仅 Android 已初始化后收到 error_permission 时，取消直接识别，改开标准 ACTION_RECOGNIZE_SPEECH 系统可见窗口，使用中文并传递本地优先选项。返回文字放入原输入框，取消不发送，50 秒上限，旧回调/旧录音结束不能覆盖新轮次。生命周期仅在系统识别窗口可见期间保留等待，其余后台场景仍取消录音。未修改手机默认项或扩大麦克风权限。
- 已在设备上直接启动小米 AsrActivity，看到“正在倾听”窗口；这只能证明窗口可启动，不能证明已正确识别人声。
- 检查：默认项缺失/已设置/宿主不支持，加上系统窗口回传与取消后隔离迟到文字，与原语音控制和录音转写回归共 13 项通过；静态分析无问题。
- 构建说明：`--no-pub` 复用了带 integration_test 的注册文件，release 编译失败；改用完整 `flutter build apk --release` 重新生成正确注册文件后首次构建成功。后续修复同样采用完整命令，测试与构建顺序执行。
- 最终修复包：`flutter build apk --release` 成功，86.8 MB；SHA-256 `92E19393352C1F384C62D64109B7341A9A326A0A44D730456A8A18C8FA290681`。覆盖安装 Success、冷启动成功，仍为 Android Debug 证书。
- 设备流程：从应用底部 AI → 语音实际启动；随后页面显示“准备发送”，中文“爱惜”已回到输入区，见 `recognized.png`，未替用户发送。这证明实际设备有识别结果并回传应用；用户原话未确认，不能据此声称识别准确度已验收。取消/回传隔离有针对性回归，更多设备与噪声场景仍未覆盖。
- 未运行全量历史测试，未提交/推送。
