import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';

/// 设置类页面的统一行：56 高、图标、标题、短说明与尾部动作。
/// 行所在卡片负责圆角与裁剪，按压反馈不再使用原生长条底。
class AppSettingsRow extends StatelessWidget {
  const AppSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final active = enabled && onTap != null;
    return Semantics(
      button: active,
      enabled: enabled,
      child: InkWell(
        onTap: active ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.spaceLg,
              vertical: AppLayout.spaceSm,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: AppLayout.iconMd,
                  color: enabled
                      ? AppColors.textSecondary
                      : AppColors.onDisabled,
                ),
                const SizedBox(width: AppLayout.spaceMd),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.onDisabled,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: enabled
                                ? AppColors.textSecondary
                                : AppColors.onDisabled,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppLayout.spaceSm),
                  trailing!,
                ] else if (active)
                  const Icon(
                    Icons.chevron_right,
                    size: AppLayout.iconMd,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
