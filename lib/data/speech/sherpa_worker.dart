part of 'sherpa_speech_engine.dart';

void _engineMain(SendPort main) {
  final receive = ReceivePort();
  // 每个 isolate 有独立的 FFI 绑定；必须在 worker 内初始化。
  sherpa.initBindings();
  main.send(receive.sendPort);

  sherpa.OfflineRecognizer? recognizer;
  receive.listen((message) {
    try {
      if (message is SpeechModelInitRequest) {
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
        main.send(SpeechModelReady(message.id));
      } else if (message is SpeechTranscribeRequest) {
        final current = recognizer;
        if (current == null) {
          main.send(SpeechWorkerFailure(message.id, '离线语音模型未初始化'));
          return;
        }
        if (message.samples.isEmpty) {
          main.send(SpeechTextResult(message.id, ''));
          return;
        }
        final text = _decode(current, message.samples);
        main.send(SpeechTextResult(message.id, text));
      } else if (message is SpeechWorkerDisposeRequest) {
        recognizer?.free();
        recognizer = null;
        Isolate.exit(main, SpeechTextResult(message.id, ''));
      }
    } catch (error) {
      final id = message is SpeechModelInitRequest
          ? message.id
          : message is SpeechTranscribeRequest
          ? message.id
          : message is SpeechWorkerDisposeRequest
          ? message.id
          : -1;
      main.send(SpeechWorkerFailure(id, '$error'));
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
