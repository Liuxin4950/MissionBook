import 'package:flutter/material.dart';

import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/failure_record.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/rules/execution_time_rules.dart';
import '../../widgets/app_top_bar.dart';
import '../shared/mission_execution_display.dart';
import '../shared/mission_retry_button.dart';
import '../detail/mission_detail_page.dart';
import '../evidence/mission_evidence_section.dart';

/// 已结束的只读记录。使用 END 冻结的时长，绝不显示运行圆环或执行控制。
class MissionRecordPage extends StatefulWidget {
  const MissionRecordPage({
    super.key,
    required this.detail,
    required this.service,
  }) : _returnToTaskDetail = false;

  /// 下层已经是该任务详情，顶栏“任务详情”直接返回，避免再堆叠一份相同详情。
  const MissionRecordPage.fromTaskDetail({
    super.key,
    required this.detail,
    required this.service,
  }) : _returnToTaskDetail = true;
  final MissionDetail detail;
  final MissionService service;
  final bool _returnToTaskDetail;

  @override
  State<MissionRecordPage> createState() => _MissionRecordPageState();
}

class _MissionRecordPageState extends State<MissionRecordPage> {
  MissionDetail get detail => widget.detail;
  MissionService get service => widget.service;
  bool _openingDetails = false;

  Future<void> _viewDetails() async {
    if (_openingDetails) return;
    setState(() => _openingDetails = true);
    if (widget._returnToTaskDetail) {
      Navigator.of(context).pop();
      return;
    }
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MissionDetailPage.fromRecord(
            missionId: detail.mission.id,
            missionService: service,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingDetails = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final times = calculateExecutionTimes(
      detail.events,
      detail.events.last.occurredAt,
    );
    final completed =
        detail.events.last.userReportedResult == UserReportedResult.completed;
    return Scaffold(
      key: const Key('mission-record-page'),
      appBar: AppTopBar(
        title: '执行记录',
        actions: [
          IconButton(
            onPressed: _openingDetails ? null : _viewDetails,
            tooltip: '任务详情',
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: MissionPageBody(
        listKey: const Key('mission-record-list'),
        footer: MissionRetryButton(source: detail, service: service),
        children: [
          MissionHeading(detail: detail, showPhase: false),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const Key('execution-result'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                completed ? '用户报告：已完成' : '用户报告：未完成',
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          Container(
            key: const Key('execution-summary'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('专注时长'),
                          Text(
                            focusDuration(times.focus),
                            style: theme.textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _SummaryValue(
                      label: '原计划',
                      value: '${detail.schedule.plannedDurationMinutes} 分',
                    ),
                    _SummaryValue(
                      label: '增加额度',
                      value: '${times.extensionMinutes} 分',
                    ),
                    _SummaryValue(label: '暂停', value: '${times.pauseCount} 次'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text('总经过 ${executionDuration(times.elapsed)}'),
              Text('暂停时长 ${executionDuration(times.paused)}'),
              if (times.focus >
                  Duration(minutes: detail.schedule.plannedDurationMinutes))
                Text(
                  '实际超时 ${executionDuration(times.focus - Duration(minutes: detail.schedule.plannedDurationMinutes))}',
                ),
            ],
          ),
          for (final failure in detail.failures)
            if (failure.userReasonCategory != null ||
                failure.userReasonText?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppLayout.sectionGap),
              Text('未完成原因', style: theme.textTheme.titleMedium),
              if (failure.userReasonCategory != null)
                Text(failureReasonLabels[failure.userReasonCategory]!),
              if (failure.userReasonText?.trim().isNotEmpty == true)
                Text(failure.userReasonText!),
            ],
          const SizedBox(height: AppLayout.sectionGap),
          MissionEvidenceSection(
            key: ValueKey('record-evidence-${detail.mission.id}'),
            detail: detail,
            service: service,
          ),
          const SizedBox(height: AppLayout.sectionGap),
          MissionEventTimeline(detail: detail),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
