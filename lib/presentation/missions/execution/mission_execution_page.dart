import 'package:mission_book/presentation/missions/execution/execution_widgets.dart';
import 'dart:async';

import 'package:flutter/material.dart';

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
import '../shared/mission_action_controller.dart';
import '../shared/mission_execution_display.dart';
import '../record/mission_record_page.dart';
import '../detail/mission_detail_page.dart';
import '../evidence/mission_evidence_section.dart';

/// 已 START 任务的执行工作区；独立页和 Today 原位办理共用同一逻辑。
/// 结束报告、材料在同一上下文展开，旧自报独立页沿用原记录路由。
class MissionExecutionPage extends StatefulWidget {
  const MissionExecutionPage({
    super.key,
    required this.detail,
    required this.service,
    this.clock = DateTime.now,
    this.embedded = false,
  });
  final MissionDetail detail;
  final MissionService service;
  final DateTime Function() clock;
  final bool embedded;
  @override
  State<MissionExecutionPage> createState() => MissionExecutionPageState();
}

class MissionExecutionPageState extends State<MissionExecutionPage>
    with WidgetsBindingObserver {
  late final MissionActionController _action;
  Timer? _timer;
  StreamSubscription<void>? _changes;
  bool _foreground = true;
  bool _report = false;
  bool _extend = false;
  bool _openingReport = false;
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
  final _pauseReason = TextEditingController();
  final _failureReason = TextEditingController();
  final _evidenceKey = GlobalKey<MissionEvidenceSectionState>();

  /// Today 收起原位工作区时保护报告和材料；收起本身不保存暂停或结束事件。
  Future<bool> prepareToCollapse() async {
    if (_action.locked) return false;
    if (_report) {
      await _leaveReport();
      if (_report) return false;
    }
    return await (_evidenceKey.currentState?.prepareToLeave() ??
        Future.value(true));
  }

  @override
  void initState() {
    super.initState();
    _action = MissionActionController(
      detail: widget.detail,
      service: widget.service,
    );
    _action.addListener(_changed);
    _changes = widget.service.changes.listen((_) {
      // 自己提交时由 _run 重读；其它入口的变更同步界面，但不替旧报告换序号。
      if (!_action.busy && _action.pending == null) {
        unawaited(_refresh(acceptReportSequence: false));
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
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
    _configureTimer();
  }

  void _configureTimer() {
    _timer?.cancel();
    final phase = _action.detail.phase;
    if (_foreground &&
        TickerMode.valuesOf(context).enabled &&
        (phase == MissionPhase.running || phase == MissionPhase.paused)) {
      // Timer 只要求重新绘制；Focus 始终从已保存时间线重新算，后台也不丢时长。
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_report) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _configureTimer();
    if (_foreground && _action.pending == null) unawaited(_refresh());
  }

  void _showRecord() {
    if (widget.embedded) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (!mounted ||
        _navigating ||
        _action.detail.phase != MissionPhase.closed) {
      return;
    }
    _navigating = true;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        settings: RouteSettings(
          name: '/missions/${_action.detail.mission.id}/record',
        ),
        builder: (_) =>
            MissionRecordPage(detail: _action.detail, service: widget.service),
      ),
    );
  }

  Future<void> _viewDetails() async {
    if (_showingDetails || _action.locked || _report) return;
    _showingDetails = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MissionDetailPage.fromExecution(
            missionId: _action.detail.mission.id,
            missionService: widget.service,
          ),
        ),
      );
      if (mounted) await _refresh();
    } finally {
      _showingDetails = false;
    }
  }

  Future<void> _refresh({bool acceptReportSequence = true}) async {
    final ownPendingEnd = _action.pending?.type == ExecutionEventType.end
        ? _action.pending?.id
        : null;
    if (!await _action.refresh() || !mounted) return;
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
            : '执行记录已变化，请先刷新状态再确认报告，输入已保留。';
      }
      setState(() {});
    }
  }

  Future<void> _run(ExecutionCommand command, {bool openReport = false}) async {
    if (_action.busy) return;
    _openingReport = openReport;
    if (!await _action.execute(command) || !mounted) return;
    _inputError = null;
    _extend = false;
    _pauseReason.clear();
    if (_action.detail.phase == MissionPhase.closed &&
        _action.detail.mission.verificationPolicy ==
            VerificationPolicy.selfReport) {
      if (widget.embedded) {
        _report = false;
      } else {
        _showRecord();
      }
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
      await _run(
        _action.prepare(ExecutionEventType.pause, reason: _pauseReason.text),
        openReport: true,
      );
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
    _pauseReason.dispose();
    _failureReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _action.detail;
    final times = calculateExecutionTimes(
      detail.events,
      widget.clock().toUtc(),
    );
    final original = detail.schedule.plannedDurationMinutes;
    final budget = original + times.extensionMinutes;
    final theme = Theme.of(context);
    if (!_report &&
        detail.events.isNotEmpty &&
        detail.events.last.type == ExecutionEventType.end) {
      final endedBody = MissionPageBody(
        embedded: widget.embedded,
        listKey: const Key('mission-evidence-workspace-list'),
        children: [
          MissionHeading(detail: detail),
          const SizedBox(height: 16),
          Text(
            '本次专注 ${focusDuration(times.focus)} · 执行已结束',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            detail.events.last.userReportedResult ==
                    UserReportedResult.completed
                ? '用户报告：已完成'
                : '用户报告：未完成',
          ),
          const SizedBox(height: 24),
          MissionEvidenceSection(
            key: _evidenceKey,
            detail: detail,
            service: widget.service,
            initiallyExpanded: true,
            onChanged: () => unawaited(_refresh()),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => MissionRecordPage(
                  detail: _action.detail,
                  service: widget.service,
                ),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('查看完整执行记录'),
          ),
        ],
      );
      return widget.embedded
          ? endedBody
          : Scaffold(
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
              child: const Text('取消报告', textAlign: TextAlign.center),
            ),
          )
        : MissionActionPair(
            primary: FilledButton.icon(
              key: const Key('execution-toggle'),
              onPressed: canAct
                  ? () => _run(
                      _action.prepare(
                        running
                            ? ExecutionEventType.pause
                            : ExecutionEventType.resume,
                        reason: running ? _pauseReason.text : null,
                      ),
                    )
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
      embedded: widget.embedded,
      listKey: const Key('mission-execution-list'),
      footer: footer,
      children: [
        MissionHeading(detail: detail),
        const SizedBox(height: AppLayout.sectionGap),
        if (_report) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(24),
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
          const SizedBox(height: 20),
          Text(
            detail.phase == MissionPhase.paused
                ? '已暂停，取消报告后仍保持暂停。请选择实际完成情况，确认后才保存。'
                : '执行状态已变化，本次报告尚未保存。请先查看下方说明。',
          ),
          const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 20),
            Text('材料可选', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            const Text('确认后结束执行；选择提交时，可以现在整理，也可以稍后补交。'),
          ],
          if (_result == UserReportedResult.completed &&
              detail.mission.verificationPolicy ==
                  VerificationPolicy.requiredEvidence) ...[
            const SizedBox(height: 20),
            Text('报告完成后必须提交材料', style: theme.textTheme.titleMedium),
            if (detail.schedule.evidenceDeadlineAt != null)
              Text(
                '提交截止：${missionLocalTime(detail.schedule.evidenceDeadlineAt!, detail.schedule.timeZone)}',
              ),
            const Text('确认后停止计时，任务项会提示待提交材料。超过截止仍保存完成报告，并记录材料超时。'),
          ],
          feedback,
        ] else ...[
          ExecutionFocusRing(focus: times.focus, budgetMinutes: budget),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '原计划 $original 分钟 · 已增加 ${times.extensionMinutes} 分钟',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              key: const Key('execution-extend'),
              onPressed: canAct
                  ? () => setState(() => _extend = !_extend)
                  : null,
              icon: const Icon(Icons.more_time),
              label: const Text('延长时间'),
            ),
          ),
          if (_extend) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('execution-minutes'),
              controller: _minutes,
              enabled: !_action.locked,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '增加分钟数（正整数）'),
            ),
            if (_inputError != null)
              Text(
                _inputError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
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
            const SizedBox(height: 16),
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
              padding: EdgeInsets.only(top: 16),
              child: Text('系统时间早于上一条记录，请校正系统时间。时长暂按最后记录计算。'),
            ),
          feedback,
          const SizedBox(height: 16),
          const Divider(),
          if (hasExtraPlan)
            Container(
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: ExpansionTile(
                title: const Text('当前目标'),
                subtitle: Text(detail.executionPlan.objective),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  for (var i = 0; i < detail.executionPlan.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${i + 1}. ${detail.executionPlan.steps[i]}'),
                    ),
                  if (detail.executionPlan.notes?.trim().isNotEmpty == true)
                    Text(detail.executionPlan.notes!),
                ],
              ),
            ),
          if (running) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: ExpansionTile(
                title: const Text('暂停说明（选填）'),
                shape: const Border(),
                collapsedShape: const Border(),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  TextField(
                    controller: _pauseReason,
                    enabled: !_action.locked,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '暂停原因（可不填）'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
    return PopScope<void>(
      canPop: !_action.busy && !_report,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _report) unawaited(_leaveReport());
      },
      child: widget.embedded
          ? body
          : Scaffold(
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
