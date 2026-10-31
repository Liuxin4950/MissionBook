import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'speech_model_store_base.dart';

part 'speech_worker_protocol.dart';
part 'sherpa_worker.dart';

/// SenseVoice 的常驻 worker isolate。
///
/// FFI 识别器和音频流只存在于 worker 内；主 isolate 只发送模型路径和 PCM，
/// 接收文字。所有请求串行执行，避免多个 decode 同时占用 CPU。
class SherpaSpeechEngine {
  SherpaSpeechEngine({
    this.workerMain = _engineMain,
    this.initializationTimeout = const Duration(seconds: 30),
    this.transcriptionTimeout = const Duration(seconds: 60),
    this.shutdownTimeout = const Duration(seconds: 3),
  });

  // worker 入口可注入，测试生命周期时不依赖设备模型和原生 FFI。
  final void Function(SendPort) workerMain;
  final Duration initializationTimeout;
  final Duration transcriptionTimeout;
  final Duration shutdownTimeout;
  Isolate? _isolate;
  ReceivePort? _receive;
  SendPort? _send;
  final _pending = <int, Completer<SpeechWorkerResponse>>{};
  int _nextId = 0;
  bool _ready = false;
  bool _disposed = false;
  Future<void>? _starting;
  Future<void>? _preparing;
  Future<void>? _disposing;
  Completer<SendPort>? _handshake;
  int _generation = 0;

  /// 并发准备共用一次模型初始化；失败后可重试，关闭后的实例不能复活。
  Future<void> prepare(SpeechModelPaths paths) {
    if (_disposed) return Future.error(StateError('离线语音引擎已关闭'));
    if (_ready) return Future.value();
    final pending = _preparing;
    if (pending != null) return pending;
    late final Future<void> future;
    future = _prepare(paths).whenComplete(() {
      if (identical(_preparing, future)) _preparing = null;
    });
    _preparing = future;
    return future;
  }

  Future<void> _prepare(SpeechModelPaths paths) async {
    try {
      await (_starting ??= _start());
    } catch (_) {
      _starting = null; // 允许下一次语音重试，而不是永久沿用一次启动失败。
      rethrow;
    }
    if (_disposed || _send == null) throw StateError('离线语音引擎已关闭');
    final id = _nextId++;
    final completer = Completer<SpeechWorkerResponse>();
    _pending[id] = completer;
    _send!.send(SpeechModelInitRequest(id, paths.model, paths.tokens));
    final SpeechWorkerResponse response;
    try {
      response = await completer.future.timeout(initializationTimeout);
    } on TimeoutException {
      _pending.remove(id);
      _resetWorker(TimeoutException('离线语音引擎初始化超时'));
      rethrow;
    }
    if (response is SpeechWorkerFailure) throw StateError(response.message);
    if (_disposed) throw StateError('离线语音引擎已关闭');
    _ready = true;
  }

  Future<void> _start() async {
    final generation = _generation;
    final receive = ReceivePort();
    _receive = receive;
    final ready = Completer<SendPort>();
    _handshake = ready;
    receive.listen((message) {
      if (generation != _generation) return;
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      if (message is SpeechWorkerResponse) {
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
    final spawn =
        Isolate.spawn(
          workerMain,
          receive.sendPort,
          onError: receive.sendPort,
          onExit: receive.sendPort,
          debugName: 'missionbook-asr',
        ).then<void>((isolate) {
          if (_disposed || generation != _generation) {
            isolate.kill(priority: Isolate.immediate);
            throw StateError('离线语音引擎已关闭');
          }
          _isolate = isolate;
        });
    final connected = ready.future.then<void>((port) {
      if (_disposed || generation != _generation) {
        throw StateError('离线语音引擎已关闭');
      }
      _send = port;
    });
    try {
      // 同时监听握手与 spawn 的错误；dispose 不会留下尚未被等待的错误 Future。
      await Future.wait([
        spawn,
        connected,
      ], eagerError: true).timeout(initializationTimeout);
    } catch (error) {
      if (generation == _generation) _resetWorker(error);
      rethrow;
    }
  }

  Future<String> transcribe(Float32List samples) async {
    if (_disposed) throw StateError('离线语音引擎已关闭');
    if (!_ready) throw StateError('离线语音模型未准备');
    final id = _nextId++;
    final completer = Completer<SpeechWorkerResponse>();
    _pending[id] = completer;
    _send!.send(SpeechTranscribeRequest(id, samples));
    final SpeechWorkerResponse response;
    try {
      response = await completer.future.timeout(transcriptionTimeout);
    } on TimeoutException {
      _pending.remove(id);
      _resetWorker(TimeoutException('离线语音识别超时'));
      rethrow;
    }
    if (response is SpeechTextResult) return response.text;
    throw StateError(
      response is SpeechWorkerFailure ? response.message : '离线语音识别失败',
    );
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _ready = false;
    final closed = StateError('离线语音引擎已关闭');
    final handshake = _handshake;
    if (handshake != null && !handshake.isCompleted) {
      handshake.completeError(closed);
    }
    _failPending(closed);
    final send = _send;
    if (send != null) {
      final id = _nextId++;
      final completer = Completer<SpeechWorkerResponse>();
      _pending[id] = completer;
      send.send(SpeechWorkerDisposeRequest(id));
      try {
        await completer.future.timeout(shutdownTimeout);
      } catch (_) {
        // 关闭阶段不再等待异常 worker。
      }
    }
    _resetWorker(closed);
  }

  /// worker 异常退出或超时后清空连接，下一次 prepare 会重新启动。
  void _resetWorker(Object error) {
    _generation++;
    final handshake = _handshake;
    _handshake = null;
    if (handshake != null && !handshake.isCompleted) {
      handshake.completeError(error);
    }
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
