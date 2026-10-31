import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../widgets/page_footer_bar.dart';
import 'mission_action_controller.dart';
import 'mission_phase_display.dart';

String executionDuration(Duration duration) {
  final seconds = math.max(0, duration.inSeconds);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
}

/// 一小时内用 分:秒，超过一小时保留小时；计时值来自事实，不按重绘次数累加。
String focusDuration(Duration duration) => duration.inHours > 0
    ? executionDuration(duration)
    : executionDuration(duration).substring(3);

String missionLocalTime(
  DateTime time,
  String timeZone, {
  bool includeDate = true,
}) {
  final local = tz.TZDateTime.from(time, tz.getLocation(timeZone));
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  return includeDate
      ? '${local.year}年${local.month}月${local.day}日 $clock'
      : clock;
}

/// 三页共用任务身份的字号与真实阶段。没有目标归属就不伪造面包屑。
class MissionHeading extends StatelessWidget {
  const MissionHeading({
    super.key,
    required this.detail,
    this.showPhase = true,
  });
  final MissionDetail detail;
  final bool showPhase;

  @override
  Widget build(BuildContext context) {
    final title = Semantics(
      header: true,
      child: Text(
        detail.mission.title,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
    final badge = Container(
      key: const Key('mission-phase'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceMd,
        vertical: AppLayout.spaceSm,
      ),
      decoration: BoxDecoration(
        color: detail.phase == MissionPhase.running
            ? AppColors.accent
            : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
      ),
      child: Text(
        phaseLabel(detail.phase, schedule: detail.schedule),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
    final heading = LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        if (!showPhase) return title;
        if (box.maxWidth < 300 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: AppLayout.spaceMd),
              badge,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: AppLayout.spaceLg),
            badge,
          ],
        );
      },
    );
    if (detail.ownershipInfo == null) return heading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          detail.ownershipInfo!.label,
          key: const Key('mission-ownership-path'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppLayout.spaceSm),
        heading,
      ],
    );
  }
}

/// 正文滚动、操作固定在安全区域内；键盘和大字体下正文仍可到达。
class MissionPageBody extends StatelessWidget {
  const MissionPageBody({
    super.key,
    required this.children,
    this.footer,
    this.listKey,
  });
  final List<Widget> children;
  final Widget? footer;
  final Key? listKey;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: LayoutBuilder(
            builder: (context, available) => Column(
              children: [
                Expanded(
                  child: ListView(
                    key: listKey,
                    padding: AppLayout.pagePadding(context),
                    children: children,
                  ),
                ),
                if (footer != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: available.maxHeight * .5,
                    ),
                    child: SingleChildScrollView(
                      child: PageFooterBar(child: footer!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MissionActionFeedback extends StatelessWidget {
  const MissionActionFeedback({
    super.key,
    required this.controller,
    required this.onRetry,
    required this.onRefresh,
    this.onPauseOther,
  });
  final MissionActionController controller;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;
  final VoidCallback? onPauseOther;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (controller.error != null) ...[
        const SizedBox(height: AppLayout.spaceLg),
        Semantics(
          liveRegion: true,
          child: Text(
            controller.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        Wrap(
          spacing: AppLayout.spaceSm,
          runSpacing: AppLayout.spaceSm,
          children: [
            if (controller.pending != null)
              FilledButton(
                key: const Key('execution-retry'),
                onPressed: controller.busy ? null : onRetry,
                child: const Text('重试原操作'),
              ),
            TextButton(
              onPressed: controller.busy ? null : onRefresh,
              child: const Text('刷新状态（保留输入）'),
            ),
          ],
        ),
      ],
      if (controller.conflict != null) ...[
        Text('正在执行：${controller.conflict!.mission.title}'),
        OutlinedButton(
          onPressed: controller.busy ? null : onPauseOther,
          child: const Text('先暂停此任务'),
        ),
      ],
      if (controller.busy)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppLayout.spaceSm),
          child: Text('正在保存，请稍候…'),
        ),
    ],
  );
}

/// 事件明细仅展示已保存的事实，时间按任务排期时区显示，包含跨日日期。
class MissionEventTimeline extends StatelessWidget {
  const MissionEventTimeline({super.key, required this.detail});
  final MissionDetail detail;
  @override
  Widget build(BuildContext context) => Column(
    key: const Key('execution-events'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('本次时间线', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppLayout.spaceLg),
      for (final event in detail.events)
        Padding(
          padding: const EdgeInsets.only(bottom: AppLayout.spaceLg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(switch (event.type) {
                ExecutionEventType.start => Icons.play_circle_outline,
                ExecutionEventType.pause => Icons.pause_circle_outline,
                ExecutionEventType.resume => Icons.play_circle_outline,
                ExecutionEventType.extend => Icons.more_time,
                ExecutionEventType.end => Icons.stop_circle_outlined,
                ExecutionEventType.stop => Icons.timer_off_outlined,
              }, color: AppColors.primary),
              const SizedBox(width: AppLayout.spaceLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(switch (event.type) {
                      ExecutionEventType.start => '开始执行',
                      ExecutionEventType.pause => '暂停执行',
                      ExecutionEventType.stop => '到点停止计时',
                      ExecutionEventType.resume => '继续执行',
                      ExecutionEventType.extend =>
                        '增加 ${event.grantedDurationMinutes} 分钟',
                      ExecutionEventType.end =>
                        event.isRetrospective
                            ? '补记已完成'
                            : detail.events.any(
                                (e) => e.type == ExecutionEventType.stop,
                              )
                            ? '确认完成情况'
                            : '结束执行',
                    }, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      missionLocalTime(
                        event.occurredAt,
                        detail.schedule.timeZone,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (event.reason?.trim().isNotEmpty == true)
                      Text(event.reason!),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
