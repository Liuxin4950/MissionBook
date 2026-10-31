import 'dart:convert';

import '../../domain/entities/goal_outline_import.dart';

/// 把一份有界的 AI 目标大纲转换为既有的原子导入请求。
class AssistantGoalOutline {
  static const maxNodes = 20;
  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'description': '新目标名称'},
      'description': {'type': 'string', 'description': '目标说明，可省略'},
      'why': {'type': 'string', 'description': '目标原因，可省略'},
      'nodes': {
        'type': 'array',
        'minItems': 1,
        'maxItems': maxNodes,
        'description': '父节点先于子节点，最多4层；只创建大纲，不创建任务或推断掌握',
        'items': {
          'type': 'object',
          'properties': {
            'key': {'type': 'string', 'description': '本份大纲内唯一编号'},
            'parentKey': {'type': 'string', 'description': '父节点key，顶层省略'},
            'title': {'type': 'string', 'description': '节点名称'},
            'description': {'type': 'string', 'description': '学习内容或验收方向'},
          },
          'required': ['key', 'title'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['title', 'nodes'],
    'additionalProperties': false,
  };

  static List<Map<String, Object?>> rows(Map<String, Object?> input) => [
    for (final node in input['nodes'] as List)
      Map<String, Object?>.from(node as Map<String, dynamic>),
  ];

  static String? validate(Map<String, Object?> input) {
    if (jsonEncode(input).length > 24000) return '整份大纲文字过长，请缩小范围';
    final title = input['title'];
    if (title is! String || title.trim().isEmpty || title.length > 120) {
      return '目标名称需为1–120字';
    }
    for (final field in ['description', 'why']) {
      if (input[field] != null &&
          (input[field] is! String || (input[field] as String).length > 2000)) {
        return '目标说明和原因各最多2000字';
      }
    }
    final nodes = input['nodes'];
    if (nodes is! List || nodes.isEmpty || nodes.length > maxNodes) {
      return '大纲应包含1–20个节点';
    }
    final depths = <String, int>{};
    for (final node in nodes) {
      if (node is! Map) return '大纲节点格式无效';
      final key = node['key'];
      final parent = node['parentKey'];
      if (key is! String ||
          key.trim().isEmpty ||
          key.length > 64 ||
          depths.containsKey(key)) {
        return '节点编号必须唯一且不为空';
      }
      if (parent != null &&
          (parent is! String || !depths.containsKey(parent))) {
        return '父节点必须位于子节点之前，不能引用缺失节点或形成循环';
      }
      final name = node['title'];
      if (name is! String || name.trim().isEmpty || name.length > 120) {
        return '节点名称需为1–120字';
      }
      if (node['description'] != null &&
          (node['description'] is! String ||
              (node['description'] as String).length > 1000)) {
        return '每个节点说明最多1000字';
      }
      final depth = parent == null ? 1 : depths[parent]! + 1;
      if (depth > 4) return 'AI 大纲最多4层，请分阶段细化';
      depths[key] = depth;
    }
    return null;
  }

  static GoalOutlineImport parse(Map<String, Object?> input) {
    final error = validate(input);
    if (error != null) throw ArgumentError(error);
    final nodes = rows(input);
    List<GoalImportNode> children(String? parent) => [
      for (final node in nodes.where((node) => node['parentKey'] == parent))
        GoalImportNode(
          key: node['key'] as String,
          title: (node['title'] as String).trim(),
          description: _optionalDescription(node['description'] as String?),
          children: children(node['key'] as String),
        ),
    ];
    return GoalOutlineImport(
      title: (input['title'] as String).trim(),
      description: input['description'] as String?,
      why: input['why'] as String?,
      nodes: children(null),
      nodeCount: nodes.length,
    );
  }

  static String? _optionalDescription(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
