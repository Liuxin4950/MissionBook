import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../application/missions/mission_service.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission_schedule_revision.dart';

/// 一个任务的只读详情。由今天页传入任务编号和应用共享的查询入口。
/// 本轮只接通阅读、重试与返回；开始、编辑、改期和取消由后续单元接入。
class MissionDetailPage extends StatefulWidget {
  const MissionDetailPage({
    super.key,
    required this.missionId,
    required this.missionService,
  });

  final String missionId;
  final MissionService missionService;

  @override
  State<MissionDetailPage> createState() => _MissionDetailPageState();
}

class _MissionDetailPageState extends State<MissionDetailPage> {
  // Future 是“这一次读取的结果”，不是数据库连接；可能得到详情、null 或错误。
  late Future<MissionDetail?> _detail;

  @override
  void initState() {
    super.initState();
    _detail = _readDetail();
  }

  Future<MissionDetail?> _readDetail() {
    // widget 指向与此 State 配对的 MissionDetailPage，两个参数由今天页提供。
    return widget.missionService.findDetail(missionId: widget.missionId);
  }

  @override
  void didUpdateWidget(covariant MissionDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 若父级让同一个页面改读另一个任务，就替换 Future。
    // Flutter 随后会再次 build；FutureBuilder 也会忽略上一次尚未返回的结果。
    if (oldWidget.missionId != widget.missionId ||
        oldWidget.missionService != widget.missionService) {
      _detail = _readDetail();
    }
  }

  void _retry() {
    setState(() {
      // 只有明确点击重试时才新建读取；普通 build 始终使用原来的 Future。
      _detail = _readDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('任务详情')),
      // 详情是独立阅读页，有自己的返回按钮，不复制 AppShell 的底部导航。
      body: SafeArea(
        top: false,
        child: FutureBuilder<MissionDetail?>(
          future: _detail,
          builder: (context, snapshot) {
            // FutureBuilder 监听 _detail，读取完成后由框架重新调用这里。
            // 等待时不显示上一次结果，避免重试或换任务时短暂展示旧数据。
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(semanticsLabel: '正在读取任务详情'),
              );
            }
            if (snapshot.hasError) {
              return _DetailMessage(message: '任务详情读取失败，请重试', onRetry: _retry);
            }
            final detail = snapshot.data;
            if (detail == null) {
              return const _DetailMessage(message: '未找到这个任务，请返回列表刷新');
            }
            return _MissionDetailContent(detail: detail);
          },
        ),
      ),
    );
  }
}

// 加载失败与“没有这个编号”是两种结果；只有读取失败提供重试按钮。
class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(liveRegion: true, child: Text(message)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('重新读取')),
          ],
        ),
      ),
    );
  }
}

// 布局只读取业务对象；不保存页面自己的“阶段”，也不接触 Drift 行类型。
class _MissionDetailContent extends StatelessWidget {
  const _MissionDetailContent({required this.detail});

  final MissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mission = detail.mission;
    final schedule = detail.schedule;
    final plan = detail.executionPlan;
    final cancelledAt = mission.cancelledAt;
    final deadline = schedule.evidenceDeadlineAt;

    // 当前三表切片尚无 START 事件：未取消任务均未开始。
    // 接入执行事件后，此处需要读取统一阶段推导，不能继续只靠 cancelledAt 判断。
    final status = cancelledAt == null ? '待开始' : '已取消';
    final policyLabel = switch (mission.verificationPolicy) {
      VerificationPolicy.selfReport => '用户自报',
      VerificationPolicy.optionalEvidence => '报告完成后可选择补交材料',
      VerificationPolicy.requiredEvidence => '报告完成后必须提交材料',
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 792),
        child: SelectionArea(
          child: ListView(
            key: const Key('mission-detail-list'),
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 360 ? 16 : 24,
            ),
            children: [
              Semantics(
                header: true,
                // 列表标题可省略，详情展示完整文字，允许按可用宽度自然换行。
                child: Text(
                  mission.title,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              Text('临时任务 · $status', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              _ScheduleCard(schedule: schedule),
              const SizedBox(height: 24),
              if (_hasText(mission.description))
                _DetailSection(
                  title: '任务说明',
                  child: Text(mission.description!),
                ),
              if (_hasText(mission.why))
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text('为什么现在做', style: theme.textTheme.titleLarge),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(mission.why!),
                      ),
                    ],
                  ),
                ),
              _DetailSection(title: '具体目标', child: Text(plan.objective)),
              // steps 的顺序由数据库 JSON 恢复；前面的数字只是步骤序号，不是完成标记。
              if (plan.steps.isNotEmpty)
                _DetailSection(
                  title: '行动步骤',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < plan.steps.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('${index + 1}. ${plan.steps[index]}'),
                        ),
                    ],
                  ),
                ),
              _DetailSection(title: '材料要求', child: Text(policyLabel)),
              if (_hasText(plan.verificationCriteria))
                _DetailSection(
                  title: '验收方向',
                  child: Text(plan.verificationCriteria!),
                ),
              if (mission.verificationPolicy ==
                      VerificationPolicy.requiredEvidence &&
                  deadline != null)
                _DetailSection(
                  title: '材料截止',
                  child: Text(_localTimeLabel(deadline, schedule.timeZone)),
                ),
              if (_hasText(plan.notes))
                _DetailSection(title: '补充说明', child: Text(plan.notes!)),
              if (cancelledAt != null)
                _DetailSection(
                  title: '取消时间',
                  child: Text(_localTimeLabel(cancelledAt, schedule.timeZone)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 这些小组件和显示函数仅服务于此页，留在本文件，避免为每个区域拆一个文件。
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
                style: theme.textTheme.titleMedium?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// 空白可选文字也不显示空标题；! 的使用位置均已由此判断检查过非空。
bool _hasText(String? text) => text != null && text.trim().isNotEmpty;

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

String _localTimeLabel(DateTime instant, String timeZone) {
  // instant 是数据库还原的 UTC 时刻；使用记录的时区，不用设备的 toLocal()。
  final local = tz.TZDateTime.from(instant, tz.getLocation(timeZone));
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
