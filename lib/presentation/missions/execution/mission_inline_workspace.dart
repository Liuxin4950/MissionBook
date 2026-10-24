import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/missions/mission_service.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';
import '../shared/mission_action_controller.dart';
import '../shared/mission_execution_display.dart';
import 'mission_execution_page.dart';

/// 今天任务行内的真实办理入口；复用专注页的执行、报告和材料逻辑，不增加路由。
class MissionInlineWorkspace extends StatefulWidget {
  const MissionInlineWorkspace({
    super.key,
    required this.missionId,
    required this.phase,
    required this.service,
    required this.clock,
    this.onExpansionChanged,
  });
  final String missionId;
  final MissionPhase phase;
  final MissionService service;
  final DateTime Function() clock;
  final ValueChanged<bool>? onExpansionChanged;
  @override
  State<MissionInlineWorkspace> createState() => MissionInlineWorkspaceState();
}

class MissionInlineWorkspaceState extends State<MissionInlineWorkspace>
    with AutomaticKeepAliveClientMixin<MissionInlineWorkspace> {
  bool _open = false;
  bool _loading = false;
  String? _error;
  MissionDetail? _detail;
  MissionActionController? _action;
  final _executionKey = GlobalKey<MissionExecutionPageState>();
  @override
  bool get wantKeepAlive => _open;

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _read() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.service.findDetail(
        missionId: widget.missionId,
      );
      if (!mounted) return;
      if (detail == null) throw StateError('任务已不存在，请刷新列表');
      _action?.removeListener(_changed);
      _action?.dispose();
      _action = MissionActionController(detail: detail, service: widget.service)
        ..addListener(_changed);
      setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = '任务读取失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _expand() async {
    setState(() => _open = true);
    updateKeepAlive();
    widget.onExpansionChanged?.call(true);
    await _read();
  }

  Future<bool> prepareToCollapse() async {
    if (_loading || _action?.locked == true) return false;
    return await (_executionKey.currentState?.prepareToCollapse() ??
        Future.value(true));
  }

  Future<void> _collapse() async {
    if (!await prepareToCollapse() || !mounted) return;
    setState(() => _open = false);
    updateKeepAlive();
    widget.onExpansionChanged?.call(false);
  }

  Future<void> _start() async {
    final action = _action!;
    if (!action.canAct) return;
    if (await action.execute(action.prepare(ExecutionEventType.start)) &&
        mounted) {
      setState(() => _detail = action.detail);
    }
  }

  @override
  void dispose() {
    _action?.removeListener(_changed);
    _action?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_open) {
      if (widget.phase == MissionPhase.closed ||
          widget.phase == MissionPhase.cancelled ||
          widget.phase == MissionPhase.evidencePending) {
        return const SizedBox.shrink();
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: Key('inline-open-${widget.missionId}'),
          onPressed: _expand,
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: Text(
            widget.phase == MissionPhase.notStarted ? '在此开始并执行' : '在此继续执行',
          ),
        ),
      );
    }
    final detail = _detail;
    final action = _action;
    return Container(
      key: Key('inline-workspace-${widget.missionId}'),
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '任务工作区',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _collapse,
                child: const Text('收起工作区'),
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _read, child: const Text('重新读取任务')),
          ],
          if (detail != null && action != null) ...[
            if (detail.events.isEmpty) ...[
              Text(
                detail.mission.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(detail.executionPlan.objective),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: Key('inline-start-${widget.missionId}'),
                onPressed: action.canAct ? _start : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('开始任务'),
              ),
              MissionActionFeedback(
                controller: action,
                onRetry: () async {
                  if (await action.execute(action.pending!) && mounted) {
                    setState(() => _detail = action.detail);
                  }
                },
                onRefresh: _read,
                onPauseOther: () async {
                  await action.execute(
                    widget.service.prepareExecution(
                      detail: action.conflict!,
                      type: ExecutionEventType.pause,
                    ),
                  );
                },
              ),
            ] else
              MissionExecutionPage(
                key: _executionKey,
                detail: detail,
                service: widget.service,
                clock: widget.clock,
                embedded: true,
              ),
          ],
        ],
      ),
    );
  }
}
