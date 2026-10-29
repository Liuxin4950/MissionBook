import 'dart:typed_data';

/// 本地离线语音后端；页面只依赖这个接口，不直接碰 sherpa-onnx。
abstract interface class LocalSpeechBackend {
  bool get supported;
  String? get lastError;

  Future<bool> hasModel();

  /// 只加载已安装的模型，成功后保持常驻 worker；不下载。
  Future<bool> prepare();

  /// 输入 16kHz 单声道 PCM16，返回识别文字。
  Future<String> transcribe(Uint8List pcm16);

  Future<void> dispose();
}
