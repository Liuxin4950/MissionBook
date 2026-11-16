import 'package:flutter/material.dart';
import 'dart:async';

import '../../application/settings/motion_settings.dart';
import '../../core/theme/app_layout.dart';
import 'motion_settings_panel.dart';

/// 页面风格即时保存，内嵌真实路由供用户预览进入与返回。
class MotionStyleSheet extends StatefulWidget {
  const MotionStyleSheet({super.key, required this.settings});
  final MotionSettings settings;

  static String label(PageMotionStyle style) => switch (style) {
    PageMotionStyle.platform => '跟随平台',
    PageMotionStyle.fade => '淡入',
    PageMotionStyle.slide => '轻滑动',
    PageMotionStyle.zoom => '柔和缩放',
    PageMotionStyle.lift => '上移进入',
    PageMotionStyle.push => '横向推入',
    PageMotionStyle.fadeThrough => '淡出穿入',
  };

  static IconData icon(PageMotionStyle style) => switch (style) {
    PageMotionStyle.platform => Icons.devices_outlined,
    PageMotionStyle.fade => Icons.gradient_outlined,
    PageMotionStyle.slide => Icons.swipe_outlined,
    PageMotionStyle.zoom => Icons.zoom_out_map_rounded,
    PageMotionStyle.lift => Icons.vertical_align_top_rounded,
    PageMotionStyle.push => Icons.view_carousel_outlined,
    PageMotionStyle.fadeThrough => Icons.layers_outlined,
  };

  @override
  State<MotionStyleSheet> createState() => _MotionStyleSheetState();
}

class _MotionStyleSheetState extends State<MotionStyleSheet> {
  final _preview = GlobalKey<NavigatorState>();
  MaterialPageRoute<void>? _previewRoute;
  bool _changing = false;

  Future<void> _play() async {
    final navigator = _preview.currentState;
    if (_changing || navigator == null) return;
    _changing = true;
    try {
      if (navigator.canPop()) {
        final route = _previewRoute;
        navigator.pop();
        await route?.completed;
      }
      if (!mounted || !navigator.mounted) return;
      final route = MaterialPageRoute<void>(
        builder: (_) => _previewPage(opened: true),
      );
      _previewRoute = route;
      unawaited(navigator.push(route));
    } finally {
      _changing = false;
    }
  }

  Widget _previewPage({bool opened = false}) => Material(
    key: ValueKey(opened ? 'motion-preview-detail' : 'motion-preview-list'),
    color: opened
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(AppLayout.spaceMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!opened)
            for (var index = 0; index < 2; index++)
              Padding(
                padding: const EdgeInsets.all(AppLayout.spaceXs),
                child: Row(
                  children: [
                    Icon(Icons.radio_button_unchecked, size: AppLayout.iconSm),
                    const SizedBox(width: AppLayout.spaceSm),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: index == 0 ? .65 : .35,
                      ),
                    ),
                  ],
                ),
              ),
          if (opened)
            Icon(
              Icons.task_alt,
              color: Theme.of(context).colorScheme.primary,
              size: AppLayout.iconLg,
            ),
          TextButton.icon(
            icon: Icon(opened ? Icons.arrow_back : Icons.play_arrow_outlined),
            label: Text(opened ? '返回' : '预览'),
            onPressed: () {
              if (opened) {
                _preview.currentState!.pop();
              } else {
                unawaited(_play());
              }
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => MotionSettingsPanel(
      title: '页面切换',
      onReplay: _play,
      replayKey: const Key('page-motion-replay'),
      maxOptionColumns: 2,
      preview: SizedBox(
        height: 120 + MediaQuery.textScalerOf(context).scale(14),
        child: Navigator(
          key: _preview,
          requestFocus: false,
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => _previewPage()),
        ),
      ),
      options: [
        for (final style in PageMotionStyle.values)
          MotionSettingsOption(
            key: ValueKey('page-style-${style.name}'),
            label: MotionStyleSheet.label(style),
            icon: MotionStyleSheet.icon(style),
            selected: widget.settings.pageStyle == style,
            enabled: !widget.settings.saving,
            onTap: () async {
              await widget.settings.selectPageStyle(style);
              if (mounted && widget.settings.error == null) await _play();
            },
          ),
      ],
      error: widget.settings.error,
    ),
  );
}
