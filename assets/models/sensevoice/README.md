# SenseVoice 离线语音模型

本目录保留模型来源、上游许可引用及官方中文测试音频。生产 APK 不包含模型权重或 tokens。

- 模型：`sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17`
- 文件：`model.int8.onnx`（约 229 MB，int8 量化）、`tokens.txt`
- 来源：<https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models>
- 压缩包：<https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2>
- 上游权重许可：以 [SenseVoiceSmall 模型卡](https://huggingface.co/FunAudioLLM/SenseVoiceSmall) 和 [FunASR MODEL_LICENSE](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE) 为准。模型卡标记 `model-license`，不能把 sherpa-onnx 代码的 Apache-2.0 当作模型权重的许可；保留同目录上游 `LICENSE` 引用。

## 用户下载（可选）

在 Android 的“助手设置 → 语音输入”手动选择下载。应用固定从 sherpa-onnx 维护者 csukuangfj 的 [Hugging Face 仓库](https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tree/2365baeacb507f821a0c8120fcee3d484dba7a07) 获取两个文件，版本固定为 `2365baeacb507f821a0c8120fcee3d484dba7a07`。

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| model.int8.onnx | 239233841 | c71f0ce00bec95b07744e116345e33d8cbbe08cef896382cf907bf4b51a2cd51 |
| tokens.txt | 315894 | f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc |

下载流式写入应用私有目录 `speech/sensevoice/*.part`，长度和 SHA-256 都通过才改名启用。取消/失败清理临时文件，下次可重新下载。网络不可达时会显示失败，不自动切换到未知镜像。旧版本已部署的模型通过完整校验后继续使用。

## 开发与验收

新克隆直接 `flutter pub get` 即可构建，无需下载模型。即使本机本目录仍有被忽略的 `.onnx`，pubspec 也不会把它装入 APK。`test_zh.wav` 是上述模型包的官方中文样例，只用于引擎验收。

显式端到端下载验收（会下载约 230 MB，使用独立临时目录并在结束后清理）：

```powershell
flutter test integration_test/speech_engine_test.dart -d emulator-5554 --dart-define=ASR_DOWNLOAD_TEST=true
```

不提供该参数时，测试只使用应用私有目录已安装的模型；缺模型会真实失败，不静默下载。
