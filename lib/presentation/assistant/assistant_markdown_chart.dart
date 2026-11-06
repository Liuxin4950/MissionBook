import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/theme/app_layout.dart';

/// 只把助手明确标记的 JSON 数据转成原生图表，不执行模型提供的代码。
class AssistantChartMarkdownElementBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => AssistantMarkdownChart(raw: element.textContent);
}

class AssistantMarkdownChart extends StatelessWidget {
  const AssistantMarkdownChart({super.key, required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    final chart = AssistantChartData.tryParse(raw);
    if (chart == null) {
      return _ChartFrame(title: '图表数据无法显示', child: SelectableText(raw));
    }
    return _ChartFrame(
      title: chart.title,
      child: chart.type == AssistantChartType.bar
          ? _BarChart(data: chart)
          : _LineChart(data: chart),
    );
  }
}

enum AssistantChartType { bar, line }

@immutable
class AssistantChartPoint {
  const AssistantChartPoint({required this.label, required this.value});

  final String label;
  final double value;
}

@immutable
class AssistantChartData {
  const AssistantChartData({
    required this.type,
    required this.title,
    required this.unit,
    required this.points,
  });

  final AssistantChartType type;
  final String title;
  final String unit;
  final List<AssistantChartPoint> points;

  static AssistantChartData? tryParse(String raw) {
    if (raw.length > 4096) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final type = switch (decoded['type']) {
        'bar' => AssistantChartType.bar,
        'line' => AssistantChartType.line,
        _ => null,
      };
      final title = decoded['title'];
      final unit = decoded['unit'] ?? '';
      final rawPoints = decoded['data'];
      if (type == null ||
          title is! String ||
          title.trim().isEmpty ||
          title.length > 80 ||
          unit is! String ||
          unit.length > 16 ||
          rawPoints is! List ||
          rawPoints.length < (type == AssistantChartType.line ? 2 : 1) ||
          rawPoints.length > 12) {
        return null;
      }
      final points = <AssistantChartPoint>[];
      for (final item in rawPoints) {
        if (item is! Map<String, dynamic>) return null;
        final label = item['label'];
        final value = item['value'];
        if (label is! String ||
            label.trim().isEmpty ||
            label.length > 32 ||
            value is! num ||
            !value.isFinite ||
            value < -1000000000 ||
            value > 1000000000) {
          return null;
        }
        points.add(AssistantChartPoint(label: label, value: value.toDouble()));
      }
      return AssistantChartData(
        type: type,
        title: title.trim(),
        unit: unit,
        points: List.unmodifiable(points),
      );
    } on FormatException {
      return null;
    }
  }
}

class _ChartFrame extends StatelessWidget {
  const _ChartFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppLayout.spaceMd),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppLayout.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppLayout.spaceSm),
          child,
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});

  final AssistantChartData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final minimum = data.points.fold<double>(
      0,
      (value, point) => math.min(value, point.value),
    );
    final maximum = data.points.fold<double>(
      0,
      (value, point) => math.max(value, point.value),
    );
    final range = maximum - minimum;
    return Column(
      children: [
        for (var index = 0; index < data.points.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index + 1 == data.points.length ? 0 : AppLayout.spaceSm,
            ),
            child: Semantics(
              label: _pointLabel(data.points[index], data.unit),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(
                      data.points[index].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: AppLayout.spaceSm),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final zero = range == 0 ? .5 : -minimum / range;
                        final value = range == 0
                            ? zero
                            : (data.points[index].value - minimum) / range;
                        final left = math.min(zero, value) * width;
                        final barWidth = math.max(
                          1.0,
                          (value - zero).abs() * width,
                        );
                        return SizedBox(
                          height: 18,
                          child: Stack(
                            children: [
                              Positioned(
                                left: zero * width,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 1,
                                  color: colors.outline,
                                ),
                              ),
                              Positioned(
                                left: left,
                                top: 2,
                                width: math.min(barWidth, width - left),
                                height: 14,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: data.points[index].value < 0
                                        ? colors.tertiary
                                        : colors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppLayout.spaceSm),
                  SizedBox(
                    width: 64,
                    child: Text(
                      _formatValue(data.points[index].value, data.unit),
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.data});

  final AssistantChartData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 156,
          child: CustomPaint(
            painter: _LineChartPainter(
              points: data.points,
              lineColor: colors.primary,
              gridColor: colors.outlineVariant,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: AppLayout.spaceXs),
        Wrap(
          spacing: AppLayout.spaceMd,
          runSpacing: AppLayout.spaceXs,
          children: [
            for (final point in data.points)
              Semantics(
                label: _pointLabel(point, data.unit),
                child: Text(
                  '${point.label}: ${_formatValue(point.value, data.unit)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
  });

  final List<AssistantChartPoint> points;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final chart = Rect.fromLTWH(
      inset,
      inset,
      math.max(0, size.width - inset * 2),
      math.max(0, size.height - inset * 2),
    );
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = lineColor;
    for (var row = 0; row < 4; row++) {
      final y = chart.top + chart.height * row / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    final minimum = points.fold<double>(
      0,
      (value, point) => math.min(value, point.value),
    );
    final maximum = points.fold<double>(
      0,
      (value, point) => math.max(value, point.value),
    );
    final range = maximum - minimum;
    final path = Path();
    final coordinates = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = chart.left + chart.width * index / (points.length - 1);
      final ratio = range == 0 ? .5 : (points[index].value - minimum) / range;
      final y = chart.bottom - chart.height * ratio;
      final point = Offset(x, y);
      coordinates.add(point);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
    for (final point in coordinates) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}

String _pointLabel(AssistantChartPoint point, String unit) =>
    '${point.label}: ${_formatValue(point.value, unit)}';

String _formatValue(double value, String unit) {
  final formattedValue = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  return unit.isEmpty ? formattedValue : '$formattedValue $unit';
}
