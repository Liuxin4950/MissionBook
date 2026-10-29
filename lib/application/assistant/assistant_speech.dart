import 'dart:async';

import 'package:flutter/foundation.dart';

/// 系统短句识别只产生文字，业务统一交给 AssistantController。
abstract interface class AssistantSpeech {
  Future<bool> start({
    required void Function(String) onText,
    required VoidCallback onDone,
    required void Function(String) onError,
  });
  Future<void> stop();
  Future<void> cancel();
}

class AssistantVoiceController extends ChangeNotifier {
  AssistantVoiceController(
    this._speech, {
    this.startTimeout = const Duration(seconds: 15),
    this.operationTimeout = const Duration(seconds: 3),
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

  bool get busy => starting || stopping;

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
      if (!available) error ??= '系统语音服务不可用或麦克风未获授权，可以重试或改用文字。';
      if (listening) _watchdog = Timer(listeningLimit, stop);
    } on TimeoutException {
      if (current()) {
        ++_generation; // 迟到的权限/识别回调不能重新开启这一轮。
        starting = false;
        listening = false;
        error = '系统语音服务响应超时。请检查麦克风权限和系统语音服务，或改用文字。';
        unawaited(_cancelSystem());
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
    if (_closed || stopping) return;
    if (starting) {
      await cancel();
      return;
    }
    _watchdog?.cancel();
    stopping = true;
    notifyListeners();
    try {
      await _speech.stop().timeout(operationTimeout);
    } catch (_) {
      if (!_closed) error = '系统未能及时结束识别，已保留现有文字，可以检查后发送。';
    } finally {
      listening = false;
      stopping = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<void> _cancelSystem() async {
    try {
      await _speech.cancel().timeout(operationTimeout);
    } catch (_) {
      // UI 已撤销这一轮；迟到回调由 generation 隔离，平台恢复后仍可再试。
    }
  }

  Future<void> cancel() async {
    ++_generation;
    _watchdog?.cancel();
    starting = false;
    stopping = false;
    listening = false;
    text = '';
    error = null;
    if (!_closed) notifyListeners();
    await _cancelSystem();
  }

  @override
  void dispose() {
    _closed = true;
    ++_generation;
    _watchdog?.cancel();
    unawaited(_cancelSystem());
    super.dispose();
  }
}
