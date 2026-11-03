import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import 'app_selection_option.dart';

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
              child: AppSelectionOption(
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
