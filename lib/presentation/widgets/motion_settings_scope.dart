import 'package:flutter/material.dart';

import '../../application/settings/motion_settings.dart';

/// 把本机选择统一应用到页面、弹层和导航动画。
class MotionSettingsHost extends StatelessWidget {
  const MotionSettingsHost({
    super.key,
    required this.settings,
    required this.child,
  });
  final MotionSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final systemMedia = MediaQuery.of(context);
      return MotionSettingsScope(
        settings: settings,
        systemReducedMotion: systemMedia.disableAnimations,
        child: MediaQuery(
          data: systemMedia.copyWith(
            disableAnimations: settings.reduceMotion(
              systemMedia.disableAnimations,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}

/// 动效选择作用于完整导航树；系统偏好保留给“跟随系统”的状态说明。
class MotionSettingsScope extends InheritedNotifier<MotionSettings> {
  const MotionSettingsScope({
    super.key,
    required MotionSettings settings,
    required this.systemReducedMotion,
    required super.child,
  }) : super(notifier: settings);

  final bool systemReducedMotion;
  MotionSettings get settings => notifier!;

  static MotionSettingsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionSettingsScope>();

  @override
  bool updateShouldNotify(covariant MotionSettingsScope oldWidget) =>
      systemReducedMotion != oldWidget.systemReducedMotion ||
      super.updateShouldNotify(oldWidget);
}
