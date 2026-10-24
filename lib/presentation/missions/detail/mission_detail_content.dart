import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/mission.dart';
import '../../../domain/entities/mission_detail.dart';
import '../shared/mission_execution_display.dart';
import '../../../domain/entities/mission_schedule_revision.dart';

/// 详情正文和底部操作布局；只展示页面传入的事实与操作反馈。
class MissionDetailContent extends StatelessWidget {
  const MissionDetailContent({
    super.key,
    required this.detail, // 页面查询得到的完整任务详情。
    required this.actionFeedback, // 页面准备好的执行反馈区域。
    required this.footer, // 页面决定当前允许显示哪些操作。
    required this.isCancelling, // 取消期间显示等待提示。
    this.cancelError, // 页面取消失败后的提示文字。
  });

  final MissionDetail detail;
  final Widget actionFeedback;
  final Widget? footer;
  final bool isCancelling;
  final String? cancelError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mission = detail.mission;
    final plan = detail.executionPlan;
    final cancelledAt = mission.cancelledAt;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
        child: SelectionArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: const Key('mission-detail-list'),
                  padding: AppLayout.pagePadding(context),
                  children: [
                    // 当前任务没有目标路径字段，真实展示临时任务，不复制原型样例归属。
                    Text(
                      '临时任务',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MissionHeading(detail: detail),
                    const SizedBox(height: AppLayout.sectionGap),
                    _ScheduleCard(schedule: detail.schedule),
                    const SizedBox(height: AppLayout.sectionGap),
                    if (cancelledAt != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppLayout.sectionGap,
                        ),
                        child: Text(
                          '没有执行记录',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    // 这里只展示动作提交反馈；计时、报告和结果由各自页面承担。
                    actionFeedback,
                    if (isCancelling)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text('正在取消…'),
                      ),
                    if (cancelError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            cancelError!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    if (_hasText(mission.description))
                      _DetailSection(
                        title: '任务说明',
                        child: Text(mission.description!),
                      ),
                    if (_hasText(mission.why)) ...[
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 20),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        shape: const Border(
                          bottom: BorderSide(color: AppColors.hairline),
                        ),
                        collapsedShape: const Border(
                          bottom: BorderSide(color: AppColors.hairline),
                        ),
                        title: Text('为什么做', style: theme.textTheme.titleMedium),
                        children: [
                          Text(mission.why!, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: AppLayout.sectionGap),
                    ],
                    _DetailSection(
                      title: '行动方案',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            plan.objective,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (plan.steps.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            for (
                              var index = 0;
                              index < plan.steps.length;
                              index++
                            )
                              _ActionStep(
                                number: index + 1,
                                text: plan.steps[index],
                                last: index == plan.steps.length - 1,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.hairline),
                    const SizedBox(height: 16),
                    if (mission.verificationPolicy !=
                            VerificationPolicy.selfReport ||
                        _hasText(plan.verificationCriteria))
                      _MaterialRequirementsCard(detail: detail),
                    if (_hasText(plan.notes)) ...[
                      const SizedBox(height: AppLayout.sectionGap),
                      _DetailSection(title: '补充说明', child: Text(plan.notes!)),
                    ],
                    if (cancelledAt != null) ...[
                      const SizedBox(height: AppLayout.sectionGap),
                      _DetailSection(
                        title: '取消时间',
                        child: Text(
                          _localTimeLabel(
                            cancelledAt,
                            detail.schedule.timeZone,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 主按钮在滚动区外，始终可见；窄屏和系统字体放大时按内容增高。
              if (footer != null)
                SafeArea(
                  top: false,
                  minimum: EdgeInsets.fromLTRB(
                    AppLayout.horizontalPadding(context),
                    8,
                    AppLayout.horizontalPadding(context),
                    16,
                  ),
                  child: SizedBox(width: double.infinity, child: footer),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 步骤圆点和连线只表达顺序，不能解释为已完成状态。
class _ActionStep extends StatelessWidget {
  const _ActionStep({
    required this.number,
    required this.text,
    required this.last,
  });
  final int number;
  final String text;
  final bool last;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (!last)
                Expanded(child: Container(width: 1, color: AppColors.hairline)),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 24),
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ],
    ),
  );
}

class _MaterialRequirementsCard extends StatelessWidget {
  const _MaterialRequirementsCard({required this.detail});
  final MissionDetail detail;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policy = detail.mission.verificationPolicy;
    final label = switch (policy) {
      VerificationPolicy.selfReport => '用户自报',
      VerificationPolicy.optionalEvidence => '报告完成后可选',
      VerificationPolicy.requiredEvidence => '报告完成后必交',
    };
    final criteria = detail.executionPlan.verificationCriteria;
    final deadline = detail.schedule.evidenceDeadlineAt;
    return Container(
      key: const Key('mission-material-card'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Icon(
              Icons.attach_file_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              initiallyExpanded: true,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('材料要求', style: theme.textTheme.titleMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                if (_hasText(criteria))
                  Text(
                    criteria!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else if (policy == VerificationPolicy.selfReport)
                  Text(
                    '报告完成即可结束，无需提交材料',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (policy == VerificationPolicy.requiredEvidence &&
                    deadline != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: AppColors.hairline),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      Text(
                        '截止',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _localTimeLabel(deadline, detail.schedule.timeZone),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodyMedium,
            child: child,
          ),
        ],
      ),
    );
  }
}

// 空白可选文字也不显示空标题；! 的使用位置均已由此判断检查过非空。
bool _hasText(String? text) => text != null && text.trim().isNotEmpty;

String _localTimeLabel(DateTime instant, String timeZone) {
  // instant 是数据库还原的 UTC 时刻；使用记录的时区，不用设备的 toLocal()。
  final local = tz.TZDateTime.from(instant, tz.getLocation(timeZone));
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

/// 展示排期日期、固定时刻和计划时长；只读数据，不发起查询。
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule});

  final MissionScheduleRevision schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = _ScheduleFact(
      icon: Icons.calendar_today_outlined,
      label: schedule.timePolicy == TimePolicy.fixed ? '固定时间' : '自选时间',
      value: _scheduleTimeLabel(schedule),
    );
    final duration = _ScheduleFact(
      icon: Icons.access_time,
      label: '计划',
      value: '${schedule.plannedDurationMinutes} 分',
    );

    return Container(
      key: const Key('mission-schedule-card'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // constraints 是卡内可用宽度；系统放大文字后也需要更多横向空间。
          // 普通手机左右并排，窄屏/大字体才上下排列，不压缩字号或截掉时间。
          final textScale = MediaQuery.textScalerOf(context).scale(18) / 18;
          final stacked = constraints.maxWidth < 280 * textScale;
          final divider = ColoredBox(
            color: theme.colorScheme.onSecondaryContainer.withValues(
              alpha: 0.2,
            ),
            child: SizedBox(width: stacked ? double.infinity : 1, height: 1),
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                time,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: divider,
                ),
                duration,
              ],
            );
          }

          // IntrinsicHeight 让分隔线跟随实际文字高度，卡片不设置固定高度。
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: time),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: divider,
                ),
                Expanded(child: duration),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 每栏接收上面根据真实排期准备的图标、标签与数值，统一文字层级。
class _ScheduleFact extends StatelessWidget {
  const _ScheduleFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSecondaryContainer;
    return Row(
      children: [
        // 图标是文字的视觉提示，不单独重复朗读。
        ExcludeSemantics(child: Icon(icon, size: 24, color: foreground)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _scheduleTimeLabel(MissionScheduleRevision schedule) {
  final fixedStartAt = schedule.fixedStartAt;
  if (schedule.timePolicy == TimePolicy.fixed && fixedStartAt != null) {
    // 固定时刻先转成记录的时区，再取月日和时分，不能使用设备本地时间。
    final local = tz.TZDateTime.from(
      fixedStartAt,
      tz.getLocation(schedule.timeZone),
    );
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}月${local.day}日 $hour:$minute';
  }
  // 自选日期是经过业务入口校验的 YYYY-MM-DD 日历值，不转换时区。
  final parts = schedule.scheduledDate.split('-');
  return '${int.parse(parts[1])}月${int.parse(parts[2])}日';
}
