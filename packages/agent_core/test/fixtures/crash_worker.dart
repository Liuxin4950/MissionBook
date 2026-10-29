import 'dart:io';

import 'package:agent_core/agent_core_io.dart';

import '../support/foundation_fixtures.dart';

/// 独立进程故意在工具产生副作用后退出，用于验证真正的进程中断恢复。
Future<void> main(List<String> arguments) async {
  final store = FileSessionStore(Directory(arguments[0]));
  if (arguments.length > 1 && arguments[1] == 'try-lock') {
    try {
      final handle = await store.open('locked');
      await handle.close();
      exitCode = 0;
    } on StateError catch (error) {
      if (!error.message.contains('会话已有写入者')) rethrow;
      exitCode = 75;
    }
    return;
  }
  final runtime = testRuntime(
    store: store,
    main: (request, token) => toolReply('crash-call'),
    tools: [
      readTool((input, context) async {
        await File(
          '${arguments[0]}/effect.txt',
        ).writeAsString('one committed effect', flush: true);
        exit(73); // 不运行 finally，不发布工具结果，操作已经真实发生。
      }),
    ],
  );
  final session = await runtime.createSession(id: 'crashed');
  await session.send('执行一次');
}
