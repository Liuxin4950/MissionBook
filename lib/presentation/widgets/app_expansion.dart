import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/colors.dart';

/// 全站展开行：标题只占内缩圆角反馈面，展开内容回到所在卡片的内容边界。
class AppExpansionTile extends StatefulWidget {
  const AppExpansionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.children = const [],
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.headerPadding = const EdgeInsets.symmetric(
      horizontal: AppLayout.spaceMd,
      vertical: AppLayout.spaceSm,
    ),
    this.childrenPadding = const EdgeInsets.fromLTRB(
      AppLayout.spaceLg,
      AppLayout.spaceSm,
      AppLayout.spaceLg,
      AppLayout.spaceLg,
    ),
    this.insetHeader = true,
    this.iconColor,
    this.expandedCrossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> children;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry childrenPadding;
  final bool insetHeader;
  final Color? iconColor;
  final CrossAxisAlignment expandedCrossAxisAlignment;

  @override
  State<AppExpansionTile> createState() => _AppExpansionTileState();
}

class _AppExpansionTileState extends State<AppExpansionTile> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpansionChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final duration = AppMotion.resolve(context, AppMotion.quick);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.insetHeader ? AppLayout.spaceSm : 0,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppLayout.radiusMd),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              button: true,
              expanded: _expanded,
              child: InkWell(
                onTap: _toggle,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppLayout.touchTargetMin,
                  ),
                  child: Padding(
                    padding: widget.headerPadding,
                    child: Row(
                      children: [
                        if (widget.leading != null) ...[
                          widget.leading!,
                          const SizedBox(width: AppLayout.spaceMd),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DefaultTextStyle.merge(
                                style: text.titleMedium,
                                child: widget.title,
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 2),
                                DefaultTextStyle.merge(
                                  style: text.bodyMedium,
                                  child: widget.subtitle!,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppLayout.spaceSm),
                        widget.trailing ??
                            AnimatedRotation(
                              turns: _expanded ? .5 : 0,
                              duration: duration,
                              curve: AppMotion.curve,
                              child: Icon(
                                Icons.expand_more,
                                size: AppLayout.iconLg,
                                color:
                                    widget.iconColor ?? AppColors.textSecondary,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: widget.childrenPadding,
                  child: Column(
                    crossAxisAlignment: widget.expandedCrossAxisAlignment,
                    children: widget.children,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
