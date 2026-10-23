import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../application/missions/mission_service.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_top_bar.dart';
import 'mission_form_page.dart';
import 'mission_action_controller.dart';
import 'mission_execution_display.dart';
import 'mission_execution_page.dart';
import 'mission_record_page.dart';
import 'mission_retry_button.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/execution_command.dart';

// 入口意图与任务阶段分开：同一已结束任务，从任务列表读详情，从历史读执行记录。
enum _MissionPageEntry { task, executionDetails, historyRecord, recordDetails }

/// 完整任务信息的阅读入口；运行/暂停可直达执行，已结束保留详情与记录入口。
class MissionDetailPage extends StatefulWidget {
  const MissionDetailPage({
    super.key,
    required this.missionId,
    required this.missionService,
  }) : _entry = _MissionPageEntry.task;

  /// 从专注页临时阅读方案，保留原执行路由；“返回执行”不会另开第二份执行页。
  const MissionDetailPage.fromExecution({
    super.key,
    required this.missionId,
    required this.missionService,
  }) : _entry = _MissionPageEntry.executionDetails;

  /// 历史列表按最新事实直达记录；已取消仍阅读取消详情，不复用过期列表快照。
  const MissionDetailPage.fromHistory({
    super.key,
    required this.missionId,
    required this.missionService,
  }) : _entry = _MissionPageEntry.historyRecord;

  /// 从执行记录临时阅读任务方案；返回原记录，不再压入同一任务的第二份记录页。
  const MissionDetailPage.fromRecord({
    super.key,
    required this.missionId,
    required this.missionService,
  }) : _entry = _MissionPageEntry.recordDetails;

  final String missionId;
  final MissionService missionService;
  final _MissionPageEntry _entry;

  @override
  State<MissionDetailPage> createState() => _MissionDetailPageState();
}

class _MissionDetailPageState extends State<MissionDetailPage>
    with WidgetsBindingObserver {
  // Future 是“这一次读取的结果”，不是数据库连接；可能得到详情、null 或错误。
  late Future<MissionDetail?> _detail;
  bool _isConfirmingCancel = false;
  bool _isCancelling = false;
  bool _isEditing = false;
  String? _cancelError;
  // 页面换任务后，旧操作的返回结果不能修改新任务的界面。
  int _cancelRequest = 0;
  bool _isExecuting = false;
  MissionDetail? _executionDetail;
  MissionActionController? _action;
  bool _redirecting = false;
  bool _isOpeningRecord = false;
  StreamSubscription<void>? _changes;
  int _lastReadChangeRevision = -1;

  bool get _isCancelBusy =>
      _isConfirmingCancel || _isCancelling || _isEditing || _isExecuting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detail = _readDetail();
    _listenChanges();
  }

  void _listenChanges() {
    _changes = widget.missionService.changes.listen((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (_lastReadChangeRevision >= widget.missionService.changeRevision) {
        return;
      }
      if (!_isCancelBusy && _action?.pending == null) _retry();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_isCancelBusy &&
        _action?.pending == null) {
      _retry();
    }
  }

  // 一次本地详情查询。
  Future<MissionDetail?> _readDetail() {
    _lastReadChangeRevision = widget.missionService.changeRevision;
    // widget 指向与此 State 配对的 MissionDetailPage，两个参数由今天页提供。
    final result = widget.missionService.findDetail(
      missionId: widget.missionId,
    );
    // 下一帧 FutureBuilder 才会订阅新查询；先接收可能提前到达的错误。
    // ignore 不改变原 Future 的结果，FutureBuilder 仍会显示读取失败和重试。
    result.ignore();
    return result;
  }

  @override
  void didUpdateWidget(covariant MissionDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 若父级让同一个页面改读另一个任务，就替换 Future。
    // Flutter 随后会再次 build；FutureBuilder 也会忽略上一次尚未返回的结果。
    if (oldWidget.missionId != widget.missionId ||
        oldWidget.missionService != widget.missionService ||
        oldWidget._entry != widget._entry) {
      _cancelRequest++;
      _isConfirmingCancel = false;
      _isCancelling = false;
      _isEditing = false;
      _cancelError = null;
      _executionDetail = null;
      _isExecuting = false;
      _resetAction();
      _redirecting = false;
      _isOpeningRecord = false;
      unawaited(_changes?.cancel());
      _listenChanges();
      _detail = _readDetail();
    }
  }

  void _retry() {
    setState(() {
      _resetAction();
      _executionDetail = null;
      // 只有明确点击重试时才新建读取；普通 build 始终使用原来的 Future。
      _detail = _readDetail();
    });
  }

  Future<void> _requestCancel() async {
    if (_isCancelBusy) return;
    // 先固定这次操作的对象；await 期间 widget 可能已经改读另一个任务。
    final request = ++_cancelRequest;
    final missionId = widget.missionId;
    final service = widget.missionService;
    setState(() {
      _isConfirmingCancel = true;
      _cancelError = null;
    });
    try {
      final confirmed = await AppConfirmDialog.show(
        context: context,
        title: '取消这个任务？',
        message: '取消后仍会保留任务和原计划，可以在已取消列表中查看。',
        cancelText: '保留任务',
        confirmText: '确认取消',
      );
      if (!mounted || request != _cancelRequest) return;
      if (!confirmed) return;
      setState(() {
        _isConfirmingCancel = false;
        _isCancelling = true;
      });
      // await 等待真实写事务完成；按钮禁用只防重复操作，不代替仓储校验。
      await service.cancel(missionId: missionId);
      if (!mounted || request != _cancelRequest) return;
      setState(() {
        // 重新查询已保存的取消时间，不在页面伪造“已取消”。
        _executionDetail = null;
        _resetAction();
        // 查询错误交给 FutureBuilder，不混成“取消保存失败”。
        _detail = _readDetail();
      });
    } catch (error, stackTrace) {
      if (!mounted || request != _cancelRequest) return;
      debugPrint('取消任务失败：$error\n$stackTrace');
      setState(() {
        _cancelError = '取消失败，请重试';
      });
    } finally {
      if (mounted && request == _cancelRequest) {
        setState(() {
          _isConfirmingCancel = false;
          _isCancelling = false;
        });
      }
    }
  }

  Future<void> _requestEdit(MissionDetail detail) async {
    if (_isCancelBusy) return;
    final request = ++_cancelRequest;
    final service = widget.missionService;
    setState(() {
      _isEditing = true;
      _cancelError = null;
    });
    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) =>
              MissionFormPage.edit(missionService: service, detail: detail),
        ),
      );
      if (!mounted || request != _cancelRequest) return;
      // 包括放弃草稿后的返回：编辑期间任务也可能被其他操作取消或改动。
      setState(() {
        _executionDetail = null;
        _resetAction();
        _detail = _readDetail();
      });
      if (saved == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('任务已更新')));
      }
    } finally {
      if (mounted && request == _cancelRequest) {
        setState(() {
          _isEditing = false;
        });
      }
    }
  }

  void _resetAction() {
    _action?.removeListener(_executionChanged);
    _action?.dispose();
    _action = null;
  }

  void _executionChanged() {
    if (!mounted) return;
    setState(() {
      _isExecuting = _action!.busy;
      _executionDetail = _action!.detail;
    });
  }

  MissionActionController _actionsFor(MissionDetail detail) {
    _action ??= MissionActionController(
      detail: detail,
      service: widget.missionService,
    )..addListener(_executionChanged);
    return _action!;
  }

  void _openCurrentPage(MissionDetail detail) {
    if (widget._entry == _MissionPageEntry.executionDetails ||
        widget._entry == _MissionPageEntry.recordDetails) {
      return;
    }
    if (_redirecting || !mounted || detail.mission.id != widget.missionId) {
      return;
    }
    final executing =
        detail.phase == MissionPhase.running ||
        detail.phase == MissionPhase.paused;
    final historyRecord =
        widget._entry == _MissionPageEntry.historyRecord &&
        detail.phase == MissionPhase.closed;
    // 从今天等任务入口打开已结束任务时留在完整详情，不自动跳过原计划与方案。
    if (!executing && !historyRecord) return;
    _redirecting = true;
    // 替换当前任务路由，避免“结束→返回→旧执行页→旧详情”这样的重复返回栈。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          detail.mission.id != widget.missionId ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          settings: RouteSettings(
            name:
                '/missions/${detail.mission.id}/${executing ? 'execution' : 'record'}',
          ),
          builder: (_) => executing
              ? MissionExecutionPage(
                  detail: detail,
                  service: widget.missionService,
                )
              : MissionRecordPage(
                  detail: detail,
                  service: widget.missionService,
                ),
        ),
      );
    });
  }

  Future<void> _requestRecord(MissionDetail detail) async {
    if (_isOpeningRecord || detail.phase != MissionPhase.closed) return;
    final request = _cancelRequest;
    setState(() => _isOpeningRecord = true);
    try {
      // 此处用 push 保留详情；记录页返回时，原计划、Why和方案仍在原阅读上下文。
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: RouteSettings(
            name: '/missions/${detail.mission.id}/record',
          ),
          builder: (_) => MissionRecordPage.fromTaskDetail(
            detail: detail,
            service: widget.missionService,
          ),
        ),
      );
    } finally {
      if (mounted && request == _cancelRequest) {
        setState(() => _isOpeningRecord = false);
      }
    }
  }

  Future<void> _submit(ExecutionCommand command) async {
    final action = _action!;
    if (await action.execute(command) &&
        mounted &&
        identical(action, _action)) {
      _openCurrentPage(action.detail);
    }
  }

  Future<void> _refreshExecution() async {
    final action = _action!;
    if (await action.refresh() && mounted && identical(action, _action)) {
      _openCurrentPage(action.detail);
    }
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    _resetAction();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      // 写入期间留在当前页，等待事务结果；对话框自身仍可用系统返回关闭。
      canPop: !_isCancelBusy,
      child: Scaffold(
        appBar: AppTopBar(title: '任务详情', canGoBack: !_isCancelBusy),
        // 详情是独立阅读页，有自己的返回按钮，不复制 AppShell 的底部导航。
        body: SafeArea(
          top: false,
          child: FutureBuilder<MissionDetail?>(
            // 监听 _detail，读取完成后由框架重新调用这里。
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
              final detail = _executionDetail ?? snapshot.data;
              if (detail == null) {
                return const _DetailMessage(message: '未找到这个任务，请返回列表刷新');
              }
              _openCurrentPage(detail);
              if (_redirecting) {
                return const Center(child: CircularProgressIndicator());
              }
              final action = _actionsFor(detail);
              final notStarted = detail.phase == MissionPhase.notStarted;
              final selfReport =
                  detail.mission.verificationPolicy ==
                  VerificationPolicy.selfReport;
              final disabled = _isCancelBusy || !action.canAct;
              Widget? auxiliaryAction;
              if (widget._entry == _MissionPageEntry.executionDetails &&
                  !notStarted) {
                auxiliaryAction = FilledButton(
                  key: const Key('detail-return-execution'),
                  onPressed: _isCancelBusy
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    detail.phase == MissionPhase.closed ? '查看执行记录' : '返回执行任务',
                  ),
                );
              } else if (widget._entry == _MissionPageEntry.recordDetails &&
                  detail.phase == MissionPhase.closed) {
                auxiliaryAction = FilledButton(
                  key: const Key('detail-return-record'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回执行记录', textAlign: TextAlign.center),
                );
              } else if (detail.phase == MissionPhase.closed) {
                auxiliaryAction = FilledButton.icon(
                  key: const Key('detail-view-record'),
                  onPressed: _isOpeningRecord
                      ? null
                      : () => _requestRecord(detail),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('查看执行记录', textAlign: TextAlign.center),
                );
              } else if (selfReport && detail.phase == MissionPhase.cancelled) {
                auxiliaryAction = MissionRetryButton(
                  source: detail,
                  service: widget.missionService,
                );
              }
              return _MissionDetailContent(
                detail: detail,
                actionFeedback: MissionActionFeedback(
                  controller: action,
                  onRetry: () => _submit(action.pending!),
                  onRefresh: _refreshExecution,
                  onPauseOther: () => _submit(
                    widget.missionService.prepareExecution(
                      detail: action.conflict!,
                      type: ExecutionEventType.pause,
                    ),
                  ),
                ),
                footer: notStarted
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 基础维护动作直接可见，不藏进更多菜单；开始后由独立页面接管。
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              if (selfReport)
                                TextButton.icon(
                                  key: const Key('edit-mission'),
                                  onPressed: disabled
                                      ? null
                                      : () => _requestEdit(detail),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('修改任务'),
                                ),
                              TextButton.icon(
                                key: const Key('cancel-mission'),
                                onPressed: disabled ? null : _requestCancel,
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('取消任务'),
                              ),
                            ],
                          ),
                          if (selfReport)
                            FilledButton.icon(
                              key: const Key('execution-start'),
                              onPressed: disabled
                                  ? null
                                  : () => _submit(
                                      action.prepare(ExecutionEventType.start),
                                    ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: const StadiumBorder(),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('开始任务'),
                            ),
                        ],
                      )
                    : auxiliaryAction,
                isCancelling: _isCancelling,
                cancelError: _cancelError,
              );
            },
          ),
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
  const _MissionDetailContent({
    required this.detail,
    required this.actionFeedback,
    required this.footer,
    required this.isCancelling,
    this.cancelError,
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
                style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
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
