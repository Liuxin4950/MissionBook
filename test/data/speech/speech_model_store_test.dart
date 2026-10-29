import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mission_book/data/speech/speech_model_store_base.dart';
import 'package:mission_book/data/speech/speech_model_store_io.dart';

void main() {
  late Directory directory;
  final content = <String, List<int>>{
    'model.int8.onnx': [1, 2, 3, 4],
    'tokens.txt': [5, 6, 7],
  };
  final files = content.entries
      .map(
        (entry) => SpeechModelFile(
          entry.key,
          entry.value.length,
          sha256.convert(entry.value).toString(),
          'https://models.example/${entry.key}',
        ),
      )
      .toList();
  setUp(
    () async => directory = await Directory.systemTemp.createTemp('asr-test-'),
  );
  tearDown(() async => directory.delete(recursive: true));
  IoSpeechModelStore store(http.Client Function() client) => IoSpeechModelStore(
    directory: () async => directory,
    clientFactory: client,
    files: files,
    supported: true,
  );

  test('检查与预热只查本地，缺模型不联网', () async {
    final models = store(() => throw StateError('不应创建网络连接'));
    expect(await models.findInstalled(), isNull);
    await expectLater(models.ensureInstalled(), throwsFormatException);
    expect(await directory.list().isEmpty, isTrue);
  });

  test('用户选择后流式下载，两个 SHA256 都通过才生效，重复下载复用安装', () async {
    var requests = 0;
    final models = store(
      () => MockClient((request) async {
        requests++;
        return http.Response.bytes(
          content[request.url.pathSegments.last]!,
          200,
        );
      }),
    );
    final progress = <int>[];
    final paths = await models.download(
      onProgress: (bytes, _) => progress.add(bytes),
    );
    expect(await File(paths.model).readAsBytes(), content['model.int8.onnx']);
    expect(await File(paths.tokens).readAsBytes(), content['tokens.txt']);
    expect(progress.last, 7);
    expect(await models.findInstalled(), isNotNull);
    await models.download(onProgress: (_, _) {});
    expect(requests, 2);
    expect(
      await directory
          .list()
          .where((file) => file.path.endsWith('.part'))
          .isEmpty,
      isTrue,
    );
  });

  test('同长度损坏文件也被 SHA256 拒绝，失败后可以重试', () async {
    var corrupt = true;
    final models = store(
      () => MockClient((request) async {
        final bytes = content[request.url.pathSegments.last]!;
        return http.Response.bytes(
          corrupt ? List.filled(bytes.length, 0) : bytes,
          200,
        );
      }),
    );
    await expectLater(
      models.download(onProgress: (_, _) {}),
      throwsFormatException,
    );
    expect(await models.findInstalled(), isNull);
    expect(await directory.list().isEmpty, isTrue);
    corrupt = false;
    await models.download(onProgress: (_, _) {});
    expect(await models.findInstalled(), isNotNull);
  });

  test('断流、错误响应和超出大小都不留下可用模型', () async {
    for (final response in [
      http.StreamedResponse(Stream.value([1, 2]), 200),
      http.StreamedResponse(Stream.value([1, 2, 3, 4, 5]), 200),
      http.StreamedResponse(const Stream.empty(), 503),
    ]) {
      final models = store(
        () => MockClient.streaming((_, _) async => response),
      );
      await expectLater(
        models.download(onProgress: (_, _) {}),
        throwsFormatException,
      );
      expect(await models.findInstalled(), isNull);
      expect(await directory.list().isEmpty, isTrue);
    }
  });

  test('连点下载共享一次任务；取消清理临时文件，随后可重试', () async {
    final released = Completer<void>();
    var requests = 0;
    final models = store(
      () => MockClient.streaming((request, _) async {
        requests++;
        if (requests == 1) await released.future;
        return http.StreamedResponse(
          Stream.value(content[request.url.pathSegments.last]!),
          200,
        );
      }),
    );
    final first = models.download(onProgress: (_, _) {});
    final second = models.download(onProgress: (_, _) {});
    expect(identical(first, second), isTrue);
    // 等待进入请求，然后模拟用户取消及网络返回。
    while (requests == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    final cancelled = expectLater(
      first,
      throwsA(isA<SpeechModelDownloadCancelled>()),
    );
    models.cancelDownload();
    released.complete();
    await cancelled;
    expect(await models.findInstalled(), isNull);
    expect(await directory.list().isEmpty, isTrue);
    await models.download(onProgress: (_, _) {});
    expect(await models.findInstalled(), isNotNull);
  });

  test('旧版私有目录文件经过摘要校验后复用，无需重新下载', () async {
    for (final entry in content.entries) {
      await File('${directory.path}/${entry.key}').writeAsBytes(entry.value);
    }
    final models = store(() => throw StateError('已有模型无需联网'));
    expect(await models.ensureInstalled(), isNotNull);
    expect(await File('${directory.path}/.verified').exists(), isTrue);
  });
}
