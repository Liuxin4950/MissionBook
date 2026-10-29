import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:mission_book/data/assistant/system_assistant_speech.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');

  test('系统语言列表永不返回时，仍会使用默认语言调用实际listen', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'locales') return Completer<List<String>>().future;
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final speech = SystemAssistantSpeech(
      speech: SpeechToText.withMethodChannel(),
      localeTimeout: const Duration(milliseconds: 20),
    );
    try {
      final started = await speech.start(
        onText: (_) {},
        onDone: () {},
        onError: (_) {},
      );
      expect(started, isTrue);
      expect(calls, contains('listen'));
    } finally {
      await speech.cancel();
    }
  });
}
