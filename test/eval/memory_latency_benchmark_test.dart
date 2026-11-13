// 记忆检索与注入构建的规模基准：1k / 5k 条中文记忆，固定 clock。
// 方法：预热 5 次后重复 50 次，按 nearest-rank 取 p50/p95；门槛为
// 5k queryMemory 检索 p95 < 20ms、装配器构建 p95 < 5ms；召回质量用固定 10 条目标验证。
// 运行：MEMORY_BENCH=1 flutter test --no-pub test/eval/memory_latency_benchmark_test.dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/memory/memory_context.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';

final _enabled = Platform.environment['MEMORY_BENCH'] == '1';
const _targets = 10;
const _warmup = 5;
const _samples = 50;
const _keyword = '早上跑步';

void main() {
  late AppDatabase db;
  late DriftMemoryRepository repository;
  late MemoryService memory;
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2030, 1, 1, 8);
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftMemoryRepository(db, clock: () => now);
    memory = MemoryService(repository);
  });

  tearDown(() async => db.close());

  Future<void> seed(int count) async {
    final rows = <MemoryItemsCompanion>[];
    for (var index = 0; index < count; index++) {
      final target = index < _targets;
      rows.add(
        MemoryItemsCompanion.insert(
          id: 'm$index',
          layer: target ? 'identity' : 'semantic',
          content: target
              ? '第$index条：我习惯早上跑步'
              : '第$index条无关记录：周末喜欢整理房间',
          certainty: 'stated',
          createdAt: now.millisecondsSinceEpoch - index * 1000,
          updatedAt: now.millisecondsSinceEpoch - index * 1000,
          sourceKind: 'user',
          importance: Value(target ? 100 : 50),
        ),
      );
    }
    await db.batch((batch) => batch.insertAll(db.memoryItems, rows));
  }

  Future<List<int>> measure(Future<void> Function() action) async {
    for (var index = 0; index < _warmup; index++) {
      await action();
    }
    final samples = <int>[];
    for (var index = 0; index < _samples; index++) {
      final watch = Stopwatch()..start();
      await action();
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
    }
    return samples;
  }

  double percentile(List<int> samples, double ratio) {
    final sorted = [...samples]..sort();
    final index = ((sorted.length * ratio).ceil() - 1).clamp(
      0,
      sorted.length - 1,
    );
    return sorted[index] / 1000;
  }

  Future<void> benchmark(int count) async {
    await seed(count);
    final assembler = MemoryContextAssembler(memory: memory);

    final query = await measure(() async {
      await repository.queryMemory(search: _keyword, limit: 20);
    });
    final page = await measure(() async {
      await repository.queryMemory(limit: 20);
    });
    final inject = await measure(() async {
      await assembler.assemble(topic: _keyword);
    });

    final result = await repository.queryMemory(search: _keyword, limit: 20);
    final contents = [
      for (final item in result['items'] as List)
        (item as Map<String, Object?>)['content'] as String,
    ];
    final recall = contents.where((content) => content.contains(_keyword)).length;
    final assembled = await assembler.assemble(topic: _keyword);
    final injected = assembled.text.contains(_keyword);

    stdout.writeln(
      'BENCH n=$count '
      'query(p50=${percentile(query, 0.50).toStringAsFixed(3)}ms, '
      'p95=${percentile(query, 0.95).toStringAsFixed(3)}ms) '
      'page(p50=${percentile(page, 0.50).toStringAsFixed(3)}ms, '
      'p95=${percentile(page, 0.95).toStringAsFixed(3)}ms) '
      'inject(p50=${percentile(inject, 0.50).toStringAsFixed(3)}ms, '
      'p95=${percentile(inject, 0.95).toStringAsFixed(3)}ms) '
      'recall=$recall/$_targets injected=${injected ? 'yes' : 'no'}',
    );

    expect(recall, _targets, reason: '$count 条规模下目标召回不应退化');
    expect(
      injected,
      isTrue,
      reason: '$count 条规模下目标记忆应仍能进入注入上下文',
    );
    expect(
      percentile(query, 0.95),
      lessThan(20),
      reason: '$count 条规模下 queryMemory 检索 p95 应低于 20ms',
    );
    expect(
      percentile(inject, 0.95),
      lessThan(5),
      reason: '$count 条规模下装配器构建 p95 应低于 5ms',
    );
  }

  test(
    '[基准] 1k 条记忆检索与注入构建',
    () => benchmark(1000),
    skip: _enabled ? false : '设置 MEMORY_BENCH=1 运行规模基准',
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    '[基准] 5k 条记忆检索与注入构建',
    () => benchmark(5000),
    skip: _enabled ? false : '设置 MEMORY_BENCH=1 运行规模基准',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
