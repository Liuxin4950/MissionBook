import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/detail_pane.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../../core/theme/app_layout.dart';
import 'mission_phase_icon.dart';
import '../../../application/missions/mission_service.dart';
import '../../../domain/entities/mission_detail.dart';
import '../execution/mission_execution_page.dart';
import 'mission_live_status.dart';

/// 不按今天日期过滤，跨午夜或切换顶层页也能找回运行/暂停任务。
class ActiveMissionsBar extends StatefulWidget {
  const ActiveMissionsBar({
    super.key,
    required this.service,
    this.clock = DateTime.now,
  });
  final MissionService service;
  final DateTime Function() clock;
  @override
  State<ActiveMissionsBar> createState() => _ActiveMissionsBarState();
}

class _ActiveMissionsBarState extends State<ActiveMissionsBar>
    with WidgetsBindingObserver {
  late Future<List<MissionDetail>> _active;
  StreamSubscription<void>? _changes;
  bool _opening = false;
  bool _choosing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  void _listen() {
    _active = widget.service.findActive();
    _active.ignore();
    _changes = widget.service.changes.listen((_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant ActiveMissionsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      unawaited(_changes?.cancel());
      _listen();
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _active = widget.service.findActive();
        _active.ignore();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _open(MissionDetail detail) async {
    if (_opening) return;
    _opening = true;
    try {
      final latest = await widget.service.findDetail(
        missionId: detail.mission.id,
      );
      if (!mounted || latest == null) return;
      final closed = openDetailPane<void>(
        context,
        label: '任务执行',
        builder: (_) => MissionExecutionPage(
          detail: latest,
          service: widget.service,
          clock: widget.clock,
        ),
      );
      unawaited(closed.then((_) => _refresh()));
    } finally {
      _opening = false;
    }
  }

  Future<void> _choose(List<MissionDetail> active) async {
    if (_choosing) return;
    _choosing = true;
    try {
      final selected = await showAdaptiveSheet<MissionDetail>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .65,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '当前任务',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final detail in active)
                  ListTile(
                    leading: MissionPhaseIcon(phase: detail.phase),
                    title: Text(detail.mission.title),
                    subtitle: MissionLiveStatus(
                      phase: detail.phase,
                      events: detail.events,
                      clock: widget.clock,
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(detail),
                  ),
              ],
            ),
          ),
        ),
      );
      if (mounted && selected != null) await _open(selected);
    } finally {
      _choosing = false;
    }
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MissionDetail>>(
    future: _active,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton(
          onPressed: _refresh,
          child: const Text('当前任务读取失败，点击重试'),
        );
      }
      final active = snapshot.data;
      if (active == null || active.isEmpty) return const SizedBox.shrink();
      final detail = active.first;
      final compact = AppLayout.windowClassOf(context) == WindowClass.compact;
      return SafeArea(
        top: false,
        bottom: !compact,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const Key('active-mission'),
                      onTap: () => _open(detail),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            MissionPhaseIcon(phase: detail.phase),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detail.mission.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  MissionLiveStatus(
                                    phase: detail.phase,
                                    events: detail.events,
                                    clock: widget.clock,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (active.length > 1)
                    IconButton(
                      key: const Key('active-missions-picker'),
                      tooltip: '其他暂停任务 · ${active.length - 1}',
                      onPressed: () => _choose(active),
                      icon: Badge(
                        label: Text('${active.length}'),
                        child: const Icon(Icons.list_rounded),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.chevron_right),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
