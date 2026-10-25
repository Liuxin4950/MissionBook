import 'package:mission_book/presentation/missions/detail/mission_detail_content.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/missions/mission_service.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../form/mission_form_page.dart';
import '../shared/mission_action_controller.dart';
import '../shared/mission_execution_display.dart';
import '../execution/mission_execution_page.dart';
import '../record/mission_record_page.dart';
import '../shared/mission_retry_button.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/execution_command.dart';
import '../evidence/mission_evidence_section.dart';

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
  MissionDetail? _lastDetail;
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
    // 把回调登记到共享服务；服务发通知后，回调通过 _retry → _readDetail 重读。
    // 不在回调里直接把阶段设成 running，因为变化也可能是暂停、取消或其他任务。
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
      _lastDetail = null;
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
      // 收到通知、回到前台或手动重试时替换查询；普通 build 复用这个 Future。
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
      final saved = await openDetailPane<bool>(
        context,
        label: '编辑任务',
        builder: (context) =>
            MissionFormPage.edit(missionService: service, detail: detail),
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
      // 同步转场（等价原 pushReplacement），返回值由目标页自行承担。
      unawaited(
        openDetailPane<void>(
          context,
          label: executing ? '任务执行' : '执行记录',
          // 从执行/记录返回不再回到本详情页。
          replace: DetailPaneReplace.top,
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
      await openDetailPane<void>(
        context,
        label: '执行记录',
        builder: (_) => MissionRecordPage.fromTaskDetail(
          detail: detail,
          service: widget.missionService,
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
            key: ValueKey(
              '${widget.missionId}-${identityHashCode(widget.missionService)}-${widget._entry.name}',
            ),
            // 监听 _detail，读取完成后由框架重新调用这里。
            future: _detail,
            builder: (context, snapshot) {
              // FutureBuilder 监听 _detail，读取完成后由框架重新调用这里。
              // 等待时不显示上一次结果，避免重试或换任务时短暂展示旧数据。
              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData &&
                  _lastDetail == null) {
                return const Center(
                  child: CircularProgressIndicator(semanticsLabel: '正在读取任务详情'),
                );
              }
              final preserveMaterials =
                  _lastDetail?.phase == MissionPhase.evidencePending ||
                  _lastDetail?.evidence.isNotEmpty == true;
              if (snapshot.hasError && !preserveMaterials) {
                return _DetailMessage(message: '任务详情读取失败，请重试', onRetry: _retry);
              }
              final detail =
                  _executionDetail ??
                  snapshot.data ??
                  (snapshot.connectionState != ConnectionState.done ||
                          snapshot.hasError
                      ? _lastDetail
                      : null);
              if (detail == null) {
                return const _DetailMessage(message: '未找到这个任务，请返回列表刷新');
              }
              _lastDetail = detail;
              _openCurrentPage(detail);
              if (_redirecting) {
                return const Center(child: CircularProgressIndicator());
              }
              final action = _actionsFor(detail);
              final notStarted = detail.phase == MissionPhase.notStarted;
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
              } else if (detail.phase == MissionPhase.cancelled) {
                auxiliaryAction = MissionRetryButton(
                  source: detail,
                  service: widget.missionService,
                );
              }
              return MissionDetailContent(
                detail: detail,
                materialSection: MissionEvidenceSection(
                  key: ValueKey('detail-evidence-${detail.mission.id}'),
                  detail: detail,
                  service: widget.missionService,
                  initiallyExpanded:
                      detail.phase == MissionPhase.evidencePending,
                  onChanged: _retry,
                ),
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
