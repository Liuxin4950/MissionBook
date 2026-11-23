import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../data/settings/today_widget_appearance.dart';
import '../widgets/app_section_header.dart';

/// Controls all copies of the Android Today widget without re-adding them.
class TodayWidgetAppearanceSheet extends StatefulWidget {
  const TodayWidgetAppearanceSheet({super.key});

  @override
  State<TodayWidgetAppearanceSheet> createState() =>
      _TodayWidgetAppearanceSheetState();
}

class _TodayWidgetAppearanceSheetState
    extends State<TodayWidgetAppearanceSheet> {
  TodayWidgetAppearance? _appearance;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final value = await TodayWidgetAppearance.load();
      if (mounted) setState(() => _appearance = value);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法读取小组件样式。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save(TodayWidgetAppearance value) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await value.save();
      if (mounted) setState(() => _appearance = value);
    } catch (_) {
      if (mounted) setState(() => _error = '无法应用小组件样式，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearance = _appearance;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppLayout.spaceXl,
          AppLayout.spaceSm,
          AppLayout.spaceXl,
          AppLayout.spaceXl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: AppSectionHeader('桌面小组件样式')),
                IconButton(
                  tooltip: '关闭小组件样式',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text('只影响安卓桌面，已添加的小组件无需重新添加。', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppLayout.spaceLg),
            if (appearance != null) ...[
              const AppSectionHeader('颜色', subtle: true),
              const SizedBox(height: AppLayout.spaceXs),
              Wrap(
                spacing: AppLayout.spaceSm,
                children: [
                  for (final mode in TodayWidgetTheme.values)
                    ChoiceChip(
                      key: ValueKey('today-widget-theme-${mode.name}'),
                      label: Text(switch (mode) {
                        TodayWidgetTheme.system => '跟随系统',
                        TodayWidgetTheme.light => '浅色',
                        TodayWidgetTheme.dark => '深色',
                      }),
                      selected: appearance.theme == mode,
                      onSelected: _saving
                          ? null
                          : (selected) {
                              if (selected) {
                                unawaited(
                                  _save(
                                    TodayWidgetAppearance(
                                      theme: mode,
                                      textSize: appearance.textSize,
                                    ),
                                  ),
                                );
                              }
                            },
                    ),
                ],
              ),
              const SizedBox(height: AppLayout.spaceMd),
              const AppSectionHeader('文字大小', subtle: true),
              const SizedBox(height: AppLayout.spaceXs),
              Wrap(
                spacing: AppLayout.spaceSm,
                children: [
                  for (final size in TodayWidgetTextSize.values)
                    ChoiceChip(
                      key: ValueKey('today-widget-text-${size.name}'),
                      label: Text(
                        size == TodayWidgetTextSize.standard ? '标准' : '大字',
                      ),
                      selected: appearance.textSize == size,
                      onSelected: _saving
                          ? null
                          : (selected) {
                              if (selected) {
                                unawaited(
                                  _save(
                                    TodayWidgetAppearance(
                                      theme: appearance.theme,
                                      textSize: size,
                                    ),
                                  ),
                                );
                              }
                            },
                    ),
                ],
              ),
            ],
            if (_saving || (appearance == null && _error == null))
              Padding(
                padding: const EdgeInsets.only(top: AppLayout.spaceSm),
                child: LinearProgressIndicator(
                  semanticsLabel: _saving ? '正在应用小组件样式' : '正在读取小组件样式',
                ),
              ),
            if (_error case final error?) ...[
              const SizedBox(height: AppLayout.spaceSm),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              if (appearance == null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(onPressed: _load, child: const Text('重试')),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
