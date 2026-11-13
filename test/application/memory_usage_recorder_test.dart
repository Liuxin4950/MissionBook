import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/memory/memory_usage_recorder.dart';
import 'package:mission_book/domain/repositories/memory_repository.dart';

class _UnusedRepository implements MemoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('测试不应访问仓储');
}

class _ControlledMemory extends MemoryService {
  _ControlledMemory() : super(_UnusedRepository());

  final calls = <({List<String> ids, bool injected})>[];
  Future<void> Function()? write;

  @override
  Future<void> recordUsage({
    required List<String> ids,
    required bool injected,
  }) {
    calls.add((ids: List.of(ids), injected: injected));
    return write?.call() ?? Future<void>.value();
  }
}

void main() {
  test('默认30秒节流：边界前不重计，边界时可重计且新ID不被阻塞', () async {
    var now = DateTime.utc(2026, 11, 13);
    final memory = _ControlledMemory();
    final recorder = MemoryUsageRecorder(memory, clock: () => now);
    recorder.record(['a', 'a'], injected: false);
    await recorder.drain();
    now = now.add(const Duration(seconds: 29, milliseconds: 999));
    recorder.record(['a', 'b'], injected: false);
    await recorder.drain();
    expect(memory.calls.map((call) => [call.ids, call.injected]), [
      [
        ['a'],
        false,
      ],
      [
        ['b'],
        false,
      ],
    ]);
    now = now.add(const Duration(milliseconds: 1));
    recorder.record(['a', 'b'], injected: false);
    await recorder.drain();
    expect(memory.calls.last.ids, ['a']);
    expect(memory.calls.last.injected, false);
    expect(memory.calls, hasLength(3));
  });

  test('recall与inject独立去重，空列表不写入', () async {
    final memory = _ControlledMemory();
    final recorder = MemoryUsageRecorder(memory);
    recorder.record([], injected: false);
    recorder.record(['a', 'a'], injected: false);
    recorder.record(['a', 'a'], injected: true);
    recorder.record(['a'], injected: false);
    recorder.record(['a'], injected: true);
    await recorder.drain();
    expect(memory.calls.map((call) => [call.ids, call.injected]), [
      [
        ['a'],
        false,
      ],
      [
        ['a'],
        true,
      ],
    ]);
  });

  test('超过500个近期键仍保持30秒去重', () async {
    final memory = _ControlledMemory();
    final recorder = MemoryUsageRecorder(memory);
    final ids = List.generate(501, (index) => 'id-$index');
    recorder.record(ids, injected: false);
    recorder.record(ids, injected: false);
    await recorder.drain();
    expect(memory.calls, hasLength(1));
    expect(memory.calls.single.ids, ids);
  });

  test('record延后调用且不等待写入，drain等待所有在途统计', () async {
    final memory = _ControlledMemory();
    final first = Completer<void>();
    final second = Completer<void>();
    final started = Completer<void>();
    memory.write = () {
      if (memory.calls.length == 1) return first.future;
      started.complete();
      return second.future;
    };
    final recorder = MemoryUsageRecorder(memory);
    recorder.record(['a'], injected: false);
    recorder.record(['a'], injected: true);
    expect(memory.calls, isEmpty);
    var drained = false;
    final draining = recorder.drain().then((_) => drained = true);
    await started.future;
    expect(drained, false);
    first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(drained, false);
    second.complete();
    await draining;
    expect(drained, true);
    await recorder.drain();
  });

  for (final synchronous in [true, false]) {
    test('${synchronous ? '同步' : '异步'}异常降级，不泄漏错误正文且后续仍能统计', () async {
      final logs = <String?>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      addTearDown(() => debugPrint = previous);
      final memory = _ControlledMemory();
      memory.write = () {
        final error = StateError('sensitive-user-content');
        if (synchronous) throw error;
        return Future<void>.error(error);
      };
      final recorder = MemoryUsageRecorder(memory);
      expect(() => recorder.record(['a'], injected: false), returnsNormally);
      await recorder.drain();
      expect(logs, hasLength(1));
      expect(logs.single, isNot(contains('sensitive-user-content')));
      memory.write = null;
      recorder.record(['b'], injected: false);
      await recorder.drain();
      expect(memory.calls, hasLength(2));
      expect(memory.calls.last.ids, ['b']);
    });
  }
}
