import 'dart:typed_data';

import 'local_speech_backend_base.dart';
import 'speech_model_store_base.dart';

LocalSpeechBackend createLocalSpeechBackend({SpeechModelStore? modelStore}) =>
    _StubLocalSpeechBackend();

class _StubLocalSpeechBackend implements LocalSpeechBackend {
  @override
  bool get supported => false;

  @override
  String? get lastError => '当前平台不支持离线语音，请使用文字输入或配置录音转写服务。';

  @override
  Future<bool> prepare() async => false;

  @override
  Future<bool> hasModel() async => false;

  @override
  Future<String> transcribe(Uint8List pcm16) async {
    throw UnsupportedError(lastError!);
  }

  @override
  Future<void> dispose() async {}
}
