import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';

/// 将鼠标和键盘反馈限制在选项圆角内，勾选同时表达当前值。
class AppSelectionOption extends StatefulWidget {
  const AppSelectionOption({
    super.key,
    required this.selected,
    required this.enabled,
    required this.child,
  });

  final bool selected;
  final bool enabled;
  final Widget child;

  @override
  State<AppSelectionOption> createState() => _AppSelectionOptionState();
}

class _AppSelectionOptionState extends State<AppSelectionOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final focused = Focus.of(context).hasFocus && widget.enabled;
    return Semantics(
      selected: widget.selected,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppLayout.touchTargetMin,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.spaceMd,
            vertical: AppLayout.spaceSm,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primarySoft
                : (_hovered || focused) && widget.enabled
                ? AppColors.surfaceMuted
                : AppColors.card,
            borderRadius: BorderRadius.circular(AppLayout.radiusMd),
            border: Border.all(
              color: focused ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: DefaultTextStyle.merge(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: !widget.enabled
                        ? AppColors.onDisabled
                        : widget.selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: widget.selected
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                  child: widget.child,
                ),
              ),
              const SizedBox(width: AppLayout.spaceSm),
              SizedBox(
                width: AppLayout.iconSm,
                child: widget.selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: AppLayout.iconSm,
                        color: AppColors.primary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
