import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mission_book/data/speech/local_speech_backend.dart';
import 'package:mission_book/data/speech/speech_model_store.dart';
import 'package:mission_book/data/speech/speech_model_store_io.dart'
    show IoSpeechModelStore;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SenseVoice 本地模型识别官方中文样例', (tester) async {
    SpeechModelStore store = createSpeechModelStore();
    // 显式下载验收用独立空目录，不能因旧模型已存在而跳过真实下载。
    if (const bool.fromEnvironment('ASR_DOWNLOAD_TEST')) {
      final base = await getTemporaryDirectory();
      await base.create(recursive: true);
      final directory = await base.createTemp('asr-acceptance-');
      addTearDown(() => directory.delete(recursive: true));
      store = IoSpeechModelStore(directory: () async => directory);
      expect(await store.findInstalled(), isNull);
      final watch = Stopwatch()..start();
      var lastReport = 0;
      await store.download(
        onProgress: (received, total) {
          if (received - lastReport > 32 * 1024 * 1024 || received == total) {
            lastReport = received;
            // ignore: avoid_print
            print('ASR_DOWNLOAD_BYTES=$received/$total');
          }
        },
      );
      // ignore: avoid_print
      print('ASR_DOWNLOAD_MS=${watch.elapsedMilliseconds}');
    }
    final backend = createLocalSpeechBackend(modelStore: store);
    addTearDown(backend.dispose);
    expect(backend.supported, isTrue, reason: backend.lastError);

    final prepareWatch = Stopwatch()..start();
    expect(await backend.prepare(), isTrue, reason: backend.lastError);
    prepareWatch.stop();

    final data = await rootBundle.load('assets/models/sensevoice/test_zh.wav');
    final pcm = _pcmFromWav(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final decodeWatch = Stopwatch()..start();
    final text = await backend.transcribe(pcm);
    decodeWatch.stop();

    // 真机/模拟器测试日志由 flutter test 转发，便于核对模型是否真的出字。
    // ignore: avoid_print
    print('ASR_RESULT=$text');
    // ignore: avoid_print
    print('ASR_PREPARE_MS=${prepareWatch.elapsedMilliseconds}');
    // ignore: avoid_print
    print('ASR_DECODE_MS=${decodeWatch.elapsedMilliseconds}');

    expect(text, contains('开饭时间'));
    expect(text, contains('9点'));
    expect(text, contains('5点'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// 只接受应用当前录音格式：16kHz、单声道、16-bit PCM。
Uint8List _pcmFromWav(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  if (String.fromCharCodes(wav.sublist(0, 4)) != 'RIFF') {
    throw const FormatException('测试音频不是 RIFF/WAV');
  }
  var offset = 12;
  var sampleRate = 0;
  var channels = 0;
  var bits = 0;
  while (offset + 8 <= wav.length) {
    final id = String.fromCharCodes(wav.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (sampleRate != 16000 || channels != 1 || bits != 16) {
        throw FormatException(
          '测试音频格式不匹配：$sampleRate Hz / $channels 声道 / $bits bit',
        );
      }
      return wav.sublist(body, body + size);
    }
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('测试音频没有 data 块');
}
