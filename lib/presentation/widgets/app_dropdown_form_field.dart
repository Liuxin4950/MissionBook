import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';

/// 共用表单下拉样式；沿用系统菜单的键盘导航、滚动、选择及返回行为。
class AppDropdownFormField<T> extends StatelessWidget {
  const AppDropdownFormField({
    super.key,
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.decoration,
    this.style,
    this.isExpanded = true,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? initialValue;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      // 选项自己呈现内缩圆角反馈，避免默认整行方形焦点底与其重叠。
      data: theme.copyWith(
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: DropdownButtonFormField<T>(
        initialValue: initialValue,
        onChanged: onChanged,
        decoration: decoration,
        style: style ?? theme.textTheme.bodyLarge,
        isExpanded: isExpanded,
        dropdownColor: AppColors.card,
        elevation: 2,
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        menuMaxHeight: 360,
        // 允许大字和长选项自然增高，菜单超出可用高度后滚动。
        itemHeight: null,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        selectedItemBuilder: (_) => [for (final item in items) item.child],
        items: [
          for (final item in items)
            DropdownMenuItem<T>(
              value: item.value,
              enabled: item.enabled,
              onTap: item.onTap,
              child: _DropdownOption(
                selected: item.value == initialValue,
                enabled: item.enabled,
                child: item.child,
              ),
            ),
        ],
      ),
    );
  }
}

/// 将鼠标和键盘反馈限制在选项圆角内，勾选同时表达当前值。
class _DropdownOption extends StatefulWidget {
  const _DropdownOption({
    required this.selected,
    required this.enabled,
    required this.child,
  });

  final bool selected;
  final bool enabled;
  final Widget child;

  @override
  State<_DropdownOption> createState() => _DropdownOptionState();
}

class _DropdownOptionState extends State<_DropdownOption> {
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
          margin: const EdgeInsets.symmetric(vertical: AppLayout.spaceXs),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
