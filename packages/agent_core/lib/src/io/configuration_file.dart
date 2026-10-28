import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../models/configuration.dart';

/// 配置只有凭据变量名；Key 由运行进程或宿主自己的凭据服务提供。
Future<AgentConfiguration> loadAgentConfiguration(File file) async {
  try {
    return AgentConfiguration.fromJson(
      readObject(jsonDecode(await file.readAsString())),
    );
  } on FormatException {
    throw const FormatException('模型配置格式错误，请检查 JSON 语法、版本和字段');
  }
}

Future<void> saveAgentConfiguration(
  File file,
  AgentConfiguration configuration,
) async {
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.tmp-${const Uuid().v4()}');
  await temporary.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(configuration.toJson())}\n',
    flush: true,
  );
  await temporary.rename(file.path);
}
