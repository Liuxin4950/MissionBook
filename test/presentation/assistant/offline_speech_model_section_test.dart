import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/speech/speech_model_store.dart';
import 'package:mission_book/presentation/assistant/offline_speech_model_section.dart';

void main() {
  testWidgets('打开设置不下载；用户点击后显示进度；取消后可重试', (tester) async {
    final store = _Models();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OfflineSpeechModelSection(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.downloads, 0);
    expect(find.text('离线模型未下载（可选）'), findsOneWidget);
    await tester.tap(find.byKey(const Key('offline-model-download')));
    await tester.pump();
    store.progress!(50, 100);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(store.downloads, 1);
    await tester.tap(find.byKey(const Key('offline-model-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('下载已取消，可随时重新下载。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('offline-model-download')));
    await tester.pump();
    store.installed = true;
    store.pending!.complete(_paths);
    await tester.pumpAndSettle();
    expect(find.text('离线模型已就绪 · 无网可用'), findsOneWidget);
    expect(find.byKey(const Key('offline-model-download')), findsNothing);
  });

  testWidgets('离开设置取消下载；不支持的平台不提供下载按钮', (tester) async {
    final store = _Models();
    await tester.pumpWidget(
      MaterialApp(home: OfflineSpeechModelSection(store: store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('offline-model-download')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(store.pending!.isCompleted, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: OfflineSpeechModelSection(store: _Models()..supported = false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offline-model-download')), findsNothing);
  });
}

const _paths = SpeechModelPaths(
  directory: '/speech',
  model: '/model',
  tokens: '/tokens',
);

class _Models implements SpeechModelStore {
  @override
  bool supported = true;
  bool installed = false;
  int downloads = 0;
  Completer<SpeechModelPaths>? pending;
  void Function(int, int)? progress;
  @override
  int get downloadBytes => 100;
  @override
  Future<SpeechModelPaths?> findInstalled() async => installed ? _paths : null;
  @override
  Future<SpeechModelPaths> ensureInstalled() async => _paths;
  @override
  Future<SpeechModelPaths> download({
    required void Function(int, int) onProgress,
  }) {
    downloads++;
    progress = onProgress;
    pending = Completer<SpeechModelPaths>();
    return pending!.future;
  }

  @override
  void cancelDownload() {
    if (pending != null && !pending!.isCompleted) {
      pending!.completeError(const SpeechModelDownloadCancelled());
    }
  }
}
