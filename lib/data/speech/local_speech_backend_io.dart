import 'dart:io';
import 'dart:typed_data';

import 'local_speech_backend_base.dart';
import 'pcm_utils.dart';
import 'sherpa_speech_engine.dart';
import 'speech_model_store.dart';

LocalSpeechBackend createLocalSpeechBackend({SpeechModelStore? modelStore}) =>
    _IoLocalSpeechBackend(modelStore ?? createSpeechModelStore());

class _IoLocalSpeechBackend implements LocalSpeechBackend {
  _IoLocalSpeechBackend(this._store);
  final SpeechModelStore _store;
  final _engine = SherpaSpeechEngine();
  Future<bool>? _prepare;
  String? _lastError;

  // Windows 端当前 sherpa_onnx 预编译包的 ONNX Runtime 版本不匹配，先只在 Android 启用。
  @override
  bool get supported => Platform.isAndroid;

  @override
  String? get lastError => _lastError;

  @override
  Future<bool> hasModel() async => await _store.findInstalled() != null;

  @override
  Future<bool> prepare() {
    final existing = _prepare;
    if (existing != null) return existing;
    final future = _prepareInternal();
    _prepare = future;
    return future;
  }

  Future<bool> _prepareInternal() async {
    try {
      final paths = await _store.ensureInstalled();
      await _engine.prepare(paths);
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = '离线语音模型准备失败：$error';
      _prepare = null; // 允许用户重试，而不是永久记住一次资源错误。
      return false;
    }
  }

  @override
  Future<String> transcribe(Uint8List pcm16) async {
    if (!await prepare()) {
      throw FormatException(_lastError ?? '离线语音模型未就绪，请稍后重试。');
    }
    return _engine.transcribe(pcm16ToFloat32(pcm16));
  }

  @override
  Future<void> dispose() => _engine.dispose();
}
