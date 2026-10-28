/// 原生文件能力独立导出，浏览器使用 agent_core.dart 不会引入 dart:io。
library;

export 'agent_core.dart';
export 'src/io/file_session_store.dart';
export 'src/io/configuration_file.dart';
