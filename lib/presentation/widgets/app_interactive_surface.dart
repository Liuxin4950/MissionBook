import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';

/// 可复用的交互行表面，统一选中、悬停和键盘聚焦的颜色与内边距。
class AppInteractiveSurface extends StatefulWidget {
  const AppInteractiveSurface({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.baseColor = Colors.transparent,
    this.selectedColor = AppColors.primarySoft,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppLayout.spaceMd,
      vertical: AppLayout.spaceSm,
    ),
    this.minHeight = AppLayout.touchTargetMin,
    this.borderRadius = AppLayout.radiusMd,
    this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final Color baseColor;

  /// 可让外层动画绘制选中底色，同时保留本组件的悬停与聚焦反馈。
  final Color selectedColor;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final double borderRadius;
  final String? semanticsLabel;

  @override
  State<AppInteractiveSurface> createState() => _AppInteractiveSurfaceState();
}

class _AppInteractiveSurfaceState extends State<AppInteractiveSurface> {
  bool _hovered = false;
  bool _focused = false;

  void _setHovered(bool value) {
    if (_hovered == value || !mounted) return;
    setState(() => _hovered = value);
  }

  void _setFocused(bool value) {
    if (_focused == value || !mounted) return;
    setState(() => _focused = value);
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.enabled && (_hovered || _focused);
    final background = highlighted
        ? AppColors.surfaceMuted
        : widget.selected
        ? widget.selectedColor
        : widget.baseColor;
    final border = _focused && widget.enabled
        ? AppColors.primary
        : Colors.transparent;

    return Semantics(
      label: widget.semanticsLabel,
      button: widget.onTap != null,
      enabled: widget.enabled,
      selected: widget.selected,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onShowHoverHighlight: _setHovered,
        onShowFocusHighlight: _setFocused,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            side: BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.enabled ? widget.onTap : null,
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
