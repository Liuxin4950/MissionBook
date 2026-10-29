import 'dart:async';

import 'package:flutter/foundation.dart';

/// 语音只产生文字，业务统一交给 AssistantController。
abstract interface class AssistantSpeech {
  Future<bool> start({
    required void Function(String) onText,
    required VoidCallback onDone,
    required void Function(String) onError,
  });
  Future<void> stop();
  Future<void> cancel();
}

/// 可提前加载已有模型的语音实现；预热不得自动下载。
abstract interface class WarmUpSpeech {
  Future<void> warmUp();
}

class AssistantVoiceController extends ChangeNotifier {
  AssistantVoiceController(
    this._speech, {
    this.startTimeout = const Duration(seconds: 15),
    this.operationTimeout = const Duration(seconds: 40),
    this.listeningLimit = const Duration(seconds: 50),
  });

  final AssistantSpeech _speech;
  final Duration startTimeout;
  final Duration operationTimeout;
  final Duration listeningLimit;
  String text = '';
  String? error;
  bool listening = false;
  bool starting = false;
  bool stopping = false;
  int _generation = 0;
  bool _closed = false;
  Timer? _watchdog;
  Future<void>? _cancellation;
  bool _cancelling = false;

  bool get busy => starting || stopping || _cancelling;

  /// 页面打开后可在后台加载已有模型；失败由下一次 start 再重试。
  Future<void> warmUp() async {
    final speech = _speech;
    if (speech is WarmUpSpeech) await (speech as WarmUpSpeech).warmUp();
  }

  void editText(String value) {
    if (_closed || listening || busy) return;
    ++_generation; // 手动修正后不再接受这一段识别迟到的最终文字。
    text = value;
    notifyListeners();
  }

  Future<void> start() async {
    if (_closed || busy || listening) return;
    final generation = ++_generation;
    starting = true;
    text = '';
    error = null;
    notifyListeners();
    var finished = false;
    bool current() => !_closed && generation == _generation;
    try {
      final available = await _speech
          .start(
            onText: (value) {
              if (current()) {
                text = value;
                notifyListeners();
              }
            },
            onDone: () {
              finished = true;
              if (current()) {
                _watchdog?.cancel();
                listening = false;
                notifyListeners();
              }
            },
            onError: (value) {
              finished = true;
              if (current()) {
                _watchdog?.cancel();
                error = value;
                listening = false;
                notifyListeners();
              }
            },
          )
          .timeout(startTimeout);
      if (!current()) return;
      listening = available && !finished;
      if (!available) error ??= '语音识别不可用或麦克风未获授权，可以重试或改用文字。';
      if (listening) _watchdog = Timer(listeningLimit, stop);
    } on TimeoutException {
      if (current()) {
        ++_generation; // 迟到的权限/识别回调不能重新开启这一轮。
        starting = false;
        listening = false;
        error = '语音启动超时，请检查麦克风权限，或改用文字。';
        unawaited(_cancel(clear: false));
        notifyListeners();
      }
    } catch (_) {
      if (current()) error = '无法启动语音识别，请检查麦克风权限或改用文字。';
    } finally {
      if (current()) {
        starting = false;
        notifyListeners();
      }
    }
  }

  Future<void> stop() async {
    if (_closed || stopping || _cancelling || (!listening && !starting)) return;
    if (starting) {
      await cancel();
      return;
    }
    _watchdog?.cancel();
    final generation = _generation;
    bool current() => !_closed && generation == _generation;
    stopping = true;
    notifyListeners();
    try {
      await _speech.stop().timeout(operationTimeout);
    } catch (_) {
      if (current()) {
        error = '语音未能及时结束，已保留现有文字，可以检查后发送。';
        unawaited(_cancel(clear: false));
      }
    } finally {
      if (current()) {
        listening = false;
        stopping = false;
        notifyListeners();
      }
    }
  }

  Future<void> _cancelSystem() async {
    try {
      await _speech.cancel().timeout(const Duration(seconds: 3));
    } catch (_) {
      // UI 已撤销这一轮；迟到回调由 generation 隔离，平台恢复后仍可再试。
    }
  }

  Future<void> cancel() => _cancel(clear: true);

  Future<void> _cancel({required bool clear}) {
    // 关闭/重试/生命周期可能同时取消；所有调用共享同一次资源释放。
    final pending = _cancellation;
    if (pending != null) return pending;
    final operation = _cancelCurrent(clear: clear);
    _cancellation = operation;
    return operation.whenComplete(() => _cancellation = null);
  }

  Future<void> _cancelCurrent({required bool clear}) async {
    ++_generation;
    _watchdog?.cancel();
    starting = false;
    stopping = false;
    listening = false;
    _cancelling = true;
    if (clear) {
      text = '';
      error = null;
    }
    if (!_closed) notifyListeners();
    try {
      await _cancelSystem();
    } finally {
      _cancelling = false;
      if (!_closed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    ++_generation;
    _watchdog?.cancel();
    unawaited(cancel());
    super.dispose();
  }
}
