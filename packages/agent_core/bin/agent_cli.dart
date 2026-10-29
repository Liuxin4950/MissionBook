import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core_io.dart';

import 'terminal_view.dart';

/// 接住用户输入，调用同一个 AgentSession；终端不是另一套 Agent 循环。
final class AgentCli {
  AgentCli({
    required this.runtime,
    required this.session,
    required this.view,
    this.demo = false,
  });
  final AgentRuntime runtime;
  AgentSession session;
  final TerminalView view;
  final bool demo;
  StreamSubscription<AgentEvent>? _events;
  StreamSubscription<ProcessSignal>? _interrupt;
  StreamIterator<String>? _lines;
  CancellationToken? _preparing;
  bool _exitRequested = false;

  Future<void> run({
    String? prompt,
    List<String> images = const [],
    bool compact = false,
  }) async {
    _subscribe();
    _interrupt = ProcessSignal.sigint.watch().listen((_) {
      if (session.isRunning || _preparing != null) {
        _preparing?.cancel();
        session.cancel();
      } else {
        _exitRequested = true;
        unawaited(_lines?.cancel());
      }
    });
    try {
      if (compact) await _compact();
      if (prompt != null || images.isNotEmpty) {
        await _send(prompt ?? '请描述图片并识别其中的文字。', images);
        return;
      }
      view.welcome(session, demo: demo);
      _lines = StreamIterator(
        stdin.transform(utf8.decoder).transform(const LineSplitter()),
      );
      while (!_exitRequested) {
        view.prompt();
        if (!await _lines!.moveNext()) break;
        final input = _lines!.current.trim();
        if (input.isEmpty) continue;
        try {
          await _handle(input);
        } on AgentCancelled {
          view.note('已取消');
        } catch (error) {
          view.error(_friendlyError(error));
        }
      }
      view.note('会话已保存，再见。');
    } finally {
      await _events?.cancel();
      await _interrupt?.cancel();
      await _lines?.cancel();
      view.close();
    }
  }

  void _subscribe() {
    _events = session.events.listen(view.observe);
  }

  Future<void> _switch(AgentSession next) async {
    await _events?.cancel();
    await session.close();
    session = next;
    _subscribe();
    view.success('${session.title}  ·  ${session.id.substring(0, 8)}');
  }

  Future<void> _handle(String input) async {
    if (!input.startsWith('/')) {
      await _send(input);
      return;
    }
    final (command, argument) = _firstArgument(input);
    switch (command) {
      case '/exit':
        _exitRequested = true;
      case '/help':
        view.help();
      case '/models':
        for (final profile in runtime.configuration.profiles) {
          view.line(
            '  ${profile.id == session.modelProfileId ? '●' : '○'} ${profile.id}  ${profile.provider} / ${profile.model}',
          );
          view.note(
            '  ${profile.protocol.name}  ·  上下文 ${tokens(profile.contextWindowTokens)}  ·  输出 ${tokens(profile.maxOutputTokens)}',
          );
        }
      case '/model':
        await session.selectModels(conversation: _required(argument));
        view.success(
          '已切换：${session.modelProfile.model}（${session.modelProfileId}）',
        );
      case '/summary-model':
        await session.selectModels(summary: _required(argument));
        view.success('摘要配置：${session.summaryProfileId}');
      case '/thinking':
        final effort = ReasoningEffort.values.firstWhere(
          (value) => value.name == argument,
          orElse: () => throw ArgumentError('使用 /thinking off、low、high 或 max'),
        );
        await session.configureGeneration(thinking: effort);
        view.success(
          '思考${thinking(effort)}；输出预算 ${tokens(session.outputTokens)}，可用 /output 调整',
        );
      case '/output':
        final count = int.tryParse(argument);
        if (count == null) throw ArgumentError('使用 /output 8192 这样的整数');
        await session.configureGeneration(maxOutputTokens: count);
        view.success('输出预算：${tokens(count)}');
      case '/format':
        if (argument != 'text' && argument != 'json') {
          throw ArgumentError('使用 /format text 或 /format json');
        }
        await session.configureGeneration(jsonOutput: argument == 'json');
        view.success('回答格式：${argument == 'json' ? 'JSON 对象' : '普通文字'}');
      case '/new':
        await _switch(
          await runtime.createSession(systemPrompt: session.systemPrompt),
        );
      case '/list':
        final ids = await runtime.listSessionIds();
        if (ids.isEmpty) view.note('暂无会话');
        for (final id in ids) {
          view.line('  ${id == session.id ? '●' : '○'} $id');
        }
      case '/open':
        final id = await _resolveId(_required(argument));
        if (id != session.id) await _switch(await runtime.openSession(id));
      case '/rename':
        await session.rename(_required(argument));
        view.success('会话名称：${session.title}');
      case '/fork':
        await _switch(await session.fork());
      case '/compact':
        await _compact();
      case '/resume':
        await _show(session.resume());
      case '/history':
        for (final message in session.transcript) {
          final role = switch (message) {
            UserMessage() => '你',
            AssistantMessage() => '助理',
            ToolResultMessage() => '工具 · ${message.toolName}',
            ContextMessage() => '背景 · ${message.source}',
            ContextSummaryMessage() => '较早对话摘要',
          };
          view.line('\n$role');
          view.line(message.text);
          for (final image in message.content.whereType<ImageBlock>()) {
            view.note('[图片 ${image.label ?? image.fileId ?? '链接'}]');
          }
        }
      case '/status':
        final model = session.modelProfile;
        view.line('');
        for (final row in <String>[
          '会话  ${session.title}',
          '编号  ${session.id}',
          '模型  ${model.provider} / ${model.model}',
          '接口  ${model.protocol.name}',
          '上下文窗口  ${tokens(model.contextWindowTokens)}',
          '输出预算  ${tokens(session.outputTokens)} / 模型上限 ${model.outputTokenLimit == null ? '未声明' : tokens(model.outputTokenLimit!)}',
          '思考  ${thinking(session.reasoningEffort)}',
          '摘要配置  ${session.summaryProfileId}',
          '原始消息  ${session.transcript.length} / 模型上下文 ${session.contextMessages.length}',
          '日志记录  ${session.recordCount} / 待核对 ${session.unknownOutcomes.length}',
        ]) {
          view.note(row);
        }
      case '/image':
        final (source, question) = _firstArgument(_required(argument));
        await _send(question.isEmpty ? '请描述图片并识别其中的文字。' : question, [source]);
      case '/export':
        final path = _unquote(_required(argument));
        await File(path).writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(await session.export())}\n',
          flush: true,
        );
        view.success('已导出：$path');
      case '/import':
        final data = jsonDecode(
          await File(_unquote(_required(argument))).readAsString(),
        );
        if (data is! Map<String, Object?>) {
          throw const FormatException('需要会话 JSON 对象');
        }
        await _switch(await runtime.importSession(data));
      case '/delete':
        final id = await _resolveId(_required(argument));
        if (id == session.id) throw ArgumentError('请先用 /new 或 /open 切换，再删除旧会话');
        await runtime.store.delete(id);
        view.success('本地会话已删除');
      default:
        view.note('未知命令。输入 /help 查看用法。');
    }
  }

  Future<void> _compact() async {
    view.startWaiting('整理上下文');
    try {
      final result = await session.compact();
      if (result == null) view.note('当前内容已经足够短，无需整理。');
    } finally {
      view.stopWaiting();
    }
  }

  Future<void> _send(String text, [List<String> sources = const []]) async {
    if (!session.modelProfile.supportsImages && sources.isNotEmpty) {
      throw ArgumentError('当前模型不支持图片，请先 /model 切换');
    }
    final token = CancellationToken();
    _preparing = token;
    final blocks = <ContentBlock>[TextBlock(text: text)];
    try {
      for (final source in sources) {
        blocks.add(await _loadImage(source, token));
      }
      token.throwIfCancelled();
      if (session.transcript.isEmpty && session.title == '新会话') {
        await session.rename(
          text.length > 24 ? '${text.substring(0, 24)}…' : text,
        );
      }
      await _show(
        session.sendMessage(UserMessage.withContent(content: blocks)),
      );
    } finally {
      _preparing = null;
      view.stopWaiting();
    }
  }

  Future<ImageBlock> _loadImage(String source, CancellationToken token) async {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return ImageBlock(url: source);
    }
    final file = File(source);
    if (!await file.exists()) throw ArgumentError('图片不存在：$source');
    if (await file.length() > 64 * 1024 * 1024) {
      throw ArgumentError('图片不能超过 64 MiB');
    }
    final image = ImageInput.fromBytes(
      await file.readAsBytes(),
      name: file.uri.pathSegments.last,
    );
    token.throwIfCancelled();
    final profile = session.modelProfile;
    if (!demo &&
        profile.provider == 'deepseek' &&
        profile.endpoint.host == 'api.deepseek.com') {
      view.startWaiting('上传图片 ${image.name}');
      final files = DeepSeekFilesClient(
        credentials: (key) => Platform.environment[key],
        credentialKey: profile.credentialKey,
      );
      try {
        final uploaded = await files.upload(image, cancellation: token);
        view.note('图片已添加：${image.name}  ·  ${image.width} × ${image.height}');
        return uploaded.block;
      } finally {
        files.close();
      }
    }
    view.note('图片已添加：${image.name}  ·  ${image.width} × ${image.height}');
    return image.inline();
  }

  Future<void> _show(Future<AgentRunResult> pending) async {
    final watch = Stopwatch()..start();
    final result = await pending;
    await Future<void>.delayed(Duration.zero);
    view.result(result, watch.elapsed);
    if (result.reason != AgentStopReason.completed) exitCode = 1;
  }

  Future<String> _resolveId(String prefix) async {
    final matches = (await runtime.listSessionIds())
        .where((id) => id.startsWith(prefix))
        .toList();
    if (matches.length != 1) {
      throw ArgumentError(matches.isEmpty ? '没有找到该会话' : '编号前缀对应多个会话，请多输入几位');
    }
    return matches.single;
  }
}

(String, String) _firstArgument(String input) {
  final text = input.trim();
  if (text.isEmpty) return ('', '');
  if (text.startsWith('"') || text.startsWith("'")) {
    final end = text.indexOf(text[0], 1);
    if (end < 0) throw ArgumentError('路径引号没有闭合');
    return (text.substring(1, end), text.substring(end + 1).trim());
  }
  final boundary = text.indexOf(RegExp(r'\s'));
  if (boundary < 0) return (text, '');
  return (text.substring(0, boundary), text.substring(boundary + 1).trim());
}

String _required(String text) {
  if (text.isEmpty) throw ArgumentError('命令缺少参数，输入 /help 查看用法');
  return text;
}

String _unquote(String text) {
  if (!text.startsWith('"') && !text.startsWith("'")) return text;
  final (path, extra) = _firstArgument(text);
  if (extra.isNotEmpty) throw ArgumentError('路径后有多余参数');
  return path;
}

String _friendlyError(Object error) {
  if (error is ModelException) return error.message;
  if (error is ArgumentError) return error.message?.toString() ?? '输入参数无效';
  if (error is FormatException) return error.message;
  if (error is StateError) return error.message;
  if (error is FileSystemException) return '文件操作失败：${error.message}';
  return '操作未完成：$error';
}
