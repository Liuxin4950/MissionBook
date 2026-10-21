import 'package:flutter/material.dart';

import 'mission_details.dart';
import 'today_display.dart';

// 固定任务区域。列表已经分组、排好序；这里只安排时间、连线和任务文字。
class FixedMissionSection extends StatelessWidget {
  const FixedMissionSection({super.key, required this.items});

  final List<TodayMissionItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '计划日程',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              // 全部任务的范围尚未确定：保留禁用入口，暂不绑定跳转。
              TextButton.icon(
                key: const Key('today-all-missions'),
                onPressed: null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                label: const Text('全部任务'),
                icon: const Icon(Icons.north_east, size: 16),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < items.length; index++)
            buildFixedMissionRow(
              context,
              items[index],
              connectPrevious: index > 0,
              connectNext: index < items.length - 1,
            ),
        ],
      ),
    );
  }
}

// 取消折叠区也使用固定行，但关闭时间轴；不再混入自选任务的另一套布局。
Widget buildFixedMissionRow(
  BuildContext context,
  TodayMissionItem item, {
  bool showTimeline = true,
  bool connectPrevious = false,
  bool connectNext = false,
}) {
  final theme = Theme.of(context);
  // 这些计算属于布局：让节点对齐标题首行，随主题字号及系统文字缩放移动。
  final titleStyle = theme.textTheme.titleMedium!;
  final timeStyle = theme.textTheme.bodyMedium!;
  final scaler = MediaQuery.textScalerOf(context);
  final titleLineHeight =
      scaler.scale(titleStyle.fontSize!) * titleStyle.height!;
  final timeLineHeight = scaler.scale(timeStyle.fontSize!) * timeStyle.height!;
  final timeTop = (titleLineHeight - timeLineHeight) / 2;
  return Stack(
    key: ValueKey('mission-${item.id}'),
    children: [
      if (showTimeline)
        Positioned(
          left: 56,
          width: 16,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey('timeline-rail-${item.id}'),
              painter: _TimelinePainter(
                connectPrevious: connectPrevious,
                connectNext: connectNext,
                nodeY: titleLineHeight / 2,
                lineColor: theme.colorScheme.outlineVariant,
                nodeColor: theme.colorScheme.onSurfaceVariant,
                background: theme.scaffoldBackgroundColor,
              ),
            ),
          ),
        ),
      // 文字撑开 Stack，竖线包含行间距；长标题换行也不会截断相邻行连线。
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Padding(
                padding: EdgeInsets.only(top: timeTop > 0 ? timeTop : 0),
                child: Text(
                  item.startTime,
                  style: timeStyle.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 36),
            Expanded(child: buildMissionDetails(context, item)),
          ],
        ),
      ),
    ],
  );
}

// 时间轴是区域内部的绘制细节，不表示任务已开始或已完成。
class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.connectPrevious,
    required this.connectNext,
    required this.nodeY,
    required this.lineColor,
    required this.nodeColor,
    required this.background,
  });

  final bool connectPrevious;
  final bool connectNext;
  final double nodeY;
  final Color lineColor;
  final Color nodeColor;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, nodeY);
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, connectPrevious ? 0 : nodeY),
      Offset(center.dx, connectNext ? size.height : nodeY),
      line,
    );
    canvas.drawCircle(center, 4.5, Paint()..color = background);
    canvas.drawCircle(
      center,
      4.5,
      Paint()
        ..color = nodeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      connectPrevious != oldDelegate.connectPrevious ||
      connectNext != oldDelegate.connectNext ||
      nodeY != oldDelegate.nodeY ||
      lineColor != oldDelegate.lineColor ||
      nodeColor != oldDelegate.nodeColor ||
      background != oldDelegate.background;
}
