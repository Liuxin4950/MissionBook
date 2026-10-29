import 'dart:io';

import 'package:agent_core/agent_core_io.dart';
import 'package:args/args.dart';

import '../example/demo_tools.dart' show currentTimeTool, authorizeDemoTool;
import 'agent_cli.dart';
import 'demo_model.dart';
import 'terminal_view.dart';

/// 启动入口：读取参数 → 组装基座 → 打开会话 → 交给终端控制器。
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('config', help: '模型配置 JSON；不传时使用 DeepSeek Flash')
    ..addOption('sessions', defaultsTo: '.agent-data', help: '本地会话目录')
    ..addOption('session', help: '打开已有会话编号')
    ..addOption('prompt', help: '运行一次后退出')
    ..addMultiOption('image', help: '图片路径或链接；可以重复指定')
    ..addOption(
      'thinking',
      allowed: ['off', 'low', 'high', 'max'],
      help: '本次会话的思考强度',
    )
    ..addOption('output', help: '本次会话的输出 token 预算')
    ..addFlag('compact', negatable: false, help: '先整理已有会话上下文')
    ..addFlag('demo', negatable: false, help: '离线体验交互，不请求模型服务')
    ..addFlag('color', defaultsTo: true, help: '终端颜色；重定向时自动关闭')
    ..addFlag('help', abbr: 'h', negatable: false, help: '查看启动参数');

  late ArgResults options;
  try {
    options = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
    return;
  }
  if (options['help'] == true) {
    stdout.writeln(parser.usage);
    return;
  }

  final view = TerminalView(color: options['color'] as bool);
  AgentRuntime? runtime;
  try {
    // 配置只保存凭据标识；当前 CLI 从环境变量解析，App 可换成设备安全存储。
    final configPath = options['config'] as String?;
    final configuration = configPath == null
        ? AgentConfiguration.deepSeek()
        : await loadAgentConfiguration(File(configPath));
    final demo = options['demo'] as bool;
    runtime = AgentRuntime(
      configuration: configuration,
      store: FileSessionStore(Directory(options['sessions'] as String)),
      credentials: (key) => Platform.environment[key],
      tools: [currentTimeTool()],
      authorize: authorizeDemoTool,
      modelOverrides: demo
          ? {
              for (final profile in configuration.profiles)
                profile.id: DemoModel(),
            }
          : const {},
    );
    final sessionId = options['session'] as String?;
    final session = sessionId == null
        ? await runtime.createSession(
            systemPrompt:
                '你是 MissionBook 的可靠中文助理，回答清楚、简洁。查询当前时间必须使用工具。'
                '区分用户陈述、工具事实与推测；识别图片时说明看不清的部分。',
          )
        : await runtime.openSession(sessionId);
    final thinking = options['thinking'] as String?;
    final outputText = options['output'] as String?;
    if (thinking != null || outputText != null) {
      final output = outputText == null ? null : int.tryParse(outputText);
      if (outputText != null && output == null) {
        throw ArgumentError('输出预算需要为整数');
      }
      await session.configureGeneration(
        maxOutputTokens: output,
        thinking: thinking == null
            ? null
            : ReasoningEffort.values.byName(thinking),
      );
    }
    await AgentCli(
      runtime: runtime,
      session: session,
      view: view,
      demo: demo,
    ).run(
      prompt: options['prompt'] as String?,
      images: options['image'] as List<String>,
      compact: options['compact'] as bool,
    );
  } catch (error) {
    view.error(error is ModelException ? error.message : error.toString());
    exitCode = 1;
  } finally {
    view.close();
    await runtime?.close();
  }
}
