import 'package:flutter/material.dart';

import '../../../application/assistant/assistant_provider_catalog.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/colors.dart';
import '../../widgets/app_interactive_surface.dart';

/// 按服务分组选择模型，返回 profileId，取消返回 null。
class AssistantModelChoicePicker extends StatefulWidget {
  const AssistantModelChoicePicker({
    super.key,
    required this.choices,
    this.title = '选择模型',
    this.selectedProfileId,
    this.followDefaultLabel,
  });

  final List<({ProviderConfig provider, ProviderModel model})> choices;
  final String title;
  final String? selectedProfileId;

  /// 提供后可选“跟随默认模型”，该选项返回空字符串。
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
    return _ModelPickerDialog(
      title: widget.title,
      searchLabel: '搜索服务或模型',
      onSearch: (value) => setState(() => _query = value.trim()),
      slivers: [
        if (widget.followDefaultLabel != null && normalized.isEmpty)
          SliverToBoxAdapter(
            child: _ModelChoiceRow(
              title: widget.followDefaultLabel!,
              selected: widget.selectedProfileId == null,
              onTap: () => Navigator.of(context).pop(''),
            ),
          ),
        if (groups.isEmpty)
          _emptyModels(widget.choices.isEmpty ? '暂无可用模型' : '没有匹配的模型'),
        for (final group in groups.values) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppMetrics.spaceLg,
                AppMetrics.spaceLg,
                AppMetrics.spaceLg,
                AppMetrics.spaceXs,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  group.first.provider.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: group.length,
            itemBuilder: (context, index) {
              final choice = group[index];
              return _ModelChoiceRow(
                title: choice.model.label,
                subtitle: choice.model.label == choice.model.modelId
                    ? null
                    : choice.model.modelId,
                selected: choice.model.profileId == widget.selectedProfileId,
                onTap: () => Navigator.of(context).pop(choice.model.profileId),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// 在服务实际返回的模型列表中搜索并选择编号。
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
    return _ModelPickerDialog(
      title: '添加模型',
      searchLabel: '搜索模型',
      onSearch: (value) => setState(() => _query = value.trim()),
      slivers: [
        if (models.isEmpty)
          _emptyModels(widget.models.isEmpty ? '服务未返回模型' : '没有匹配的模型'),
        SliverList.builder(
          itemCount: models.length,
          itemBuilder: (context, index) {
            final model = models[index];
            return _ModelChoiceRow(
              title: model,
              selected: model == widget.selected,
              onTap: () => Navigator.of(context).pop(model),
            );
          },
        ),
      ],
    );
  }
}

/// 搜索与列表共用可滚动视口，键盘或短横屏压缩高度时仍可操作。
class _ModelPickerDialog extends StatelessWidget {
  const _ModelPickerDialog({
    required this.title,
    required this.searchLabel,
    required this.onSearch,
    required this.slivers,
  });

  final String title;
  final String searchLabel;
  final ValueChanged<String> onSearch;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(AppMetrics.spaceLg),
    backgroundColor: AppColors.card,
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
    child: CustomScrollView(
      shrinkWrap: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppMetrics.spaceLg),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '取消',
                      constraints: const BoxConstraints.tightFor(
                        width: AppMetrics.touchTargetMin,
                        height: AppMetrics.touchTargetMin,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppMetrics.spaceSm),
                TextField(
                  decoration: InputDecoration(
                    labelText: searchLabel,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                  onChanged: onSearch,
                ),
              ],
            ),
          ),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: AppMetrics.spaceSm)),
      ],
    ),
  );
}

class _ModelChoiceRow extends StatelessWidget {
  const _ModelChoiceRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppMetrics.spaceSm),
    child: AppInteractiveSurface(
      selected: selected,
      onTap: onTap,
      semanticsLabel: title,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_rounded,
              size: AppMetrics.iconSm,
              color: AppColors.primary,
            ),
        ],
      ),
    ),
  );
}

Widget _emptyModels(String message) => SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.all(AppMetrics.spaceXxl),
    child: Text(message, textAlign: TextAlign.center),
  ),
);
