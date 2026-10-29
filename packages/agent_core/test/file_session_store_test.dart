@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:agent_core/agent_core_io.dart';
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
  late Directory directory;
  late String worker;
  setUpAll(() async {
    // 编译独立测试进程，避免 Windows 在父进程已加载 DLL 时再次覆盖同一个构建产物。
    final output = Directory('.dart_tool/test-workers');
    await output.create(recursive: true);
    worker =
        '${output.absolute.path}/bundle/bin/crash_worker${Platform.isWindows ? '.exe' : ''}';
    final compiled = await Process.run(Platform.resolvedExecutable, [
      'build',
      'cli',
      '--target=test/fixtures/crash_worker.dart',
      '--output=${output.path}',
    ]);
    expect(
      compiled.exitCode,
      0,
      reason: '${compiled.stdout}\n${compiled.stderr}',
    );
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'agent-core-storage-test-',
    );
  });
  tearDown(() async {
    final target = directory.absolute.path;
    final tempRoot = Directory.systemTemp.absolute.path;
    if (!target.startsWith('$tempRoot${Platform.pathSeparator}') ||
        !directory.uri.pathSegments.any(
          (part) => part.startsWith('agent-core-storage-test-'),
        )) {
      throw StateError('拒绝清理测试临时目录之外的位置');
    }
    await directory.delete(recursive: true);
  });

  test('大记录跨读取块后仍能分页，关闭开始后不再接受新写入', () async {
    final store = FileSessionStore(directory);
    final handle = await store.create('pages');
    for (var index = 0; index < 5; index++) {
      await handle.append('diagnostic', {'value': '$index${'x' * 70000}'});
    }
    final closing = handle.close();
    await expectLater(
      handle.append('late', {}),
      throwsA(isA<AgentPersistenceException>()),
    );
    await closing;
    final reader = await store.open('pages', readOnly: true);
    final page = await reader.readRecords(start: 2, limit: 2);
    expect(page.map((record) => record.sequence), [2, 3]);
    expect((page.first.data['value'] as String).length, 70001);
    await reader.close();
  });

  test('真实文件关闭重开，原文、配置、摘要和校验均恢复', () async {
    final config = testConfiguration(
      window: 3000,
      context: ContextPolicy(
        headroomTokens: 64,
        summaryMaxTokens: 128,
        keepRecentMessages: 1,
      ),
    );
    final runtime = testRuntime(
      store: FileSessionStore(directory),
      configuration: config,
    );
    final session = await runtime.createSession(id: 'saved');
    await session.send('背景：${'用户明确约束' * 480}');
    await session.send('按这些约束继续');
    final ids = session.contextMessages.map((message) => message.id).toList();
    expect(
      (await session.readRecords()).any(
        (record) => record.type == 'context_compacted',
      ),
      isTrue,
    );
    await runtime.close();
    final nextRuntime = testRuntime(
      store: FileSessionStore(directory),
      configuration: config,
    );
    final reopened = await nextRuntime.openSession('saved');
    expect(reopened.transcript, hasLength(4));
    expect(reopened.contextMessages.map((message) => message.id), ids);
    expect((await reopened.send('下一句')).reason, AgentStopReason.completed);
    await nextRuntime.close();
  });

  test('未提交尾片段隔离保存后恢复，完整坏行拒绝修改', () async {
    final runtime = testRuntime(store: FileSessionStore(directory));
    final session = await runtime.createSession(id: 'tail');
    await session.send('已保存');
    await runtime.close();
    final file = File('${directory.path}/tail.jsonl');
    await file.writeAsString('{"record":', mode: FileMode.append, flush: true);
    final nextRuntime = testRuntime(store: FileSessionStore(directory));
    final recovered = await nextRuntime.openSession('tail');
    expect(recovered.transcript, hasLength(2));
    expect((await recovered.readRecords()).last.type, 'storage_tail_recovered');
    expect(
      (await directory
          .list()
          .where((file) => file.path.contains('.torn-'))
          .toList()),
      hasLength(1),
    );
    await nextRuntime.close();
    final valid = await file.readAsString();
    final corrupt = valid.replaceFirst(
      RegExp(r'"sha256":"[a-f0-9]+"'),
      '"sha256":"broken"',
    );
    await file.writeAsString(corrupt, flush: true);
    final brokenRuntime = testRuntime(store: FileSessionStore(directory));
    await expectLater(brokenRuntime.openSession('tail'), throwsFormatException);
    expect(await file.readAsString(), corrupt);
    await brokenRuntime.close();
  });

  test('未来版本拒绝打开，文件与未完成尾部均不改动', () async {
    final runtime = testRuntime(store: FileSessionStore(directory));
    await runtime.createSession(id: 'future');
    await runtime.close();
    final file = File('${directory.path}/future.jsonl');
    final text = (await file.readAsString()).replaceFirst(
      '"version":1',
      '"version":99',
    );
    await file.writeAsString('$text{"unfinished":', flush: true);
    final next = testRuntime(store: FileSessionStore(directory));
    await expectLater(next.openSession('future'), throwsFormatException);
    expect(await file.readAsString(), '$text{"unfinished":');
    await next.close();
  });

  test('同一会话在同进程和不同进程都只能有一个写入者', () async {
    final store = FileSessionStore(directory);
    final runtime = testRuntime(store: store);
    await runtime.createSession(id: 'locked');
    await expectLater(
      FileSessionStore(directory).open('locked'),
      throwsStateError,
    );
    final child = await Process.run(worker, [
      directory.path,
      'try-lock',
    ], workingDirectory: Directory.current.path);
    expect(child.exitCode, 75, reason: '${child.stdout}\n${child.stderr}');
    await runtime.close();
    final reopened = await store.open('locked');
    await reopened.close();
  });

  test('真实子进程在工具产生副作用后退出，恢复不会重复执行', () async {
    final child = await Process.run(worker, [
      directory.path,
    ], workingDirectory: Directory.current.path);
    expect(child.exitCode, 73, reason: '${child.stdout}\n${child.stderr}');
    final effect = File('${directory.path}/effect.txt');
    expect(await effect.readAsString(), 'one committed effect');
    var reexecuted = false;
    final runtime = testRuntime(
      store: FileSessionStore(directory),
      tools: [
        readTool((input, context) {
          reexecuted = true;
          return const ToolOutput.success('不应执行');
        }),
      ],
    );
    final recovered = await runtime.openSession('crashed');
    expect(recovered.needsOutcomeResolution, isTrue);
    expect(recovered.unknownOutcomes.keys, ['crash-call']);
    await expectLater(recovered.resume(), throwsStateError);
    await recovered.resolveToolOutcome(
      'crash-call',
      ToolOutput.success(await effect.readAsString()),
      source: '实际读取副作用文件',
    );
    expect((await recovered.resume()).reason, AgentStopReason.completed);
    expect(reexecuted, isFalse);
    expect(await effect.readAsString(), 'one committed effect');
    await runtime.close();
  });

  test('配置 JSON 可保存、再次保存和读取，只保存凭据变量名', () async {
    final file = File('${directory.path}/agent.json');
    final config = AgentConfiguration.deepSeek();
    await saveAgentConfiguration(file, config);
    await saveAgentConfiguration(file, config);
    expect((await loadAgentConfiguration(file)).toJson(), config.toJson());
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(
      json['profiles'],
      everyElement(containsPair('credentialKey', 'DEEPSEEK_API_KEY')),
    );
  });

  test('跨 isolate 的写者也被拒绝，失败的开锁不会释放原写者', () async {
    final store = FileSessionStore(directory);
    final handle = await store.create('locked');
    try {
      final path = directory.path;
      final rejected = await Isolate.run(() async {
        try {
          final second = await FileSessionStore(Directory(path)).open('locked');
          await second.close();
          return false;
        } on StateError {
          return true;
        }
      });
      expect(rejected, true);
      final child = await Process.run(worker, [path, 'try-lock']);
      expect(child.exitCode, 75, reason: '${child.stderr}');
    } finally {
      await handle.close();
    }
  });

  test('空文件可重新创建；只读打开和分页不会取得写权限或修改日志', () async {
    final store = FileSessionStore(directory);
    await File('${directory.path}/empty.jsonl').create();
    final writer = await store.create('empty');
    for (var i = 0; i < 20; i++) {
      await writer.append('diagnostic', {'number': i});
    }
    final reader = await store.open('empty', readOnly: true);
    expect(
      (await reader.readRecords(
        start: 7,
        limit: 3,
      )).map((record) => record.sequence),
      [7, 8, 9],
    );
    expect(() => reader.append('invalid', {}), throwsStateError);
    await expectLater(store.delete('empty'), throwsStateError);
    await reader.close();
    await writer.close();
    await store.delete('empty');
    expect(await store.listSessionIds(), isEmpty);
  });

  test('存储达到明确体积上限时拒绝继续增长，不截断已保存内容', () async {
    final store = FileSessionStore(
      directory,
      maxJournalBytes: 1024,
      maxRecordBytes: 512,
    );
    final handle = await store.create('bounded');
    await handle.append('diagnostic', {'value': 'x' * 100});
    final before = await File('${directory.path}/bounded.jsonl').readAsBytes();
    await expectLater(
      handle.append('too-large', {'value': 'x' * 900}),
      throwsA(isA<AgentPersistenceException>()),
    );
    expect(await File('${directory.path}/bounded.jsonl').readAsBytes(), before);
    await handle.close();
  });
}
