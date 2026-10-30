import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_speech.dart';

class ControlledSpeech implements AssistantSpeech {
  Completer<bool>? permission;
  Completer<void>? stoppingGate;
  bool available = true;
  void Function(String)? emit;
  void Function(String)? fail;
  VoidCallback? done;
  VoidCallback? processing;
  @override
  Future<bool> start({
    required void Function(String) onText,
    required VoidCallback onDone,
    VoidCallback? onProcessing,
    required void Function(String) onError,
  }) async {
    emit = onText;
    done = onDone;
    processing = onProcessing;
    fail = onError;
    return permission == null ? available : permission!.future;
  }

  @override
  Future<void> stop() async {
    if (stoppingGate != null) {
      await stoppingGate!.future;
      return;
    }
    done?.call();
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  test('录音达到上限后直接进入转写状态，完成前不能重复录音', () async {
    final speech = ControlledSpeech();
    final voice = AssistantVoiceController(speech);
    await voice.start();
    speech.processing!();
    expect(voice.listening, isFalse);
    expect(voice.stopping, isTrue);
    await voice.start();
    expect(voice.stopping, isTrue);
    speech.emit!('识别成功');
    speech.done!();
    expect(voice.busy, isFalse);
    expect(voice.text, '识别成功');
    voice.dispose();
  });

  test('转写等待期间取消再重录，旧停止流程不能关闭新一轮', () async {
    final speech = ControlledSpeech()..stoppingGate = Completer<void>();
    final voice = AssistantVoiceController(speech);
    await voice.start();
    final previous = voice.stop();
    await voice.cancel();
    await voice.start();
    speech.emit!('新一轮内容');
    speech.stoppingGate!.complete();
    await previous;
    expect(voice.listening, isTrue);
    expect(voice.text, '新一轮内容');
    voice.dispose();
  });
  test('系统提前结束后保留转写，取消后旧识别结果不能覆盖新草稿', () async {
    final speech = ControlledSpeech();
    final voice = AssistantVoiceController(speech);
    await voice.start();
    speech.emit!('调整任务');
    speech.done!();
    expect(voice.listening, isFalse);
    expect(voice.text, '调整任务');
    final oldEmit = speech.emit!;
    await voice.cancel();
    await voice.start();
    speech.emit!('新的内容');
    oldEmit('过时结果');
    expect(voice.text, '新的内容');
    voice.dispose();
    speech.emit!('释放后的结果');
  });

  test('拒绝麦克风与识别错误都有可恢复状态', () async {
    final speech = ControlledSpeech()..available = false;
    final voice = AssistantVoiceController(speech);
    await voice.start();
    expect(voice.error, isNotNull);
    expect(voice.starting, isFalse);
    expect(voice.listening, isFalse);
    speech.available = true;
    await voice.start();
    expect(voice.error, isNull);
    speech.fail!('系统识别中断');
    expect(voice.listening, isFalse);
    expect(voice.error, '系统识别中断');
    voice.dispose();
  });

  test('权限等待期间取消，迟到的初始化不会恢复录音状态', () async {
    final speech = ControlledSpeech()..permission = Completer<bool>();
    final voice = AssistantVoiceController(speech);
    final starting = voice.start();
    await voice.cancel();
    speech.permission!.complete(true);
    await starting;
    expect(voice.starting, isFalse);
    expect(voice.listening, isFalse);
    expect(voice.text, isEmpty);
    voice.dispose();
  });
  test('系统启动永不返回时会超时退出，迟到结果不能重开录音', () async {
    final speech = ControlledSpeech()..permission = Completer<bool>();
    final voice = AssistantVoiceController(
      speech,
      startTimeout: const Duration(milliseconds: 20),
    );
    await voice.start();
    expect(voice.starting, isFalse);
    expect(voice.listening, isFalse);
    expect(voice.error, contains('超时'));
    speech.permission!.complete(true);
    speech.emit!('迟到的结果');
    await Future<void>.delayed(Duration.zero);
    expect(voice.text, isEmpty);
    expect(voice.listening, isFalse);
    voice.dispose();
  });

  test('转写结束后可修正文字，空白内容与实际内容随编辑更新', () async {
    final speech = ControlledSpeech();
    final voice = AssistantVoiceController(speech);
    await voice.start();
    speech.emit!('原始识别');
    speech.done!();
    voice.editText('修正后的任务');
    expect(voice.text, '修正后的任务');
    voice.editText('');
    expect(voice.text, isEmpty);
    voice.dispose();
  });
}
