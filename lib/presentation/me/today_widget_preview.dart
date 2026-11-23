import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../../data/settings/today_widget_appearance.dart';
import '../widgets/app_segmented_control.dart';

/// 设置页的小组件预览面板。
///
/// 预览只读原生 `previewAppearance` 的排版计划；切换尺寸和浅深示例只刷新
/// 预览，不写偏好、不更新 Launcher。这里不把画面称为系统桌面截图。
class TodayWidgetPreviewPane extends StatelessWidget {
  const TodayWidgetPreviewPane({
    super.key,
    required this.preview,
    required this.sizeClass,
    required this.exampleTheme,
    required this.loading,
    required this.error,
    required this.onSizeClassChanged,
    required this.onExampleThemeChanged,
    required this.onRetry,
  });

  final TodayWidgetPreview? preview;
  final TodayWidgetSizeClass sizeClass;
  final TodayWidgetTheme exampleTheme;
  final bool loading;
  final String? error;
  final ValueChanged<TodayWidgetSizeClass> onSizeClassChanged;
  final ValueChanged<TodayWidgetTheme> onExampleThemeChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmentedControl<TodayWidgetSizeClass>(
          options: const {
            TodayWidgetSizeClass.small: '小方形',
            TodayWidgetSizeClass.medium: '横向宽卡',
            TodayWidgetSizeClass.large: '大方形',
          },
          selected: sizeClass,
          onSelected: onSizeClassChanged,
          optionKey: (value) =>
              ValueKey('today-widget-preview-size-${value.name}'),
        ),
        const SizedBox(height: AppLayout.spaceSm),
        AppSegmentedControl<TodayWidgetTheme>(
          options: const {
            TodayWidgetTheme.light: '浅色示例',
            TodayWidgetTheme.dark: '深色示例',
          },
          selected: exampleTheme,
          onSelected: onExampleThemeChanged,
          optionKey: (value) =>
              ValueKey('today-widget-preview-theme-${value.name}'),
        ),
        const SizedBox(height: AppLayout.spaceSm),
        Container(
          key: const Key('today-widget-preview-frame'),
          padding: const EdgeInsets.all(AppLayout.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppLayout.radiusLg),
          ),
          child: _previewBody(context),
        ),
        if (current != null && error == null) ...[
          const SizedBox(height: AppLayout.spaceSm),
          Wrap(
            spacing: AppLayout.spaceSm,
            runSpacing: AppLayout.spaceXs,
            children: [
              Text(
                '示例数据',
                key: const Key('today-widget-preview-sample-label'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${current.sizeSource.label} '
                '${current.widthDp} × ${current.heightDp} dp',
                key: const Key('today-widget-preview-size-label'),
                style: theme.textTheme.bodySmall,
              ),
              if (current.overflow != TodayWidgetPreviewOverflow.none)
                Text(
                  switch (current.overflow) {
                    TodayWidgetPreviewOverflow.tight => '空间偏紧，已压缩排版',
                    TodayWidgetPreviewOverflow.headerOnly => '空间不足，仅保留题头入口',
                    TodayWidgetPreviewOverflow.none => '',
                  },
                  key: const Key('today-widget-preview-overflow'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppLayout.spaceXs),
        Text(
          '预览使用与桌面相同的排版计划，实际 Launcher 裁边可能有细微差异。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _previewBody(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: LinearProgressIndicator(semanticsLabel: '正在生成小组件预览'),
        ),
      );
    }
    if (error case final message?) {
      return SizedBox(
        height: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              key: const Key('today-widget-preview-error'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppLayout.spaceXs),
            TextButton(
              key: const Key('today-widget-preview-retry'),
              onPressed: onRetry,
              child: const Text('重试预览'),
            ),
          ],
        ),
      );
    }
    final current = preview;
    if (current == null) {
      return const SizedBox(height: 120);
    }
    return TodayWidgetPreviewCanvas(preview: current);
  }
}

/// 直接显示 Android 用桌面同一份 RemoteViews 渲染出的图像。
/// 设置页只负责按比例缩放，不再用 Flutter 复制原生排版，避免两套 renderer 漂移。
class TodayWidgetPreviewCanvas extends StatelessWidget {
  const TodayWidgetPreviewCanvas({super.key, required this.preview});

  final TodayWidgetPreview preview;

  @override
  Widget build(BuildContext context) {
    final ratio = preview.widthDp / preview.heightDp;
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width / ratio;
        const maxHeight = 280.0;
        if (height > maxHeight) {
          height = maxHeight;
          width = height * ratio;
        }
        return Center(
          child: Semantics(
            container: true,
            image: true,
            label: _semanticsLabel(),
            child: ExcludeSemantics(
              child: SizedBox(
                key: const Key('today-widget-preview-surface'),
                width: width,
                height: height,
                child: Image.memory(
                  preview.renderedPng,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _semanticsLabel() => [
    '小组件预览',
    '示例数据',
    preview.sizeClass.label,
    '${preview.sizeSource.label} ${preview.widthDp} × ${preview.heightDp} dp',
    preview.theme.label,
    preview.style.label,
    if (preview.overflow == TodayWidgetPreviewOverflow.tight) '空间偏紧',
    if (preview.overflow == TodayWidgetPreviewOverflow.headerOnly) '仅保留题头入口',
    if (preview.empty == TodayWidgetPreviewEmpty.waiting) '等待同步',
    if (preview.empty == TodayWidgetPreviewEmpty.empty) '今日暂无任务',
  ].join('，');
}

extension TodayWidgetStyleLabel on TodayWidgetStyle {
  String get label => switch (this) {
    TodayWidgetStyle.paper => '纸页清单',
    TodayWidgetStyle.indexCard => '课程卡片',
    TodayWidgetStyle.minimal => '极简',
    TodayWidgetStyle.timeline => '任务时间轴',
  };
}

extension TodayWidgetThemeLabel on TodayWidgetTheme {
  String get label => switch (this) {
    TodayWidgetTheme.system => '跟随系统',
    TodayWidgetTheme.light => '浅色',
    TodayWidgetTheme.dark => '深色',
  };
}

extension TodayWidgetTimeModeLabel on TodayWidgetTimeMode {
  String get label => switch (this) {
    TodayWidgetTimeMode.none => '不显示',
    TodayWidgetTimeMode.start => '开始时间',
    TodayWidgetTimeMode.range => '开始–结束',
  };
}

extension TodayWidgetSizeClassLabel on TodayWidgetSizeClass {
  String get label => switch (this) {
    TodayWidgetSizeClass.small => '小方形',
    TodayWidgetSizeClass.medium => '横向宽卡',
    TodayWidgetSizeClass.large => '大方形',
  };
}

extension TodayWidgetSizeSourceLabel on TodayWidgetSizeSource {
  String get label => switch (this) {
    TodayWidgetSizeSource.widget => '真实组件尺寸',
    TodayWidgetSizeSource.reference => '参考尺寸',
  };
}
