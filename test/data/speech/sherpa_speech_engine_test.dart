import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/speech/sherpa_speech_engine.dart';
import 'package:mission_book/data/speech/speech_model_store_base.dart';

void _testWorker(SendPort main) {
  final receive = ReceivePort();
  main.send(receive.sendPort);
  var initializations = 0;
  receive.listen((message) {
    if (message is SpeechModelInitRequest) {
      initializations++;
      if (message.model == 'stall') return;
      main.send(
        message.model == 'invalid'
            ? SpeechWorkerFailure(message.id, '测试模型不可用')
            : SpeechModelReady(message.id),
      );
    } else if (message is SpeechTranscribeRequest) {
      if (message.samples.firstOrNull == -1) Isolate.exit();
      if (message.samples.firstOrNull == -2) return;
      main.send(
        SpeechTextResult(
          message.id,
          'init:$initializations samples:${message.samples.length}',
        ),
      );
    } else if (message is SpeechWorkerDisposeRequest) {
      Isolate.exit(main, SpeechTextResult(message.id, ''));
    }
  });
}

void _silentWorker(SendPort main) {
  ReceivePort().listen((_) {});
}

SpeechModelPaths _paths([String model = 'valid']) => SpeechModelPaths(
  directory: 'test-only',
  model: model,
  tokens: 'test-tokens',
);

void main() {
  test('并发 prepare 只初始化一次；识别请求完整往返，关闭幂等', () async {
    final engine = SherpaSpeechEngine(workerMain: _testWorker);
    addTearDown(engine.dispose);
    await Future.wait([engine.prepare(_paths()), engine.prepare(_paths())]);
    expect(await engine.transcribe(Float32List(3)), 'init:1 samples:3');
    await Future.wait([engine.dispose(), engine.dispose()]);
    await expectLater(engine.prepare(_paths()), throwsStateError);
    await expectLater(engine.transcribe(Float32List(1)), throwsStateError);
  });

  test('模型初始化失败可重试，不把失败缓存成已准备', () async {
    final engine = SherpaSpeechEngine(workerMain: _testWorker);
    addTearDown(engine.dispose);
    await expectLater(engine.transcribe(Float32List(1)), throwsStateError);
    await expectLater(engine.prepare(_paths('invalid')), throwsStateError);
    await engine.prepare(_paths());
    expect(await engine.transcribe(Float32List(1)), 'init:2 samples:1');
  });

  test('worker 意外退出拒绝待处理请求，下一次 prepare 可重新连接', () async {
    final engine = SherpaSpeechEngine(workerMain: _testWorker);
    addTearDown(engine.dispose);
    await engine.prepare(_paths());
    await expectLater(
      engine.transcribe(Float32List.fromList([-1])),
      throwsStateError,
    );
    await engine.prepare(_paths());
    expect(await engine.transcribe(Float32List(1)), 'init:1 samples:1');
  });

  test('worker 不握手会超时并释放，dispose 不等待失联进程', () async {
    final engine = SherpaSpeechEngine(
      workerMain: _silentWorker,
      initializationTimeout: const Duration(milliseconds: 100),
    );
    await expectLater(
      engine.prepare(_paths()),
      throwsA(isA<TimeoutException>()),
    );
    await engine.dispose();
  });

  test('初始化途中关闭不会让迟到连接复活或遗留未处理 Future', () async {
    final engine = SherpaSpeechEngine(workerMain: _testWorker);
    final rejected = expectLater(
      engine.prepare(_paths('stall')),
      throwsStateError,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await engine.dispose();
    await rejected;
    await expectLater(engine.prepare(_paths()), throwsStateError);
  });

  test('识别超时重置 worker，模型可重建', () async {
    final engine = SherpaSpeechEngine(
      workerMain: _testWorker,
      transcriptionTimeout: const Duration(milliseconds: 100),
    );
    addTearDown(engine.dispose);
    await engine.prepare(_paths());
    await expectLater(
      engine.transcribe(Float32List.fromList([-2])),
      throwsA(isA<TimeoutException>()),
    );
    await engine.prepare(_paths());
    expect(await engine.transcribe(Float32List(1)), 'init:1 samples:1');
  });
}
