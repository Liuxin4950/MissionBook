import 'package:flutter/material.dart';

/// 根据区域实际宽度分列。始终使用同一棵 Wrap 子树，缩放时保留字段与展开状态。
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({
    super.key,
    required this.children,
    this.minColumnWidth = 320,
    this.maxColumns = 3,
    this.spacing = 20,
  });
  final List<Widget> children;
  final double minColumnWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (children.isEmpty) return const SizedBox.shrink();
      final limit = children.length < maxColumns ? children.length : maxColumns;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns =
          ((box.maxWidth + spacing) / (minColumnWidth * scale + spacing))
              .floor()
              .clamp(1, limit);
      final width = (box.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
