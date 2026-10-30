import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'speech_model_store_base.dart';

/// SenseVoice 的常驻 worker isolate。
///
/// FFI 识别器和音频流只存在于 worker 内；主 isolate 只发送模型路径和 PCM，
/// 接收文字。所有请求串行执行，避免多个 decode 同时占用 CPU。
class SherpaSpeechEngine {
  Isolate? _isolate;
  ReceivePort? _receive;
  SendPort? _send;
  final _pending = <int, Completer<_EngineResponse>>{};
  int _nextId = 0;
  bool _ready = false;
  bool _disposed = false;
  Future<void>? _starting;

  Future<void> prepare(SpeechModelPaths paths) async {
    if (_disposed) throw StateError('离线语音引擎已关闭');
    if (_ready) return;
    try {
      await (_starting ??= _start());
    } catch (_) {
      _starting = null; // 允许下一次语音重试，而不是永久沿用一次启动失败。
      rethrow;
    }
    final id = _nextId++;
    final completer = Completer<_EngineResponse>();
    _pending[id] = completer;
    _send!.send(_InitRequest(id, paths.model, paths.tokens));
    final _EngineResponse response;
    try {
      response = await completer.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _pending.remove(id);
      _resetWorker(TimeoutException('离线语音引擎初始化超时'));
      rethrow;
    }
    if (response is _Failure) throw StateError(response.message);
    _ready = true;
  }

  Future<void> _start() async {
    final receive = ReceivePort();
    _receive = receive;
    final ready = Completer<SendPort>();
    receive.listen((message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      if (message is _EngineResponse) {
        final completer = _pending.remove(message.id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(message);
        }
        return;
      }
      if (message is List && message.length >= 2) {
        // Isolate.spawn 的 onError 通道：识别器初始化出现未捕获异常。
        final error = StateError('离线语音引擎初始化失败：${message.first}');
        if (!ready.isCompleted) ready.completeError(error);
        if (!_disposed) _resetWorker(error);
        return;
      }
      if (message == null) {
        // onExit：worker 已退出。下一次准备会重建 isolate，不能永久复用失效状态。
        if (_disposed) {
          _failPending(StateError('离线语音引擎已关闭'));
          return;
        }
        final error = StateError('离线语音引擎已退出');
        if (!ready.isCompleted) ready.completeError(error);
        _resetWorker(error);
      }
    });
    _isolate = await Isolate.spawn(
      _engineMain,
      receive.sendPort,
      onError: receive.sendPort,
      onExit: receive.sendPort,
      debugName: 'missionbook-asr',
    );
    _send = await ready.future;
  }

  Future<String> transcribe(Float32List samples) async {
    if (_disposed) throw StateError('离线语音引擎已关闭');
    if (!_ready) throw StateError('离线语音模型未准备');
    final id = _nextId++;
    final completer = Completer<_EngineResponse>();
    _pending[id] = completer;
    _send!.send(_TranscribeRequest(id, samples));
    final _EngineResponse response;
    try {
      response = await completer.future.timeout(const Duration(seconds: 60));
    } on TimeoutException {
      _pending.remove(id);
      _resetWorker(TimeoutException('离线语音识别超时'));
      rethrow;
    }
    if (response is _Text) return response.text;
    throw StateError(response is _Failure ? response.message : '离线语音识别失败');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final send = _send;
    if (send != null) {
      final id = _nextId++;
      final completer = Completer<_EngineResponse>();
      _pending[id] = completer;
      send.send(_DisposeRequest(id));
      try {
        await completer.future.timeout(const Duration(seconds: 3));
      } catch (_) {
        // 关闭阶段不再等待异常 worker。
      }
    }
    _isolate?.kill(priority: Isolate.immediate);
    _receive?.close();
    _failPending(StateError('离线语音引擎已关闭'));
  }

  /// worker 异常退出或超时后清空连接，下一次 prepare 会重新启动。
  void _resetWorker(Object error) {
    _ready = false;
    _starting = null;
    _send = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receive?.close();
    _receive = null;
    _failPending(error);
  }

  void _failPending(Object error) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }
}

class _InitRequest {
  const _InitRequest(this.id, this.model, this.tokens);
  final int id;
  final String model;
  final String tokens;
}

class _TranscribeRequest {
  const _TranscribeRequest(this.id, this.samples);
  final int id;
  final Float32List samples;
}

class _DisposeRequest {
  const _DisposeRequest(this.id);
  final int id;
}

sealed class _EngineResponse {
  const _EngineResponse(this.id);
  final int id;
}

class _Ready extends _EngineResponse {
  const _Ready(super.id);
}

class _Text extends _EngineResponse {
  const _Text(super.id, this.text);
  final String text;
}

class _Failure extends _EngineResponse {
  const _Failure(super.id, this.message);
  final String message;
}

void _engineMain(SendPort main) {
  final receive = ReceivePort();
  // 每个 isolate 有独立的 FFI 绑定；必须在 worker 内初始化。
  sherpa.initBindings();
  main.send(receive.sendPort);

  sherpa.OfflineRecognizer? recognizer;
  receive.listen((message) {
    try {
      if (message is _InitRequest) {
        final config = sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            senseVoice: sherpa.OfflineSenseVoiceModelConfig(
              model: message.model,
              language: 'zh',
              useInverseTextNormalization: true,
            ),
            tokens: message.tokens,
            numThreads: 2,
            debug: false,
          ),
        );
        final next = sherpa.OfflineRecognizer(config);
        final old = recognizer;
        recognizer = next;
        old?.free();
        try {
          _decode(next, Float32List(1600));
        } catch (_) {
          // 预热失败不影响真正识别。
        }
        main.send(_Ready(message.id));
      } else if (message is _TranscribeRequest) {
        final current = recognizer;
        if (current == null) {
          main.send(_Failure(message.id, '离线语音模型未初始化'));
          return;
        }
        if (message.samples.isEmpty) {
          main.send(_Text(message.id, ''));
          return;
        }
        final text = _decode(current, message.samples);
        main.send(_Text(message.id, text));
      } else if (message is _DisposeRequest) {
        recognizer?.free();
        recognizer = null;
        Isolate.exit(main, _Text(message.id, ''));
      }
    } catch (error) {
      final id = message is _InitRequest
          ? message.id
          : message is _TranscribeRequest
          ? message.id
          : message is _DisposeRequest
          ? message.id
          : -1;
      main.send(_Failure(id, '$error'));
    }
  });
}

String _decode(sherpa.OfflineRecognizer recognizer, Float32List samples) {
  final stream = recognizer.createStream();
  try {
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    recognizer.decode(stream);
    return recognizer.getResult(stream).text.trim();
  } finally {
    stream.free();
  }
}
