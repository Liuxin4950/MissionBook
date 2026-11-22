import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import 'app_interactive_surface.dart';

/// 将鼠标和键盘反馈限制在选项圆角内，勾选同时表达当前值。
class AppSelectionOption extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AppInteractiveSurface(
      selected: selected,
      enabled: enabled,
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle.merge(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: !enabled
                    ? AppColors.onDisabled
                    : selected
                    ? AppColors.primary
                    : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
              child: child,
            ),
          ),
          const SizedBox(width: AppLayout.spaceSm),
          SizedBox(
            width: AppLayout.iconSm,
            child: selected
                ? const Icon(
                    Icons.check_rounded,
                    size: AppLayout.iconSm,
                    color: AppColors.primary,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
