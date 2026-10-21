import 'package:flutter/material.dart';

import 'mission_details.dart';
import 'today_display.dart';

// 自选时间区域。只接收自选任务列表，不判断时间策略或重新分组。
class FlexibleMissionSection extends StatefulWidget {
  const FlexibleMissionSection({super.key, required this.items});

  final List<TodayMissionItem> items;

  @override
  State<FlexibleMissionSection> createState() => _FlexibleMissionSectionState();
}

class _FlexibleMissionSectionState extends State<FlexibleMissionSection> {
  static const _previewCount = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 折叠只影响排版，完整数据仍由 widget.items 提供，不再查询或转换。
    final hasMore = widget.items.length > _previewCount;
    final visibleItems = _expanded
        ? widget.items
        : widget.items.take(_previewCount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '自选时间',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final item in visibleItems)
            buildFlexibleMissionRow(context, item),
          if (hasMore)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('flexible-missions-toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? '收起' : '展开全部（${widget.items.length}）'),
              ),
            ),
        ],
      ),
    );
  }
}

// 同一套行布局也用于取消折叠区，避免复制图标和文字排版。
Widget buildFlexibleMissionRow(BuildContext context, TodayMissionItem item) {
  final colors = Theme.of(context).colorScheme;
  return Padding(
    key: ValueKey('mission-${item.id}'),
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 24,
                color: colors.primary,
              ),
            ),
          ),
        ),
        Expanded(child: buildMissionDetails(context, item)),
      ],
    ),
  );
}
