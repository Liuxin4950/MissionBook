import '../../widgets/app_dropdown_form_field.dart';
import 'package:mission_book/presentation/missions/execution/execution_widgets.dart';
import 'dart:async';
import '../../assistant/assistant_launcher.dart';

import 'package:flutter/material.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/execution_command.dart';
import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/failure_record.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/rules/execution_time_rules.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_visibility.dart';
import '../../widgets/app_expansion.dart';
import '../shared/mission_action_controller.dart';
import '../shared/mission_execution_display.dart';
import '../record/mission_record_page.dart';
import '../detail/mission_detail_page.dart';
import '../evidence/mission_evidence_section.dart';

/// 已 START 任务的独立执行页；离开页面不会停止或暂停真实执行。
/// 结束报告与材料留在独立工作流中，旧自报独立页沿用原记录路由。
class MissionExecutionPage extends StatefulWidget {
  const MissionExecutionPage({
    super.key,
    required this.detail,
    required this.service,
    this.clock = DateTime.now,
    this.openEndConfirm = false,
  });
  final MissionDetail detail;
  final MissionService service;
  final DateTime Function() clock;

  // 通知「停止」动作直达：打开后直接呈现 END 确认区（§7.2 停止后的第二步）。
  final bool openEndConfirm;
  @override
  State<MissionExecutionPage> createState() => _MissionExecutionPageState();
}

// 状态类只被本页 createState 创建；没有 GlobalKey 跨组件调用，保持私有。
class _MissionExecutionPageState extends State<MissionExecutionPage>
    with WidgetsBindingObserver {
  late final MissionActionController _action;
  Timer? _timer;
  StreamSubscription<void>? _changes;
  bool _appVisible = true;
  bool _tickerEnabled = true;
  bool _report = false;
  bool _extend = false;
  bool _openingReport = false;
  bool _openingPauseDialog = false;
  bool _closingReport = false;
  bool _navigating = false;
  bool _showingDetails = false;
  int? _reportSequence;
  Duration? _reportFocus;
  int? _promptedBudget;
  UserReportedResult? _result;
  bool _submitOptionalEvidence = false;
  String? _reasonCategory;
  String? _inputError;
  final _minutes = TextEditingController(text: '10');
  final _failureReason = TextEditingController();
  final _evidenceKey = GlobalKey<MissionEvidenceSectionState>();

  @override
  void initState() {
    super.initState();
    _report =
        widget.openEndConfirm ||
        widget.detail.phase == MissionPhase.reportPending;
    _action = MissionActionController(
      detail: widget.detail,
      service: widget.service,
    );
    if (_report &&
        (_action.detail.phase == MissionPhase.paused ||
            _action.detail.phase == MissionPhase.reportPending)) {
      _reportSequence = _action.detail.lastSequence;
      _reportFocus = calculateExecutionTimes(
        _action.detail.events,
        widget.clock().toUtc(),
      ).focus;
    } else {
      _report = false;
    }
    _action.addListener(_changed);
    _changes = widget.service.changes.listen((_) {
      // 自己提交时由 _run 重读；其它入口的变更同步界面，但不替旧报告换序号。
      if (!_action.busy && _action.pending == null) {
        unawaited(_refresh(acceptReportSequence: false));
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _appVisible = isAppVisible(WidgetsBinding.instance.lifecycleState);
  }

  void _changed() {
    if (mounted) {
      _configureTimer(); // END 后停止无意义重绘，材料编辑不再每秒重建整块工作区。
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    DetailPaneScope.maybeOf(
      context,
    )?.registerTopGuard(_mayLeave, route: ModalRoute.of(context));
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _configureTimer();
  }

  void _configureTimer() {
    final phase = _action.detail.phase;
    if (!_appVisible || !_tickerEnabled || phase != MissionPhase.running) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    // 已有刷新器就沿用，避免频繁重读或依赖更新把下一秒不断推迟。
    // Timer 只要求重新绘制；Focus 始终从已保存时间线重新算，后台也不丢时长。
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_report) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasVisible = _appVisible;
    _appVisible = isAppVisible(state);
    _configureTimer();
    if (_appVisible) {
      // 从隐藏恢复成 inactive 时也先追上时钟，不依赖用户再点一下窗口。
      setState(() {});
      if ((!wasVisible || state == AppLifecycleState.resumed) &&
          _action.pending == null) {
        unawaited(_refresh());
      }
    }
  }

  Future<void> _requestPause() async {
    if (_openingPauseDialog ||
        !_action.canAct ||
        _action.detail.phase != MissionPhase.running) {
      return;
    }
    _openingPauseDialog = true;
    // 固定打开弹窗时的事实快照；其它入口变更后不能悄悄换成新序号提交。
    final detail = _action.detail;
    try {
      final reason = await ExecutionPauseDialog.show(context);
      if (!mounted || reason == null) return;
      await _run(
        widget.service.prepareExecution(
          detail: detail,
          type: ExecutionEventType.pause,
          reason: reason,
        ),
      );
    } finally {
      _openingPauseDialog = false;
    }
  }

  void _showRecord() {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (!mounted ||
        _navigating ||
        _action.detail.phase != MissionPhase.closed) {
      return;
    }
    _navigating = true;
    // 结束后本执行页就地变成记录工作区，返回不再回到执行视图。
    openDetailPane<void>(
      context,
      label: '执行记录',
      replace: DetailPaneReplace.top,
      builder: (_) =>
          MissionRecordPage(detail: _action.detail, service: widget.service),
    );
  }

  Future<void> _viewDetails() async {
    if (_showingDetails || _action.locked || _report) return;
    _showingDetails = true;
    try {
      await openDetailPane<void>(
        context,
        label: '任务详情',
        builder: (_) => MissionDetailPage.fromExecution(
          missionId: _action.detail.mission.id,
          missionService: widget.service,
        ),
      );
      if (mounted) await _refresh();
    } finally {
      _showingDetails = false;
    }
  }

  Future<void> _refresh({bool acceptReportSequence = false}) async {
    final ownPendingEnd = _action.pending?.type == ExecutionEventType.end
        ? _action.pending?.id
        : null;
    if (!await _action.refresh() || !mounted) return;
    if (_action.detail.phase == MissionPhase.reportPending) {
      // 自动停止只冻结计时；已有报告草稿保留，STOP 不改变用户的报告意图。
      _reportSequence = _action.detail.lastSequence;
      _reportFocus = calculateExecutionTimes(
        _action.detail.events,
        widget.clock().toUtc(),
      ).focus;
      _report = true;
      _extend = false;
      setState(() {});
      return;
    }
    if (_action.detail.phase == MissionPhase.closed &&
        _action.detail.mission.verificationPolicy ==
            VerificationPolicy.selfReport) {
      if (!_report || ownPendingEnd == _action.detail.events.last.id) {
        _showRecord();
      } else {
        _action.stale = true;
        _action.error = '执行记录已变化，任务已结束。本次输入已保留，可以放弃草稿后查看已保存记录。';
        setState(() {});
      }
    } else if (_report) {
      if (_action.detail.phase == MissionPhase.paused && acceptReportSequence) {
        _reportSequence = _action.detail.lastSequence;
        _reportFocus = calculateExecutionTimes(
          _action.detail.events,
          widget.clock().toUtc(),
        ).focus;
      } else if (_action.detail.lastSequence != _reportSequence) {
        // 报告草稿仍保留，但不能用旧报告结束已经恢复的任务。
        _action.stale = true;
        _action.error = _action.detail.phase == MissionPhase.running
            ? '执行记录已变化，任务已继续执行。请取消本次报告后按最新状态操作，输入已保留。'
            : '执行记录已变化。请取消本次报告后按最新状态操作，当前输入已保留。';
      }
      setState(() {});
    }
  }

  Future<void> _run(ExecutionCommand command, {bool openReport = false}) async {
    if (_action.busy) return;
    _openingReport = openReport;
    final succeeded = await _action.execute(command);
    if (!mounted) return;
    if (!succeeded) {
      if (_action.stale) {
        try {
          final latest = await widget.service.findDetailSnapshot(
            missionId: _action.detail.mission.id,
          );
          if (mounted && latest?.phase == MissionPhase.reportPending) {
            await _refresh();
          }
        } catch (_) {
          // 读取失败保留原冲突与输入，继续提供刷新入口。
        }
      }
      return;
    }
    _inputError = null;
    _extend = false;
    if (_action.detail.phase == MissionPhase.closed &&
        _action.detail.mission.verificationPolicy ==
            VerificationPolicy.selfReport) {
      _showRecord();
    } else if (_action.detail.events.last.type == ExecutionEventType.end) {
      // END 后在同一工作区接材料，不再多跳一页；计时已由 END 冻结。
      _report = false;
    } else if (openReport && _action.detail.phase == MissionPhase.paused) {
      _beginReport();
    }
    setState(() {});
  }

  void _beginReport() {
    setState(() {
      _report = true;
      _reportSequence = _action.detail.lastSequence;
      _reportFocus = calculateExecutionTimes(
        _action.detail.events,
        widget.clock().toUtc(),
      ).focus;
      _extend = false;
    });
  }

  Future<void> _openReport() async {
    if (!_action.canAct) return;
    if (_action.detail.phase == MissionPhase.running) {
      await _run(_action.prepare(ExecutionEventType.pause), openReport: true);
    } else {
      _beginReport();
    }
  }

  Future<void> _leaveReport() async {
    if (_action.locked || _closingReport) return;
    _closingReport = true;
    final hasDraft =
        _result != null ||
        _reasonCategory != null ||
        _failureReason.text.trim().isNotEmpty;
    final discard =
        !hasDraft ||
        await AppConfirmDialog.show(
          context: context,
          title: '放弃本次报告？',
          message: '仅放弃尚未保存的输入，不改变已保存的执行状态。',
          cancelText: '继续填写',
          confirmText: '放弃报告',
        );
    _closingReport = false;
    if (!mounted || !discard) return;
    setState(() {
      _report = false;
      _result = null;
      _reasonCategory = null;
      _failureReason.clear();
      _inputError = null;
    });
    // 外部恢复等冲突在离开草稿后再重读；取消报告本身绝不写 RESUME。
    if (_action.stale) await _refresh();
  }

  Future<bool> _mayLeave() async {
    if (_action.busy || _action.pending != null || _closingReport) return false;
    if (_action.detail.phase == MissionPhase.closed && !_action.stale) {
      return true;
    }
    if (!_report) return true;
    await _leaveReport();
    return mounted && !_report;
  }

  void _confirmReport() {
    if (!_action.canAct || _result == null || _reportSequence == null) return;
    final prepared = widget.service.prepareExecution(
      detail: _action.detail,
      type: ExecutionEventType.end,
      report: _result,
      submitOptionalEvidence:
          _result == UserReportedResult.completed &&
              _action.detail.mission.verificationPolicy ==
                  VerificationPolicy.optionalEvidence
          ? _submitOptionalEvidence
          : null,
      userReasonCategory: _result == UserReportedResult.notCompleted
          ? _reasonCategory
          : null,
      userReasonText: _result == UserReportedResult.notCompleted
          ? _failureReason.text
          : null,
    );
    // 固定为打开报告时看到的序号；其它入口恢复后，旧报告必须被仓储拒绝。
    unawaited(
      _run(
        ExecutionCommand(
          id: prepared.id,
          missionId: prepared.missionId,
          expectedSequence: _reportSequence!,
          type: prepared.type,
          userReportedResult: prepared.userReportedResult,
          submitOptionalEvidence: prepared.submitOptionalEvidence,
          userReasonCategory: prepared.userReasonCategory,
          userReasonText: prepared.userReasonText,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_changes?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    _action.removeListener(_changed);
    _action.dispose();
    _minutes.dispose();
    _failureReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AssistantSurface(
    missionId: widget.detail.mission.id,
    child: LayoutBuilder(builder: _buildWorkspace),
  );

  Widget _buildWorkspace(BuildContext context, BoxConstraints viewport) {
    // 高屏把留白分配到圆环上方和控制区之间；小窗/键盘展开时收回，正文仍可滚动。
    final breathingSpace =
        (viewport.maxHeight - MediaQuery.viewInsetsOf(context).bottom - 680)
            .clamp(0.0, 200.0);
    final detail = _action.detail;
    final times = calculateExecutionTimes(
      detail.events,
      widget.clock().toUtc(),
    );
    final original = detail.schedule.plannedDurationMinutes;
    // 当前预算 = 原计划 + 已增加额度；口径统一走领域时间规则，页面不再手写加法。
    final budget = currentBudget(times, original).inMinutes;
    final theme = Theme.of(context);
    if (!_report &&
        detail.events.isNotEmpty &&
        detail.events.last.type == ExecutionEventType.end) {
      final endedBody = MissionPageBody(
        listKey: const Key('mission-evidence-workspace-list'),
        children: [
          MissionHeading(detail: detail),
          const SizedBox(height: AppLayout.spaceLg),
          Container(
            padding: const EdgeInsets.all(AppLayout.spaceXl),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.timelapse_rounded,
                      color: AppColors.primary,
                      size: AppLayout.iconMd,
                    ),
                    const SizedBox(width: AppLayout.spaceSm),
                    Text(
                      '本次专注',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceSm),
                Text(
                  focusDuration(times.focus),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppLayout.spaceMd),
                Text(
                  // 是否报告完成的判定口径统一走 MissionDetail 的派生属性。
                  detail.endReportedCompleted
                      ? '执行已结束 · 用户报告已完成'
                      : '执行已结束 · 用户报告未完成',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.spaceXxl),
          MissionEvidenceSection(
            key: _evidenceKey,
            detail: detail,
            service: widget.service,
            initiallyExpanded: true,
            onChanged: () => unawaited(_refresh()),
          ),
          const SizedBox(height: AppLayout.spaceLg),
          OutlinedButton.icon(
            onPressed: () => openDetailPane<void>(
              context,
              label: '执行记录',
              builder: (_) => MissionRecordPage(
                detail: _action.detail,
                service: widget.service,
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('查看完整执行记录'),
          ),
        ],
      );
      return Scaffold(
        key: const Key('mission-evidence-workspace'),
        appBar: const AppTopBar(title: '执行记录与材料'),
        body: endedBody,
      );
    }
    final hasExtraPlan =
        detail.executionPlan.objective.trim() != detail.mission.title.trim() ||
        detail.executionPlan.steps.isNotEmpty ||
        detail.executionPlan.notes?.trim().isNotEmpty == true;
    final canAct = _action.canAct;
    final running = detail.phase == MissionPhase.running;
    final showPrompt =
        running &&
        detail.schedule.fixedStartAt == null &&
        times.focus >= Duration(minutes: budget) &&
        _promptedBudget != budget;
    final feedback = MissionActionFeedback(
      controller: _action,
      onRetry: () => _run(_action.pending!, openReport: _openingReport),
      onRefresh: _refresh,
      onPauseOther: () => _run(
        widget.service.prepareExecution(
          detail: _action.conflict!,
          type: ExecutionEventType.pause,
        ),
      ),
    );
    final footer = _report
        ? MissionActionPair(
            primary: FilledButton(
              key: const Key('report-confirm'),
              onPressed: canAct && _result != null ? _confirmReport : null,
              // 按钮只表达动作；“取消后保持暂停”的解释留在正文，避免双按钮挤成多行。
              child: const Text('确认结束', textAlign: TextAlign.center),
            ),
            secondary: OutlinedButton(
              key: const Key('report-cancel'),
              onPressed: _action.locked ? null : _leaveReport,
              child: Text(
                detail.phase == MissionPhase.reportPending ? '稍后确认' : '取消报告',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : detail.phase == MissionPhase.reportPending
        ? FilledButton.icon(
            key: const Key('execution-end'),
            onPressed: canAct ? _beginReport : null,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('确认完成情况'),
          )
        : MissionActionPair(
            primary: FilledButton.icon(
              key: const Key('execution-toggle'),
              onPressed: canAct && detail.phase != MissionPhase.reportPending
                  ? running
                        ? _requestPause
                        : () => _run(_action.prepare(ExecutionEventType.resume))
                  : null,
              icon: Icon(
                running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(running ? '暂停' : '继续执行'),
            ),
            secondary: OutlinedButton.icon(
              key: const Key('execution-end'),
              onPressed: canAct ? _openReport : null,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('结束'),
            ),
          );
    final body = MissionPageBody(
      listKey: const Key('mission-execution-list'),
      // 结束报告仍固定确认区；执行控制与圆环一起滚动，保持同一视觉中心。
      footer: _report ? footer : null,
      children: [
        if (_report)
          MissionHeading(detail: detail)
        else ...[
          Semantics(
            header: true,
            child: Text(
              detail.mission.title,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          if (detail.ownershipInfo != null) ...[
            const SizedBox(height: AppLayout.spaceSm),
            Text(
              detail.ownershipInfo!.label,
              key: const Key('mission-ownership-path'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
        SizedBox(
          height: AppLayout.sectionGap + (_report ? 0 : breathingSpace * .35),
        ),
        if (_report) ...[
          Container(
            padding: const EdgeInsets.all(AppLayout.spaceXl),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('本次专注时长'),
                Text(
                  focusDuration(_reportFocus ?? times.focus),
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.spaceXl),
          Text(
            detail.phase == MissionPhase.reportPending
                ? '计划时间已到，计时已停止。请选择实际完成情况，确认后可补充材料。'
                : detail.phase == MissionPhase.paused
                ? '已暂停，取消报告后仍保持暂停。请选择实际完成情况，确认后才保存。'
                : '执行状态已变化，本次报告尚未保存。请先查看下方说明。',
          ),
          const SizedBox(height: AppLayout.spaceLg),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ChoiceChip(
                key: const Key('report-completed'),
                label: const Text('已完成'),
                selected: _result == UserReportedResult.completed,
                onSelected: _action.locked
                    ? null
                    : (_) => setState(
                        () => _result = UserReportedResult.completed,
                      ),
              ),
              ChoiceChip(
                key: const Key('report-not-completed'),
                label: const Text('未完成'),
                selected: _result == UserReportedResult.notCompleted,
                onSelected: _action.locked
                    ? null
                    : (_) => setState(
                        () => _result = UserReportedResult.notCompleted,
                      ),
              ),
            ],
          ),
          if (_result == UserReportedResult.notCompleted) ...[
            const SizedBox(height: AppLayout.spaceLg),
            AppDropdownFormField<String>(
              initialValue: _reasonCategory,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '原因类别（可不选）'),
              items: [
                for (final entry in failureReasonLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: _action.locked
                  ? null
                  : (value) => setState(() => _reasonCategory = value),
            ),
            const SizedBox(height: AppLayout.spaceLg),
            TextField(
              key: const Key('report-reason'),
              controller: _failureReason,
              enabled: !_action.locked,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '补充说明（可不填）'),
            ),
          ],
          if (_result == UserReportedResult.completed &&
              detail.mission.verificationPolicy ==
                  VerificationPolicy.optionalEvidence) ...[
            const SizedBox(height: AppLayout.spaceXl),
            Text('材料可选', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppLayout.spaceSm),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('report-evidence-skip'),
                  label: const Text('不交材料，直接结束'),
                  selected: !_submitOptionalEvidence,
                  onSelected: _action.locked
                      ? null
                      : (_) => setState(() => _submitOptionalEvidence = false),
                ),
                ChoiceChip(
                  key: const Key('report-evidence-submit'),
                  label: const Text('提交文本或图片'),
                  selected: _submitOptionalEvidence,
                  onSelected: _action.locked
                      ? null
                      : (_) => setState(() => _submitOptionalEvidence = true),
                ),
              ],
            ),
            const SizedBox(height: AppLayout.spaceSm),
            const Text('确认后结束执行；选择提交时，可以现在整理，也可以稍后补交。'),
          ],
          if (_result == UserReportedResult.completed &&
              detail.mission.verificationPolicy ==
                  VerificationPolicy.requiredEvidence) ...[
            const SizedBox(height: AppLayout.spaceXl),
            Text('报告完成后必须提交材料', style: theme.textTheme.titleMedium),
            if (detail.schedule.evidenceDeadlineAt != null)
              Text(
                '提交截止：${missionLocalTime(detail.schedule.evidenceDeadlineAt!, detail.schedule.timeZone)}',
              ),
            const Text('确认后停止计时，任务项会提示待提交材料。超过截止仍保存完成报告，并记录材料超时。'),
          ],
          feedback,
        ] else ...[
          ExecutionFocusRing(
            focus: times.focus,
            budgetMinutes: budget,
            paused: !running,
          ),
          if (detail.phase == MissionPhase.reportPending) ...[
            const SizedBox(height: AppLayout.spaceLg),
            const Text('计划时间已到，计时已停止，待确认完成情况。', textAlign: TextAlign.center),
          ],
          if (times.extensionMinutes > 0) ...[
            const SizedBox(height: AppLayout.spaceMd),
            Center(
              child: Text(
                '原计划 $original 分钟 · 已增加 ${times.extensionMinutes} 分钟',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          SizedBox(height: AppLayout.executionRingGap + breathingSpace * .3),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: footer,
            ),
          ),
          const SizedBox(height: AppLayout.spaceSm),
          if (detail.phase != MissionPhase.reportPending)
            Center(
              child: TextButton.icon(
                key: const Key('execution-extend'),
                onPressed: canAct
                    ? () => setState(() => _extend = !_extend)
                    : null,
                icon: const Icon(Icons.add_rounded, size: AppLayout.iconMd),
                label: const Text('延长时间'),
              ),
            ),
          if (_extend) ...[
            const SizedBox(height: AppLayout.spaceLg),
            TextField(
              key: const Key('execution-minutes'),
              controller: _minutes,
              enabled: !_action.locked,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '增加时间',
                hintText: '请输入正整数',
                suffixText: '分钟',
                errorText: _inputError,
              ),
            ),
            const SizedBox(height: AppLayout.spaceLg),
            FilledButton(
              onPressed: canAct
                  ? () {
                      final minutes = int.tryParse(_minutes.text.trim());
                      if (minutes == null || minutes <= 0) {
                        setState(() => _inputError = '请输入大于0的整数分钟');
                        return;
                      }
                      _run(
                        _action.prepare(
                          ExecutionEventType.extend,
                          minutes: minutes,
                        ),
                      );
                    }
                  : null,
              child: const Text('确认增加额度'),
            ),
          ],
          if (showPrompt) ...[
            const SizedBox(height: AppLayout.spaceLg),
            const Text('已达到当前额度，可以结束，也可以增加时间继续。不会自动结束。'),
            TextButton(
              onPressed: canAct
                  ? () => setState(() {
                      _promptedBudget = budget;
                      _extend = true;
                    })
                  : null,
              child: const Text('继续并增加时间'),
            ),
            TextButton(
              onPressed: () => setState(() => _promptedBudget = budget),
              child: const Text('暂不处理'),
            ),
          ],
          if (times.clockBehind)
            const Padding(
              padding: EdgeInsets.only(top: AppLayout.spaceLg),
              child: Text('系统时间早于上一条记录，请校正系统时间。时长暂按最后记录计算。'),
            ),
          feedback,
          const SizedBox(height: AppLayout.sectionGap),
          if (hasExtraPlan)
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppLayout.radiusLg),
              ),
              child: AppExpansionTile(
                leading: const Icon(Icons.track_changes_rounded),
                title: Text('当前目标', style: theme.textTheme.titleSmall),
                subtitle: Text(
                  detail.executionPlan.objective,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  AppLayout.spaceLg,
                  AppLayout.spaceSm,
                  AppLayout.spaceLg,
                  AppLayout.spaceLg,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 摘要可以收起，展开后保留完整目标，长文本不会丢失。
                  Text(detail.executionPlan.objective),
                  for (var i = 0; i < detail.executionPlan.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: AppLayout.spaceSm),
                      child: Text('${i + 1}. ${detail.executionPlan.steps[i]}'),
                    ),
                  if (detail.executionPlan.notes?.trim().isNotEmpty == true)
                    Text(detail.executionPlan.notes!),
                ],
              ),
            ),
        ],
      ],
    );
    return PopScope<void>(
      canPop: !_action.busy && !_report,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _report) unawaited(_leaveReport());
      },
      child: Scaffold(
        key: const Key('mission-execution-page'),
        appBar: AppTopBar(
          title: _report ? '结束报告' : '执行任务',
          canGoBack: !_action.busy,
          onBack: _report ? _leaveReport : null,
          actions: [
            if (!_report)
              IconButton(
                tooltip: '任务详情',
                onPressed: _action.locked ? null : _viewDetails,
                icon: const Icon(Icons.info_outline),
              ),
          ],
        ),
        body: body,
      ),
    );
  }
}
