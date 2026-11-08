import '../../../core/theme/app_motion.dart';
import '../../../domain/entities/analysis_scope.dart';
import '../../../domain/entities/execution_event.dart';
import '../../records/analysis/analysis_panel.dart';
import '../execution/execution_report_button.dart';
import '../../records/shared/record_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_expansion.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/failure_record.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/rules/execution_time_rules.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_visibility.dart';
import '../shared/mission_execution_display.dart';
import '../shared/mission_retry_button.dart';
import '../detail/mission_detail_page.dart';
import '../evidence/mission_evidence_section.dart';

/// 执行事实只读，时长按 END 冻结；材料区继续按事实提供提交与修正操作。
class MissionRecordWorkspace extends StatefulWidget {
  const MissionRecordWorkspace({
    super.key,
    required this.detail,
    required this.service,
  }) : _returnToTaskDetail = false;

  /// 下层已经是该任务详情，顶栏“任务详情”直接返回，避免再堆叠一份相同详情。
  const MissionRecordWorkspace.fromTaskDetail({
    super.key,
    required this.detail,
    required this.service,
  }) : _returnToTaskDetail = true;
  final MissionDetail detail;
  final MissionService service;
  final bool _returnToTaskDetail;

  @override
  State<MissionRecordWorkspace> createState() => _MissionRecordWorkspaceState();
}

class _MissionRecordWorkspaceState extends State<MissionRecordWorkspace>
    with WidgetsBindingObserver {
  // 页面打开后事实仍可能变化（例如别的入口补记了材料超时）。
  // 与今天/历史/详情页一致：订阅服务通知并重读详情，不长期保留过期快照。
  late MissionDetail _detail;
  StreamSubscription<void>? _changes;
  Timer? _deadlineTimer;
  bool _appVisible = true;
  bool _tickerEnabled = true;
  bool _refreshing = false;
  bool _refreshAgain = false;
  String? _refreshError;
  bool _openingDetails = false;

  MissionDetail get detail => _detail;
  MissionService get service => widget.service;

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
    WidgetsBinding.instance.addObserver(this);
    _appVisible = isAppVisible(WidgetsBinding.instance.lifecycleState);
    // (_) 忽略没有业务数据的通知；它只表示“事实有变化，请重读”。
    _changes = widget.service.changes.listen((_) => _refresh());
    unawaited(_refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _configureDeadlineTimer();
  }

  void _configureDeadlineTimer() {
    final waiting =
        detail.phase == MissionPhase.evidencePending &&
        detail.mission.verificationPolicy ==
            VerificationPolicy.requiredEvidence;
    if (!_appVisible || !_tickerEnabled || !waiting) {
      _deadlineTimer?.cancel();
      _deadlineTimer = null;
    } else {
      // 截止自然到达时没有提交通知；可见记录页主动走服务补算，不自行改阶段。
      _deadlineTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(_refresh());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = isAppVisible(state);
    _configureDeadlineTimer();
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _deadlineTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    if (_refreshing) {
      // 查询期间到来的通知合并为下一次读取，避免旧查询覆盖较新的事实。
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        try {
          final latest = await service.findDetailAndReconcile(
            missionId: detail.mission.id,
          );
          if (!mounted) return;
          if (latest == null) throw StateError('任务不存在');
          setState(() {
            _detail = latest;
            _refreshError = null;
          });
        } catch (_) {
          if (!mounted) return;
          // 保留可读快照和材料组件，明确提示读取失败并提供重试。
          setState(() => _refreshError = '记录刷新失败，当前显示上次读取的内容');
        }
        _configureDeadlineTimer();
      } while (mounted && _refreshAgain);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _viewDetails() async {
    if (_openingDetails) return;
    setState(() => _openingDetails = true);
    if (widget._returnToTaskDetail) {
      Navigator.of(context).pop();
      return;
    }
    try {
      await openDetailPane<void>(
        context,
        label: '任务详情',
        builder: (_) => MissionDetailPage.fromRecord(
          missionId: detail.mission.id,
          missionService: service,
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
      schedule: detail.schedule,
    );
    // “用户报告：已完成”只看 END 的自报结果；判定口径统一走 MissionDetail。
    final completed = detail.endReportedCompleted;
    // 实际超时 = max(Focus − 原计划, 0)，由领域时间规则统一计算，页面只展示。
    final overtime = actualOvertime(
      times,
      detail.schedule.plannedDurationMinutes,
    );
    return Scaffold(
      key: const Key('mission-record-page'),
      appBar: AppTopBar(
        title: '执行记录',
        actions: [
          PopupMenuButton<String>(
            popUpAnimationStyle: AppMotion.overlayStyle(context),
            key: const Key('record-more'),
            tooltip: '记录更多操作',
            icon: const Icon(Icons.more_horiz, size: AppLayout.iconLg),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'time', child: Text('更正实际日期 / 时段')),
              if (RecordScope.maybeOf(context) != null)
                const PopupMenuItem(value: 'analysis', child: Text('任务评价')),
            ],
            onSelected: (action) {
              if (action == 'time') {
                unawaited(showExecutionReportSheet(context, detail, service));
              } else {
                unawaited(
                  showAnalysisSummary(
                    context,
                    scope: AnalysisScope.mission,
                    id: detail.mission.id,
                    title: detail.mission.title,
                  ),
                );
              }
            },
          ),
          IconButton(
            onPressed: _openingDetails ? null : _viewDetails,
            tooltip: '任务详情',
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: MissionPageBody(
        listKey: const Key('mission-record-list'),
        children: [
          if (_refreshError != null)
            OutlinedButton.icon(
              key: const Key('record-refresh-retry'),
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: Text('$_refreshError，点击重试'),
            ),
          MissionHeading(detail: detail, showPhase: false),
          const SizedBox(height: AppLayout.spaceXl),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const Key('execution-result'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppLayout.spaceMd,
                vertical: AppLayout.spaceSm,
              ),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
              ),
              child: Text(
                completed ? '用户报告：已完成' : '用户报告：未完成',
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          AppSectionCard(
            key: const Key('execution-summary'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (detail.effectiveUserReport case final report?) ...[
                  Text('实际发生', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppLayout.spaceSm),
                  Text(
                    report.occurrenceDate,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppLayout.spaceSm),
                  Text(
                    report.actualStart == null
                        ? '具体时段未记录'
                        : '${missionLocalTime(report.actualStart!, report.timeZoneId, includeDate: false)} – ${missionLocalTime(report.actualEnd!, report.timeZoneId, includeDate: false)}',
                  ),
                  if (detail.events.any(
                    (e) => e.type == ExecutionEventType.start,
                  ))
                    const SizedBox(height: AppLayout.spaceLg),
                ],
                if (detail.events.any(
                  (e) => e.type == ExecutionEventType.start,
                )) ...[
                  Text('应用计时', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppLayout.spaceSm),
                  Text(
                    focusDuration(times.focus),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppLayout.spaceSm),
                  AppExpansionTile(
                    title: const Text('计时明细'),
                    insetHeader: false,
                    children: [
                      Wrap(
                        spacing: AppLayout.spaceXl,
                        runSpacing: AppLayout.spaceMd,
                        children: [
                          _SummaryValue(
                            label: '原计划',
                            value:
                                '${detail.schedule.plannedDurationMinutes} 分',
                          ),
                          if (times.extensionMinutes > 0)
                            _SummaryValue(
                              label: '增加额度',
                              value: '${times.extensionMinutes} 分',
                            ),
                          if (times.pauseCount > 0)
                            _SummaryValue(
                              label: '暂停',
                              value: '${times.pauseCount} 次',
                            ),
                          _SummaryValue(
                            label: '总经过',
                            value: executionDuration(times.elapsed),
                          ),
                          if (times.paused > Duration.zero)
                            _SummaryValue(
                              label: '暂停时长',
                              value: executionDuration(times.paused),
                            ),
                          if (overtime > Duration.zero)
                            _SummaryValue(
                              label: '实际超时',
                              value: executionDuration(overtime),
                            ),
                        ],
                      ),
                    ],
                  ),
                ] else
                  Text('本次为用户补记，无应用计时', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          for (final failure in detail.failures)
            if (failure.userReasonCategory != null ||
                failure.userReasonText?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppLayout.sectionGap),
              Text('未完成原因', style: theme.textTheme.titleMedium),
              if (failure.userReasonCategory != null)
                Text(
                  failureReasonLabels[failure.userReasonCategory] ??
                      failure.userReasonCategory!,
                ),
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
          const SizedBox(height: AppLayout.spaceLg),
          Align(
            alignment: Alignment.centerRight,
            child: MissionRetryButton(
              source: detail,
              service: service,
              secondary: true,
            ),
          ),
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
      const SizedBox(height: AppLayout.spaceXs),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
