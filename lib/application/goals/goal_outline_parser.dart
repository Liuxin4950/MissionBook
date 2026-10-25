import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities/goal_outline_import.dart';

/// 严格读取 v1 JSON 协议，所有错误都指向输入位置，确认前不写业务数据。
abstract final class GoalOutlineParser {
  static const maxBytes = 2 * 1024 * 1024;
  static const maxNodes = 500;
  static const maxDepth = 12;

  static GoalOutlineImport parseText(String text) =>
      parseBytes(Uint8List.fromList(utf8.encode(text)));

  static GoalOutlineImport parseBytes(Uint8List bytes) {
    if (bytes.length > maxBytes) throw const FormatException('文件超过 2 MiB 限制');
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } on FormatException catch (error) {
      throw FormatException('JSON 格式无效：${error.message}');
    }
    final root = _object(decoded, 'Root');
    _fields(
      root,
      'Root',
      {'schema', 'version', 'goal', 'nodes'},
      {'schema', 'version', 'goal', 'nodes'},
    );
    if (root['schema'] != 'mission-book.goal-outline') {
      throw const FormatException('Root.schema 必须是 mission-book.goal-outline');
    }
    if (root['version'] is! int || root['version'] != 1) {
      throw const FormatException('Root.version 必须是整数 1');
    }
    final goal = _object(root['goal'], 'goal');
    _fields(goal, 'goal', {'title'}, {'title', 'description', 'why'});
    final title = _string(goal['title'], 'goal.title', required: true)!;
    final description = _optional(goal, 'description', 'goal.description');
    final why = _optional(goal, 'why', 'goal.why');
    final nodes = root['nodes'];
    if (nodes is! List) throw const FormatException('nodes 必须是数组');
    final keys = <String>{};
    var count = 0;
    GoalImportNode readNode(Object? raw, String path, int depth) {
      if (depth > maxDepth) throw FormatException('$path 超过 12 层限制');
      if (++count > maxNodes) throw FormatException('$path 超过 500 个节点限制');
      final value = _object(raw, path);
      _fields(
        value,
        path,
        {'key', 'title'},
        {'key', 'title', 'description', 'children'},
      );
      final key = _string(value['key'], '$path.key', required: true)!;
      if (!keys.add(key)) throw FormatException('$path.key 重复：$key');
      final title = _string(value['title'], '$path.title', required: true)!;
      final description = _optional(value, 'description', '$path.description');
      final rawChildren = value['children'] ?? const <Object?>[];
      if (rawChildren is! List ||
          (value.containsKey('children') && value['children'] == null)) {
        throw FormatException('$path.children 必须是数组');
      }
      return GoalImportNode(
        key: key,
        title: title,
        description: description,
        children: [
          for (var index = 0; index < rawChildren.length; index++)
            readNode(rawChildren[index], '$path.children[$index]', depth + 1),
        ],
      );
    }

    return GoalOutlineImport(
      title: title,
      description: description,
      why: why,
      nodes: [
        for (var index = 0; index < nodes.length; index++)
          readNode(nodes[index], 'nodes[$index]', 1),
      ],
      nodeCount: count,
    );
  }

  static Map<String, dynamic> _object(Object? value, String path) {
    if (value is! Map<String, dynamic>) throw FormatException('$path 必须是对象');
    return value;
  }

  static void _fields(
    Map<String, dynamic> value,
    String path,
    Set<String> required,
    Set<String> allowed,
  ) {
    for (final key in required) {
      if (!value.containsKey(key)) throw FormatException('$path.$key 缺失');
    }
    for (final key in value.keys) {
      if (!allowed.contains(key)) throw FormatException('$path.$key 不允许出现');
    }
  }

  static String? _optional(
    Map<String, dynamic> object,
    String key,
    String path,
  ) => object.containsKey(key) ? _string(object[key], path) : null;

  static String? _string(Object? value, String path, {bool required = false}) {
    if (value is! String) throw FormatException('$path 必须是字符串');
    final clean = value.trim();
    if (required && clean.isEmpty) throw FormatException('$path 不能为空');
    return clean.isEmpty ? null : clean;
  }
}
