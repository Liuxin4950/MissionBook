import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';

/// 自适应弹层：手机从底部升起（现行稿），平板/桌面居中为对话框。
/// 两种形态共用同一份内容构建器；离开确认等关闭逻辑仍由调用方掌控，
/// 这里只决定“从哪里升起”，不改变任何业务语义。
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = false,
  bool isDismissible = true,
  bool enableDrag = true,
  BoxConstraints? constraints,
  Color? backgroundColor,
}) {
  if (AppLayout.windowClassOf(context) == WindowClass.compact) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: true,
      constraints:
          constraints ?? const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
      backgroundColor: backgroundColor,
    );
  }
  // 宽屏：居中对话框。高度封顶九成屏高、宽度封顶 detailPaneMaxWidth；
  // 内容自带的高度/滚动约束（FractionallySizedBox、ListView 等）照常生效。
  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    builder: (dialogContext) => Dialog(
      backgroundColor: backgroundColor ?? AppColors.background,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(AppLayout.spaceXxl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppLayout.detailPaneMaxWidth,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * .9,
        ),
        child: builder(dialogContext),
      ),
    ),
  );
}
