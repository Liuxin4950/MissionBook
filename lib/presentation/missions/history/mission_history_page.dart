import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/rules/execution_time_rules.dart';
import '../detail/mission_detail_page.dart';
import '../shared/mission_execution_display.dart';
import '../shared/mission_phase_display.dart';
import '../evidence/mission_evidence_section.dart';

/// 执行历史与取消记录分开读取。没有 END 的任务通过“当前任务”恢复执行。
class MissionHistoryPage extends StatefulWidget {
  const MissionHistoryPage({super.key, required this.service});
  final MissionService service;
  @override
  State<MissionHistoryPage> createState() => _MissionHistoryPageState();
}

class _MissionHistoryPageState extends State<MissionHistoryPage>
    with WidgetsBindingObserver {
  late Future<List<MissionDetail>> _records;
  StreamSubscription<void>? _changes;
  bool _cancelled = false;
  bool _opening = false;
  List<MissionDetail>? _lastRecords;
  final _evidenceKeys = <String, GlobalKey<MissionEvidenceSectionState>>{};

  Future<void> _selectCancelled(bool value) async {
    if (_cancelled == value) return;
    for (final key in _evidenceKeys.values) {
      if (!await (key.currentState?.prepareToLeave() ?? Future.value(true))) {
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _cancelled = value;
      _lastRecords = null;
      _records = _load();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  void _listen() {
    _records = _load();
    _changes = widget.service.changes.listen((_) => _refresh());
  }

  Future<List<MissionDetail>> _load() {
    final result = _cancelled
        ? widget.service.findCancelled()
        : widget.service.findFinished();
    result.ignore();
    return result;
  }

  @override
  void didUpdateWidget(covariant MissionHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      unawaited(_changes?.cancel());
      _listen();
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _records = _load();
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
          builder: (_) => MissionDetailPage.fromHistory(
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: AppLayout.horizontalPadding(context),
      title: Text('历史', style: Theme.of(context).textTheme.headlineSmall),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.horizontalPadding(context),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('执行记录'),
                        selected: !_cancelled,
                        onSelected: (_) => unawaited(_selectCancelled(false)),
                      ),
                      ChoiceChip(
                        key: const Key('history-cancelled'),
                        label: const Text('已取消'),
                        selected: _cancelled,
                        onSelected: (_) => unawaited(_selectCancelled(true)),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<MissionDetail>>(
                  future: _records,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done &&
                        !snapshot.hasData &&
                        _lastRecords == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError && _lastRecords == null) {
                      return Center(
                        child: TextButton(
                          onPressed: _refresh,
                          child: const Text('记录读取失败，点击重试'),
                        ),
                      );
                    }
                    final records =
                        snapshot.data ??
                        _lastRecords ??
                        const <MissionDetail>[];
                    if (snapshot.hasData) _lastRecords = snapshot.data;
                    return RefreshIndicator(
                      onRefresh: () async {
                        _refresh();
                        await _records;
                      },
                      child: ListView(
                        padding: AppLayout.pagePadding(context),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (records.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                _cancelled ? '还没有取消的任务' : '还没有执行结束的记录',
                              ),
                            ),
                          for (final detail in records)
                            Card(
                              key: ValueKey(
                                'history-record-${detail.mission.id}',
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    title: Text(detail.mission.title),
                                    subtitle: Text(
                                      _cancelled
                                          ? '已取消 · ${missionLocalTime(detail.mission.cancelledAt!, detail.schedule.timeZone)}'
                                          : '${detail.events.last.userReportedResult == UserReportedResult.completed ? '报告完成' : '报告未完成'} · 专注 ${focusDuration(calculateExecutionTimes(detail.events, detail.events.last.occurredAt).focus)}${evidenceStatusLabel(detail).isEmpty ? '' : '\n${evidenceStatusLabel(detail)}'}',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _open(detail),
                                  ),
                                  if (!_cancelled &&
                                      (detail.phase ==
                                              MissionPhase.evidencePending ||
                                          detail.evidence.isNotEmpty ||
                                          detail.failures.any(
                                            (failure) =>
                                                failure.trigger ==
                                                'EVIDENCE_DEADLINE_MISSED',
                                          )))
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        12,
                                      ),
                                      child: MissionEvidenceSection(
                                        key: _evidenceKeys.putIfAbsent(
                                          detail.mission.id,
                                          () =>
                                              GlobalKey<
                                                MissionEvidenceSectionState
                                              >(),
                                        ),
                                        detail: detail,
                                        service: widget.service,
                                        protectNavigation: false,
                                        onChanged: _refresh,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
