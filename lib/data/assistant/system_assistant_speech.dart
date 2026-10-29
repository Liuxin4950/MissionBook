import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../application/assistant/assistant_speech.dart';

/// 每个 App 一个系统识别器；语言列表只是优化，不能挡住实际录音。
class SystemAssistantSpeech implements AssistantSpeech {
  SystemAssistantSpeech({
    SpeechToText? speech,
    this.localeTimeout = const Duration(seconds: 1),
  }) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  final Duration localeTimeout;
  void Function(String)? _onText;
  void Function(String)? _onError;
  VoidCallback? _onDone;
  Future<bool>? _initialization;
  bool _initialized = false;
  bool _active = false;
  int _generation = 0;
  String? _localeId;
  bool _localeChecked = false;
  Completer<void>? _finalResult;

  Future<bool> _initialize() => _initialization ??= _speech
      .initialize(
        options: [
          SpeechToText.androidIntentLookup,
          SpeechToText.androidNoBluetooth,
        ],
        onError: (error) {
          if (!_active) return;
          _active = false;
          final message = error.errorMsg;
          _onError?.call(
            message.contains('permission')
                ? '麦克风未获授权，请在系统设置中允许后重试，或改用文字。'
                : message.contains('language')
                ? '系统没有可用的当前语言识别服务，可切换系统语音服务或改用文字。'
                : message.contains('no_match') ||
                      message.contains('speech_timeout')
                ? '暂时没有识别到清晰语音，可以重说，或检查现有文字后发送。'
                : '语音识别中断，请检查系统语音服务或网络后重试。',
          );
        },
        onStatus: (status) {
          if (!_active) return;
          if (status == SpeechToText.notListeningStatus) {
            _onDone?.call(); // 结束录音后仍接收系统稍后送达的最终文字。
          } else if (status == SpeechToText.doneStatus) {
            _active = false;
            _onDone?.call();
          }
        },
      )
      .then(
        (value) {
          _initialized = value;
          if (!value) _initialization = null;
          return value;
        },
        onError: (Object error, StackTrace stack) {
          _initialization = null;
          Error.throwWithStackTrace(error, stack);
        },
      );

  @override
  Future<bool> start({
    required void Function(String) onText,
    required VoidCallback onDone,
    required void Function(String) onError,
  }) async {
    final generation = ++_generation;
    _onText = onText;
    _onDone = onDone;
    _onError = onError;
    _active = false;
    if (!_initialized && !await _initialize()) return false;
    if (generation != _generation) return false;
    if (!_localeChecked) {
      try {
        final locales = await _speech.locales().timeout(localeTimeout);
        _localeId = locales
            .where((item) => item.localeId.toLowerCase().startsWith('zh'))
            .firstOrNull
            ?.localeId;
      } catch (_) {
        // 部分 Android 服务不会回传语言广播，直接使用系统默认语言继续。
      }
      _localeChecked = true;
    }
    if (generation != _generation) return false;
    _active = true;
    _finalResult = Completer<void>();
    try {
      await _speech.listen(
        onResult: (result) {
          if (_active && generation == _generation) {
            _onText?.call(result.recognizedWords);
            if (result.finalResult && !(_finalResult?.isCompleted ?? true)) {
              _finalResult!.complete();
            }
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
      if (generation != _generation) {
        await _speech.cancel();
        return false;
      }
      return true;
    } catch (_) {
      _active = false;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    if (_initialized) await _speech.stop();
    if (_active && _finalResult != null) {
      await _finalResult!.future.timeout(
        const Duration(milliseconds: 2200),
        onTimeout: () {},
      );
    }
    _active = false;
  }

  @override
  Future<void> cancel() async {
    ++_generation;
    _active = false;
    if (_initialized) await _speech.cancel();
  }
}
