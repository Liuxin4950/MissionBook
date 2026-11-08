import 'package:flutter/material.dart';

import '../../application/settings/motion_settings.dart';
import '../../core/theme/app_page_transitions.dart';
import '../../core/theme/app_motion.dart';

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
      final reduced = settings.reduceMotion(systemMedia.disableAnimations);
      final theme = Theme.of(context);
      final feedbackDuration = reduced ? Duration.zero : AppMotion.quick;
      return MotionSettingsScope(
        settings: settings,
        systemReducedMotion: systemMedia.disableAnimations,
        child: MediaQuery(
          data: systemMedia.copyWith(
            disableAnimations: settings.reduceMotion(
              systemMedia.disableAnimations,
            ),
          ),
          child: Theme(
            data: theme.copyWith(
              filledButtonTheme: FilledButtonThemeData(
                style: (theme.filledButtonTheme.style ?? const ButtonStyle())
                    .copyWith(animationDuration: feedbackDuration),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: (theme.outlinedButtonTheme.style ?? const ButtonStyle())
                    .copyWith(animationDuration: feedbackDuration),
              ),
              textButtonTheme: TextButtonThemeData(
                style: (theme.textButtonTheme.style ?? const ButtonStyle())
                    .copyWith(animationDuration: feedbackDuration),
              ),
              iconButtonTheme: IconButtonThemeData(
                style: (theme.iconButtonTheme.style ?? const ButtonStyle())
                    .copyWith(animationDuration: feedbackDuration),
              ),
              expansionTileTheme: theme.expansionTileTheme.copyWith(
                expansionAnimationStyle: AnimationStyle(
                  duration: reduced ? Duration.zero : AppMotion.standard,
                  reverseDuration: reduced ? Duration.zero : AppMotion.exit,
                  curve: AppMotion.curve,
                ),
              ),
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  for (final platform in TargetPlatform.values)
                    platform: AppPageTransitionsBuilder(
                      platformBuilder:
                          theme.pageTransitionsTheme.builders[platform] ??
                          const ZoomPageTransitionsBuilder(),
                      style: settings.pageStyle,
                      reduced: reduced,
                    ),
                },
              ),
            ),
            child: child,
          ),
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
