import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core_io.dart';
import 'package:args/args.dart';

import '../example/demo_tools.dart' show currentTimeTool, authorizeDemoTool;

/// 独立运行入口；这里只注册本机只读时间工具，业务能力由以后宿主提供。
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('config', help: '模型配置 JSON 路径；不传时采用 DeepSeek 默认配置')
    ..addOption('sessions', defaultsTo: '.agent-data', help: '会话日志目录')
    ..addOption('session', help: '打开已有会话编号')
    ..addOption('prompt', help: '运行一次后退出')
    ..addFlag('compact', negatable: false, help: '运行前手动压缩已有会话')
    ..addFlag('help', abbr: 'h', negatable: false, help: '查看用法');
  late ArgResults options;
  try {
    options = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
    return;
  }
  if (options['help'] == true) {
    print(parser.usage);
    return;
  }
  AgentRuntime? runtime;
  AgentSession? session;
  StreamSubscription<AgentEvent>? events;
  StreamSubscription<ProcessSignal>? interrupt;
  final lines = StreamIterator(
    stdin.transform(utf8.decoder).transform(const LineSplitter()),
  );
  var exitRequested = false;
  var streamedText = false;

  Future<void> attach(AgentSession next) async {
    await events?.cancel();
    session = next;
    events = next.events.listen((event) {
      if (event is ModelStreamUpdated &&
          event.purpose == ModelRequestPurpose.conversation &&
          event.update is ModelTextDelta) {
        stdout.write((event.update as ModelTextDelta).text);
        streamedText = true;
      } else if (event is ContextCompacted) {
        print(
          '\n[上下文压缩] ${event.compaction.beforeTokens} → ${event.compaction.afterTokens} 估算 tokens',
        );
      } else if (event is ModelAttemptFailed) {
        print(
          '\n[模型请求] ${event.failure.message}${event.willRetry ? '；即将重试' : ''}',
        );
      } else if (event is ToolExecutionStarted) {
        print('\n[执行工具] ${event.call.name}');
      }
    });
    print(
      '[会话] ${next.id}；模型：${next.modelProfileId}；摘要：${next.summaryProfileId}',
    );
    if (next.needsOutcomeResolution) {
      print('[需要核对] 有工具结果未知，宿主应核对并调用 resolveToolOutcome 后再继续。');
    }
  }

  Future<void> showResult(Future<AgentRunResult> pending) async {
    streamedText = false;
    final result = await pending;
    await Future<void>.delayed(Duration.zero); // 让异步事件先送到终端。
    if (!streamedText && result.answer != null) print(result.answer);
    print(
      '\n[${result.reason.name}] 请求 ${result.modelSteps} 步 / ${result.modelAttempts} 次尝试；'
      '报告用量：输入 ${result.usage.inputTokens}，输出 ${result.usage.outputTokens}',
    );
    if (result.failure != null) print(result.failure);
    if (result.reason != AgentStopReason.completed) exitCode = 1;
  }

  try {
    final configPath = options['config'] as String?;
    final config = configPath == null
        ? AgentConfiguration.deepSeek()
        : await loadAgentConfiguration(File(configPath));
    runtime = AgentRuntime(
      configuration: config,
      store: FileSessionStore(Directory(options['sessions'] as String)),
      credentials: (name) => Platform.environment[name],
      tools: [currentTimeTool()],
      authorize: authorizeDemoTool,
    );
    final existing = options['session'] as String?;
    await attach(
      existing == null
          ? await runtime.createSession(
              systemPrompt:
                  '你是一个可靠的中文助理。查询当前时间必须使用 get_current_time，根据真实结果回答，区分事实与猜测。',
            )
          : await runtime.openSession(existing),
    );
    interrupt = ProcessSignal.sigint.watch().listen((_) {
      if (session!.isRunning) {
        session!.cancel();
      } else {
        exitRequested = true;
        unawaited(lines.cancel());
      }
    });
    if (options['compact'] == true) await session!.compact();
    final prompt = options['prompt'] as String?;
    if (prompt != null) {
      await showResult(session!.send(prompt));
      return;
    }
    print('输入文字对话；/help 查看命令。运行时 Ctrl+C 取消，空闲时 Ctrl+C 退出。');
    while (!exitRequested) {
      stdout.write('\n你 > ');
      if (!await lines.moveNext()) break;
      final input = lines.current.trim();
      if (input.isEmpty) continue;
      try {
        if (input == '/exit') break;
        if (input == '/help') {
          print(
            '/models、/model 编号、/summary-model 编号、/list、/new、/open 会话编号、'
            '/history、/status、/compact、/resume、/export 路径、/import 路径、/fork、/exit',
          );
        } else if (input == '/models') {
          for (final profile in config.profiles) {
            print(
              '${profile.id}：${profile.provider}/${profile.model}，${profile.protocol.name}，窗口预算 ${profile.contextWindowTokens}',
            );
          }
        } else if (input.startsWith('/model ')) {
          await session!.selectModels(conversation: input.substring(7).trim());
          print('当前模型：${session!.modelProfileId}');
        } else if (input.startsWith('/summary-model ')) {
          await session!.selectModels(summary: input.substring(15).trim());
          print('摘要模型：${session!.summaryProfileId}');
        } else if (input == '/list') {
          for (final id in await runtime.listSessionIds()) {
            print(id);
          }
        } else if (input == '/new') {
          final next = await runtime.createSession();
          await session!.close();
          await attach(next);
        } else if (input.startsWith('/open ')) {
          final nextId = input.substring(6).trim();
          if (nextId != session!.id) {
            final next = await runtime.openSession(nextId);
            await session!.close();
            await attach(next);
          }
        } else if (input == '/compact') {
          final result = await session!.compact();
          if (result == null) print('暂无可压缩的旧历史。');
        } else if (input == '/resume') {
          await showResult(session!.resume());
        } else if (input == '/history') {
          for (final message in session!.transcript) {
            print('${message.runtimeType} ${message.id}：${message.text}');
          }
        } else if (input == '/status') {
          print(
            '原始消息 ${session!.transcript.length}，当前上下文 ${session!.contextMessages.length}，'
            '日志 ${session!.records.length}，待核对结果 ${session!.unknownOutcomes.length}',
          );
        } else if (input.startsWith('/export ')) {
          final file = File(input.substring(8).trim());
          await file.writeAsString(
            '${const JsonEncoder.withIndent('  ').convert(session!.export())}\n',
            flush: true,
          );
          print('已导出：${file.absolute.path}');
        } else if (input.startsWith('/import ')) {
          final json = jsonDecode(
            await File(input.substring(8).trim()).readAsString(),
          );
          if (json is! Map<String, Object?>) {
            throw const FormatException('导入文件必须是会话 JSON 对象');
          }
          final next = await runtime.importSession(json);
          await session!.close();
          await attach(next);
        } else if (input == '/fork') {
          final next = await session!.fork();
          await session!.close();
          await attach(next);
        } else if (input.startsWith('/')) {
          print('未知命令，输入 /help 查看可用命令。');
        } else {
          await showResult(session!.send(input));
        }
      } catch (error) {
        stderr.writeln('操作未完成：$error');
      }
    }
  } catch (error) {
    stderr.writeln('运行失败：$error');
    exitCode = 1;
  } finally {
    await interrupt?.cancel();
    await lines.cancel();
    await runtime?.close();
    await events?.cancel();
  }
}
