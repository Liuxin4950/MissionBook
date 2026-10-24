import 'dart:async';
import 'package:flutter/material.dart';
import '../../../application/missions/mission_service.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';
import '../detail/mission_detail_page.dart';
import 'mission_live_status.dart';

/// 不按今天日期过滤，跨午夜或切换顶层页也能找回运行/暂停任务。
class ActiveMissionsBar extends StatefulWidget {
  const ActiveMissionsBar({super.key, required this.service});
  final MissionService service;
  @override
  State<ActiveMissionsBar> createState() => _ActiveMissionsBarState();
}

class _ActiveMissionsBarState extends State<ActiveMissionsBar>
    with WidgetsBindingObserver {
  late Future<List<MissionDetail>> _active;
  StreamSubscription<void>? _changes;
  bool _opening = false;
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
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MissionDetailPage(
            missionId: detail.mission.id,
            missionService: widget.service,
          ),
        ),
      );
    } finally {
      _opening = false;
      _refresh();
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('active-mission'),
                leading: Icon(
                  active.first.phase == MissionPhase.running
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
                title: Text(
                  active.first.mission.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: MissionLiveStatus(
                  phase: active.first.phase,
                  events: active.first.events,
                ),
                onTap: () => _open(active.first),
              ),
              if (active.length > 1)
                ExpansionTile(
                  title: Text('其他暂停任务 · ${active.length - 1}'),
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .2,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final detail in active.skip(1))
                            ListTile(
                              title: Text(detail.mission.title),
                              subtitle: MissionLiveStatus(
                                phase: detail.phase,
                                events: detail.events,
                              ),
                              onTap: () => _open(detail),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}
