import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/memory/memory_settings.dart';
import 'package:mission_book/domain/entities/analysis_scope.dart';

class _Settings implements MemorySettingsStore {
  bool enabled = true;
  Completer<void>? readStarted;
  Completer<bool>? delayedRead;

  @override
  Future<bool> extractionEnabled() async {
    final pending = delayedRead;
    if (pending != null) {
      readStarted!.complete();
      return pending.future;
    }
    return enabled;
  }

  @override
  Future<void> saveExtractionEnabled(bool value) async => enabled = value;
}

class _Store implements AnalysisStore {
  _Store(this.work);
  AnalysisWork? work;
  final writes = <String>[];
  final interruptions = <bool>[];
  Completer<void>? savingStarted;
  Completer<void>? savingFinished;

  @override
  Future<AnalysisWork?> claim({Set<AnalysisScope>? automaticScopes}) async {
    final next = work;
    if (next == null ||
        (!next.manual && !(automaticScopes?.contains(next.scope) ?? true))) {
      return null;
    }
    work = null;
    return next;
  }

  @override
  Future<AnalysisInput> input(AnalysisWork work) async =>
      AnalysisInput(const {'userMessage': 'I prefer mornings'}, const []);

  @override
  Future<void> saveMemoryCandidates(AnalysisWork work, String json) async {
    writes.add('candidates');
    savingStarted?.complete();
    await savingFinished?.future;
  }

  @override
  Future<bool> completeReflection(AnalysisWork work, String json) async {
    writes.add('reflection');
    return true;
  }

  @override
  Future<bool> publish(
    AnalysisWork work,
    String content,
    List<Map<String, Object?>> sources,
    int coverage,
  ) async {
    writes.add('publish');
    return true;
  }

  @override
  Future<void> fail(
    AnalysisWork work,
    String message, {
    bool blocked = false,
    bool interrupted = false,
  }) async => interruptions.add(interrupted);

  @override
  Future<void> ensureReflectionJob() async {}
  @override
  Future<void> recover() async {}
  @override
  Future<void> resumeBlocked() async {}
  @override
  Future<void> retry(
    AnalysisScope scope,
    String id, {
    bool closing = false,
    bool manual = true,
    String? operationId,
  }) async {}
}

void main() {
  for (final scope in [AnalysisScope.memory, AnalysisScope.reflection]) {
    late _Store store;
    late _Settings settings;
    late AnalysisService service;
    late Completer<void> modelStarted;
    late Completer<String> modelResult;
    var busy = false;

    setUp(() {
      store = _Store(AnalysisWork(scope, 'source', 1, false));
      settings = _Settings();
      modelStarted = Completer<void>();
      modelResult = Completer<String>();
      busy = false;
      service = AnalysisService(
        store: store,
        memorySettings: settings,
        mainBusy: () => busy,
        model: (prompt, {imageKey, mime, json = false}) {
          modelStarted.complete();
          return modelResult.future;
        },
      );
    });

    tearDown(() async {
      if (!modelResult.isCompleted) modelResult.complete('{}');
      settings.delayedRead?.complete(true);
      await service.dispose();
    });

    test('${scope.name}: delayed result cannot write after shutdown', () async {
      final drain = service.drain();
      await modelStarted.future;
      final closing = service.dispose();
      modelResult.complete('{}');
      await drain;
      await closing;
      expect(store.writes, isEmpty);
      expect(store.interruptions, [true]);
    });

    test(
      '${scope.name}: delayed result rechecks main session priority',
      () async {
        final drain = service.drain();
        await modelStarted.future;
        busy = true;
        modelResult.complete('{}');
        await drain;
        expect(store.writes, isEmpty);
        expect(store.interruptions, [true]);
      },
    );

    test('${scope.name}: delayed result respects extraction toggle', () async {
      final drain = service.drain();
      await modelStarted.future;
      await service.saveMemoryExtractionEnabled(false);
      modelResult.complete('{}');
      await drain;
      expect(store.writes, isEmpty);
      expect(store.interruptions, [true]);
    });

    test(
      '${scope.name}: result reloads persisted extraction setting',
      () async {
        final drain = service.drain();
        await modelStarted.future;
        settings.enabled = false;
        modelResult.complete('{}');
        await drain;
        expect(service.memoryExtractionEnabled, isFalse);
        expect(store.writes, isEmpty);
        expect(store.interruptions, [true]);
      },
    );

    test(
      '${scope.name}: shutdown during settings read discards result',
      () async {
        final drain = service.drain();
        await modelStarted.future;
        settings.readStarted = Completer<void>();
        final pending = settings.delayedRead = Completer<bool>();
        modelResult.complete('{}');
        await settings.readStarted!.future;
        final closing = service.dispose();
        settings.delayedRead = null;
        pending.complete(true);
        await drain;
        await closing;
        expect(store.writes, isEmpty);
        expect(store.interruptions, [true]);
      },
    );

    test('${scope.name}: stale settings read cannot undo toggle', () async {
      final drain = service.drain();
      await modelStarted.future;
      settings.readStarted = Completer<void>();
      final pending = settings.delayedRead = Completer<bool>();
      modelResult.complete('{}');
      await settings.readStarted!.future;
      await service.saveMemoryExtractionEnabled(false);
      settings.delayedRead = null;
      pending.complete(true);
      await drain;
      expect(service.memoryExtractionEnabled, isFalse);
      expect(store.writes, isEmpty);
      expect(store.interruptions, [true]);
    });

    test('${scope.name}: disabled automatic work is not claimed', () async {
      settings.enabled = false;
      await service.drain();
      expect(modelStarted.isCompleted, isFalse);
      expect(store.work, isNotNull);
      expect(store.writes, isEmpty);
    });

    test('${scope.name}: manual job bypasses extraction setting', () async {
      settings.enabled = false;
      store.work = AnalysisWork(scope, 'source', 1, false, 0, true);
      final drain = service.drain();
      await modelStarted.future;
      modelResult.complete('{}');
      await drain;
      expect(
        store.writes,
        scope == AnalysisScope.memory
            ? ['candidates', 'publish']
            : ['reflection'],
      );
      expect(store.interruptions, isEmpty);
    });

    test('${scope.name}: manual job still respects shutdown', () async {
      store.work = AnalysisWork(scope, 'source', 1, false, 0, true);
      final drain = service.drain();
      await modelStarted.future;
      final closing = service.dispose();
      modelResult.complete('{}');
      await drain;
      await closing;
      expect(store.writes, isEmpty);
      expect(store.interruptions, [true]);
    });

    test(
      '${scope.name}: failed settings read preserves disabled value',
      () async {
        final drain = service.drain();
        await modelStarted.future;
        settings.readStarted = Completer<void>();
        final pending = settings.delayedRead = Completer<bool>();
        modelResult.complete('{}');
        await settings.readStarted!.future;
        await service.saveMemoryExtractionEnabled(false);
        settings.delayedRead = null;
        pending.completeError(StateError('settings unavailable'));
        await drain;
        expect(service.memoryExtractionEnabled, isFalse);
        expect(store.writes, isEmpty);
        expect(store.interruptions, [true]);
      },
    );

    if (scope == AnalysisScope.memory) {
      for (final shutdown in [true, false]) {
        test(
          'memory: rechecks before publish after candidate save ($shutdown)',
          () async {
            store.savingStarted = Completer<void>();
            store.savingFinished = Completer<void>();
            final drain = service.drain();
            await modelStarted.future;
            modelResult.complete('{}');
            await store.savingStarted!.future;
            final closing = shutdown ? service.dispose() : null;
            if (!shutdown) await service.saveMemoryExtractionEnabled(false);
            store.savingFinished!.complete();
            await drain;
            await closing;
            expect(store.writes, ['candidates']);
            expect(store.interruptions, [true]);
          },
        );
      }
    }
  }
}
