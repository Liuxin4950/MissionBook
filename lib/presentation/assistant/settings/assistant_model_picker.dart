import 'package:flutter/material.dart';

import '../../../application/assistant/assistant_provider_catalog.dart';

/// 按服务分组的可选模型；返回 `profileId`，取消返回 null。
class AssistantModelChoicePicker extends StatefulWidget {
  const AssistantModelChoicePicker({
    super.key,
    required this.choices,
    this.selectedProfileId,
    this.followDefaultLabel,
  });

  final List<({ProviderConfig provider, ProviderModel model})> choices;
  final String? selectedProfileId;

  /// 传入后在弹层底部提供“跟随默认模型”动作。
  final String? followDefaultLabel;

  @override
  State<AssistantModelChoicePicker> createState() =>
      _AssistantModelChoicePickerState();
}

class _AssistantModelChoicePickerState
    extends State<AssistantModelChoicePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = _query.toLowerCase();
    final groups =
        <String, List<({ProviderConfig provider, ProviderModel model})>>{};
    for (final choice in widget.choices) {
      final matches =
          choice.model.label.toLowerCase().contains(normalized) ||
          choice.model.modelId.toLowerCase().contains(normalized) ||
          choice.provider.displayName.toLowerCase().contains(normalized);
      if (!matches) continue;
      groups.putIfAbsent(choice.provider.providerId, () => []).add(choice);
    }
    return AlertDialog(
      title: const Text('选择模型'),
      content: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height * .5,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '搜索服务或模型',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: groups.isEmpty
                  ? const Center(child: Text('没有可用模型'))
                  : ListView(
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              entry.value.first.provider.displayName,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          for (final choice in entry.value)
                            ListTile(
                              dense: true,
                              title: Text(choice.model.label),
                              subtitle: Text(
                                '${choice.model.modelId} · ${choice.model.contextWindowTokens} 上下文',
                              ),
                              selected:
                                  choice.model.profileId ==
                                  widget.selectedProfileId,
                              trailing:
                                  choice.model.profileId ==
                                      widget.selectedProfileId
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () => Navigator.of(
                                context,
                              ).pop(choice.model.profileId),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.followDefaultLabel != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(widget.followDefaultLabel!),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// 在服务返回的真实模型列表中搜索并选择一个编号。
class AssistantModelPicker extends StatefulWidget {
  const AssistantModelPicker({
    super.key,
    required this.models,
    required this.selected,
  });
  final List<String> models;
  final String selected;

  @override
  State<AssistantModelPicker> createState() => _AssistantModelPickerState();
}

class _AssistantModelPickerState extends State<AssistantModelPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final models = widget.models
        .where((model) => model.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return AlertDialog(
      title: const Text('选择模型'),
      content: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height * .45,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '搜索模型',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: models.isEmpty
                  ? const Center(child: Text('没有匹配的模型'))
                  : ListView.builder(
                      itemCount: models.length,
                      itemBuilder: (context, index) {
                        final model = models[index];
                        return ListTile(
                          title: Text(model),
                          selected: model == widget.selected,
                          trailing: model == widget.selected
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.of(context).pop(model),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
