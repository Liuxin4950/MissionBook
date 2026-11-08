import 'package:flutter/material.dart';

import '../../application/settings/motion_settings.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';
import '../widgets/app_expansion.dart';
import 'motion_settings_panel.dart';
import '../widgets/app_segmented_control.dart';

/// 强度选择与可操作的共享组件预览，预览使用当前实际生效的偏好。
class MotionPreferencesSheet extends StatefulWidget {
  const MotionPreferencesSheet({super.key, required this.settings});
  final MotionSettings settings;

  static String label(MotionPreference preference) => switch (preference) {
    MotionPreference.system => '跟随系统',
    MotionPreference.full => '开启动效',
    MotionPreference.reduced => '减少动效',
  };

  @override
  State<MotionPreferencesSheet> createState() => _MotionPreferencesSheetState();
}

class _MotionPreferencesSheetState extends State<MotionPreferencesSheet> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final duration = AppMotion.resolve(context, AppMotion.standard);
      return MotionSettingsPanel(
        title: '动效',
        onReplay: () => setState(() => _selected = 1 - _selected),
        replayKey: const Key('motion-preview-replay'),
        preview: AppExpansionTile(
          title: const Text('组件预览'),
          initiallyExpanded: true,
          childrenPadding: const EdgeInsets.all(AppLayout.spaceMd),
          children: [
            AppSegmentedControl<int>(
              options: const {0: '待办', 1: '完成'},
              selected: _selected,
              onSelected: (value) => setState(() => _selected = value),
            ),
            const SizedBox(height: AppLayout.spaceMd),
            AnimatedContainer(
              key: const Key('motion-component-preview'),
              duration: duration,
              curve: AppMotion.curve,
              padding: const EdgeInsets.all(AppLayout.spaceMd),
              decoration: BoxDecoration(
                color: _selected == 0
                    ? colors.surfaceContainer
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppLayout.radiusMd),
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: AppMotion.curve,
                    child: Icon(
                      _selected == 0
                          ? Icons.radio_button_unchecked
                          : Icons.check_circle_outline,
                      color: colors.primary,
                      key: ValueKey(_selected),
                    ),
                  ),
                  const SizedBox(width: AppLayout.spaceMd),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: .25, end: _selected == 0 ? .25 : 1),
                      duration: duration,
                      curve: AppMotion.curve,
                      builder: (_, value, _) => LinearProgressIndicator(
                        key: const Key('motion-preview-progress'),
                        value: value,
                        borderRadius: BorderRadius.circular(
                          AppLayout.radiusPill,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        options: [
          for (final preference in MotionPreference.values)
            ListTile(
              key: ValueKey('motion-option-${preference.name}'),
              title: Text(MotionPreferencesSheet.label(preference)),
              selected: widget.settings.preference == preference,
              trailing: widget.settings.preference == preference
                  ? const Icon(Icons.check)
                  : null,
              enabled: !widget.settings.saving,
              onTap: () async {
                await widget.settings.select(preference);
                if (mounted) setState(() => _selected = 1 - _selected);
              },
            ),
        ],
        error: widget.settings.error,
      );
    },
  );
}
