@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core_io.dart';
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
  late Directory directory;
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
    await session.send('背景：${'用户明确约束' * 120}');
    await session.send('按这些约束继续');
    final ids = session.contextMessages.map((message) => message.id).toList();
    expect(
      session.records.any((record) => record.type == 'context_compacted'),
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
    expect(recovered.records.last.type, 'storage_tail_recovered');
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
    final child = await Process.run(Platform.resolvedExecutable, [
      'run',
      'test/fixtures/crash_worker.dart',
      directory.path,
      'try-lock',
    ], workingDirectory: Directory.current.path);
    expect(child.exitCode, 75, reason: '${child.stdout}\n${child.stderr}');
    await runtime.close();
    final reopened = await store.open('locked');
    await reopened.close();
  });

  test('真实子进程在工具产生副作用后退出，恢复不会重复执行', () async {
    final child = await Process.run(Platform.resolvedExecutable, [
      'run',
      'test/fixtures/crash_worker.dart',
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
      everyElement(containsPair('credentialEnvironment', 'DEEPSEEK_API_KEY')),
    );
  });
}
