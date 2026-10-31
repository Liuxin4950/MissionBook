import 'package:flutter/material.dart';

import '../../application/assistant/assistant_goal_outline.dart';
import '../../core/theme/app_layout.dart';

/// 整份目标大纲的草稿编辑，不在编辑过程中写业务数据。
class AssistantOutlineEditor extends StatefulWidget {
  const AssistantOutlineEditor({
    super.key,
    required this.input,
    required this.onSave,
    required this.onCancel,
  });
  final Map<String, Object?> input;
  final String? Function(Map<String, Object?>) onSave;
  final VoidCallback onCancel;

  @override
  State<AssistantOutlineEditor> createState() => _AssistantOutlineEditorState();
}

class _AssistantOutlineEditorState extends State<AssistantOutlineEditor> {
  late final _nodes = AssistantGoalOutline.rows(widget.input);
  late final _fields = <String, TextEditingController>{
    for (final field in ['title', 'description', 'why'])
      field: TextEditingController(text: widget.input[field] as String? ?? ''),
    for (final node in _nodes)
      for (final field in ['title', 'description'])
        '${node['key']}:$field': TextEditingController(
          text: node[field] as String? ?? '',
        ),
  };
  final _removed = <String>{};
  String? _error;

  void _remove(String key) {
    setState(() {
      _removed.add(key);
      // 父节点先于子节点，顺序扫描即可移除整棵草稿子树。
      for (final node in _nodes) {
        if (_removed.contains(node['parentKey'])) {
          _removed.add(node['key'] as String);
        }
      }
    });
  }

  void _save() {
    final input = <String, Object?>{
      for (final field in ['title', 'description', 'why'])
        field: _fields[field]!.text.trim(),
      'nodes': [
        for (final node in _nodes.where(
          (node) => !_removed.contains(node['key']),
        ))
          {
            ...node,
            for (final field in ['title', 'description'])
              field: _fields['${node['key']}:$field']!.text.trim(),
          },
      ],
    };
    final error = AssistantGoalOutline.validate(input) ?? widget.onSave(input);
    if (error != null) setState(() => _error = error);
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String label, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: AppLayout.spaceMd),
    child: TextField(
      key: ValueKey('outline-field-$key'),
      controller: _fields[key],
      minLines: 1,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final depths = <String, int>{};
    for (final node in _nodes) {
      depths[node['key'] as String] = node['parentKey'] == null
          ? 1
          : depths[node['parentKey']]! + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field('title', '目标名称'),
        _field('description', '目标说明', lines: 3),
        _field('why', '为什么要做', lines: 2),
        const Text('移除节点会同时移除其子节点；保存提案后仍需确认执行。'),
        const SizedBox(height: AppLayout.spaceMd),
        for (final node in _nodes.where(
          (node) => !_removed.contains(node['key']),
        ))
          Padding(
            padding: EdgeInsets.only(
              left: (depths[node['key']]! - 1) * 12.0,
              bottom: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '第${depths[node['key']]}层节点',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('outline-remove-${node['key']}'),
                      tooltip: '移除该节点及其子节点',
                      onPressed: () => _remove(node['key'] as String),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
                _field('${node['key']}:title', '节点名称'),
                _field('${node['key']}:description', '学习内容或验收方向', lines: 3),
              ],
            ),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppLayout.spaceSm,
          children: [
            TextButton(onPressed: widget.onCancel, child: const Text('取消修改')),
            FilledButton(onPressed: _save, child: const Text('保存提案')),
          ],
        ),
      ],
    );
  }
}
