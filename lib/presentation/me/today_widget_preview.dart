import 'dart:math' as math;

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
            TodayWidgetSizeClass.small: '小号',
            TodayWidgetSizeClass.medium: '中号',
            TodayWidgetSizeClass.large: '大号',
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

/// 按原生预览计划绘制的小组件画面。
///
/// 色调、字号、间距、圆角、头尾和空态都来自回执；画面按真实宽高比放置，
/// 外层用 FittedBox 缩放，不参与设置页的字体缩放。
class TodayWidgetPreviewCanvas extends StatelessWidget {
  const TodayWidgetPreviewCanvas({super.key, required this.preview});

  final TodayWidgetPreview preview;

  @override
  Widget build(BuildContext context) {
    final width = preview.widthDp.toDouble();
    final height = preview.heightDp.toDouble();
    final ratio = width / height;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        var canvasWidth = available;
        var canvasHeight = ratio == 0 ? 0.0 : available / ratio;
        const maxHeight = 280.0;
        if (canvasHeight > maxHeight) {
          canvasHeight = maxHeight;
          canvasWidth = canvasHeight * ratio;
        }
        return Center(
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: Semantics(
              container: true,
              label: _semanticsLabel(),
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    key: const Key('today-widget-preview-surface'),
                    width: width,
                    height: height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        preview.metrics.radius.toDouble(),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _color(preview.colors.content),
                          border: Border.all(
                            color: _color(preview.colors.hairline),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(
                            preview.metrics.radius.toDouble(),
                          ),
                        ),
                        child: MediaQuery.withNoTextScaling(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: preview.metrics.horizontalPadding
                                  .toDouble(),
                              vertical: preview.metrics.verticalPadding
                                  .toDouble(),
                            ),
                            child: _content(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _content() {
    final metrics = preview.metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview.header.visible)
          SizedBox(height: metrics.headerHeight.toDouble(), child: _header()),
        Expanded(
          child: preview.empty == TodayWidgetPreviewEmpty.none
              ? _rows()
              : _emptyState(),
        ),
        if (preview.footer.visible)
          SizedBox(height: metrics.footerHeight.toDouble(), child: _footer()),
      ],
    );
  }

  Widget _header() {
    final header = preview.header;
    final metrics = preview.metrics;
    final primary = _textStyle(
      metrics.headerSp,
      _color(preview.colors.primaryText),
      FontWeight.w700,
    );
    final secondary = _textStyle(
      metrics.metaSp,
      _color(preview.colors.secondaryText),
      FontWeight.w400,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            header.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: primary,
          ),
        ),
        if (header.count case final count?) ...[
          const SizedBox(width: 4),
          Text(
            count,
            style: _textStyle(
              metrics.metaSp,
              _color(preview.colors.accent),
              FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(width: 4),
        Text(header.right, maxLines: 1, style: secondary),
      ],
    );
  }

  Widget _rows() {
    final metrics = preview.metrics;
    // 计划已经决定可见行；用固定行高避免文字度量与原生计划出现第二套排版。
    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < preview.rows.length; index++) ...[
              if (index > 0) SizedBox(height: metrics.rowGap.toDouble()),
              SizedBox(
                key: ValueKey('today-widget-preview-row-$index'),
                height: metrics.rowHeight.toDouble(),
                child: _row(preview.rows[index], index: index),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(TodayWidgetPreviewRow row, {required int index}) {
    final metrics = preview.metrics;
    final colors = preview.colors;
    final style = preview.style;
    // 版式、书脊与分隔线都直接取原生计划，不在 Flutter 侧二次推断。
    final wide = preview.rowLayout == TodayWidgetPreviewRowLayout.wide;
    final showSpine = preview.spineVisible;
    final hasMetaLine =
        (row.showTime && row.time != null) ||
        (row.showStatus && row.status != null);
    final availableHeight = metrics.rowHeight - 2 * metrics.rowPadding;
    final usedHeight =
        row.titleMaxLines * (metrics.taskSp * 1.15) +
        (hasMetaLine ? metrics.metaSp * 1.15 + 2 : 0);
    final showProgress =
        !wide &&
        row.progress != null &&
        availableHeight - usedHeight >= metrics.metaSp * 1.15;
    final titleStyle = _textStyle(
      metrics.taskSp,
      _color(colors.primaryText),
      FontWeight.w600,
    );
    final metaStyle = _textStyle(
      metrics.metaSp,
      _color(colors.secondaryText),
      FontWeight.w400,
    );
    final statusColor = (row.status ?? '').contains('待确认')
        ? _color(colors.warn)
        : _color(colors.accent);
    final statusStyle = _textStyle(
      metrics.metaSp,
      statusColor,
      FontWeight.w600,
    );
    final Widget content;
    if (!wide) {
      content = SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              row.title,
              maxLines: row.titleMaxLines,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
            if (row.showTime || row.showStatus) ...[
              const SizedBox(height: 2),
              Text.rich(
                key: ValueKey('today-widget-preview-row-$index-meta'),
                TextSpan(
                  children: [
                    if (row.showTime && row.time != null)
                      TextSpan(text: row.time),
                    if (row.showTime &&
                        row.time != null &&
                        row.showStatus &&
                        row.status != null)
                      const TextSpan(text: ' · '),
                    if (row.showStatus && row.status != null)
                      TextSpan(text: row.status, style: statusStyle),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle,
              ),
            ],
            if (showProgress && row.progress != null) ...[
              const SizedBox(height: 2),
              Text(
                row.progress!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle,
              ),
            ],
          ],
        ),
      );
    } else {
      content = Row(
        children: [
          if (row.showTime && row.time != null) ...[
            SizedBox(
              width: math.max(38, metrics.metaSp * 4.0),
              child: Text(
                row.time!,
                key: ValueKey('today-widget-preview-row-$index-time'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: row.titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  if (showProgress && row.progress != null)
                    Text(
                      row.progress!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: metaStyle,
                    ),
                ],
              ),
            ),
          ),
          if (row.showStatus && row.status != null) ...[
            const SizedBox(width: 4),
            Text(
              row.status!,
              key: ValueKey('today-widget-preview-row-$index-status'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: statusStyle,
            ),
          ],
        ],
      );
    }
    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        showSpine ? 0 : 2,
        metrics.rowPadding.toDouble(),
        2,
        metrics.rowPadding.toDouble(),
      ),
      child: content,
    );
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: style == TodayWidgetStyle.indexCard
            ? _color(colors.rowSurface)
            : Colors.transparent,
        borderRadius: style == TodayWidgetStyle.indexCard
            ? BorderRadius.circular(AppLayout.radiusSm)
            : null,
      ),
      child: showSpine
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: ValueKey('today-widget-preview-row-$index-spine'),
                  width: 3,
                  decoration: BoxDecoration(
                    color: _color(colors.spine),
                    borderRadius: BorderRadius.circular(
                      style == TodayWidgetStyle.indexCard ? 8 : 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: body),
              ],
            )
          : body,
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        surface,
        if (preview.dividerVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              key: ValueKey('today-widget-preview-row-$index-divider'),
              height: 1,
              color: _color(colors.hairline),
            ),
          ),
      ],
    );
  }

  Widget _emptyState() {
    final metrics = preview.metrics;
    final text = switch (preview.empty) {
      TodayWidgetPreviewEmpty.waiting => '等待同步',
      TodayWidgetPreviewEmpty.empty => '今日暂无任务',
      TodayWidgetPreviewEmpty.none => '',
    };
    return Center(
      child: Text(
        text,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: _textStyle(
          metrics.metaSp,
          _color(preview.colors.secondaryText),
          FontWeight.w400,
        ),
      ),
    );
  }

  Widget _footer() {
    final footer = preview.footer;
    final metrics = preview.metrics;
    final text = footer.text;
    if (text == null) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _textStyle(
          metrics.metaSp,
          _color(preview.colors.accent),
          FontWeight.w600,
        ),
      ),
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

  static TextStyle _textStyle(int size, Color color, FontWeight weight) =>
      TextStyle(
        fontSize: size.toDouble(),
        height: 1.15,
        color: color,
        fontWeight: weight,
      );

  static Color _color(int argb) => Color(argb);
}

extension TodayWidgetStyleLabel on TodayWidgetStyle {
  String get label => switch (this) {
    TodayWidgetStyle.paper => '纸页清单',
    TodayWidgetStyle.indexCard => '索引卡',
    TodayWidgetStyle.minimal => '极简',
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
    TodayWidgetSizeClass.small => '小号',
    TodayWidgetSizeClass.medium => '中号',
    TodayWidgetSizeClass.large => '大号',
  };
}

extension TodayWidgetSizeSourceLabel on TodayWidgetSizeSource {
  String get label => switch (this) {
    TodayWidgetSizeSource.widget => '真实组件尺寸',
    TodayWidgetSizeSource.reference => '参考尺寸',
  };
}
