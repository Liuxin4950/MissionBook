import 'speech_model_store_base.dart';

SpeechModelStore createSpeechModelStore() => _StubSpeechModelStore();

class _StubSpeechModelStore implements SpeechModelStore {
  @override
  bool get supported => false;
  @override
  int get downloadBytes => 0;
  @override
  void cancelDownload() {}
  @override
  Future<SpeechModelPaths> download({
    required void Function(int received, int total) onProgress,
  }) async => throw UnsupportedError('当前平台不支持离线语音模型。');

  @override
  Future<SpeechModelPaths?> findInstalled() async => null;

  @override
  Future<SpeechModelPaths> ensureInstalled() async {
    throw UnsupportedError('当前平台不支持离线语音模型。');
  }
}
