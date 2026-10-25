import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../widgets/app_page_header.dart';
import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/evidence.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/rules/execution_time_rules.dart';
import '../detail/mission_detail_page.dart';
import '../record/mission_record_page.dart';
import '../shared/mission_execution_display.dart';
import '../shared/mission_phase_display.dart';
import '../evidence/evidence_image_preview.dart';

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
  final _thumbnails = <String, Future<Uint8List>>{};

  void _selectCancelled(bool value) {
    if (_cancelled == value) return;
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
          builder: (_) => _cancelled
              ? MissionDetailPage.fromHistory(
                  missionId: detail.mission.id,
                  missionService: widget.service,
                )
              : MissionRecordPage(detail: detail, service: widget.service),
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
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: Column(
            children: [
              Padding(
                padding: AppLayout.pagePadding(context).copyWith(bottom: 0),
                child: AppPageHeader(
                  title: '历史',
                  subtitle: Text(
                    '回看执行与材料记录',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
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
                        onSelected: (_) => _selectCancelled(false),
                      ),
                      ChoiceChip(
                        key: const Key('history-cancelled'),
                        label: const Text('已取消'),
                        selected: _cancelled,
                        onSelected: (_) => _selectCancelled(true),
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
                      child: ListView.builder(
                        padding: AppLayout.pagePadding(context),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: records.isEmpty ? 1 : records.length,
                        itemBuilder: (context, index) {
                          if (records.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                _cancelled ? '还没有取消的任务' : '还没有执行结束的记录',
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (index == 0 ||
                                  _day(records[index - 1]) !=
                                      _day(records[index]))
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: index == 0 ? 0 : 16,
                                    bottom: 10,
                                  ),
                                  child: Text(
                                    _day(records[index]),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                              _recordCard(records[index]),
                            ],
                          );
                        },
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

  String _day(MissionDetail detail) => missionLocalTime(
    _cancelled ? detail.mission.cancelledAt! : detail.events.last.occurredAt,
    detail.schedule.timeZone,
  ).split(' ').first;

  Widget _recordCard(MissionDetail detail) {
    final theme = Theme.of(context);
    final endedAt = _cancelled
        ? detail.mission.cancelledAt!
        : detail.events.last.occurredAt;
    final clock = missionLocalTime(
      endedAt,
      detail.schedule.timeZone,
      includeDate: false,
    ).substring(0, 5);
    final completed =
        !_cancelled &&
        detail.events.last.userReportedResult == UserReportedResult.completed;
    final images = _cancelled
        ? <Evidence>[]
        : detail.effectiveEvidence
              .where((item) => item.type == EvidenceType.image)
              .toList();
    final status = _cancelled
        ? '已取消'
        : completed
        ? '报告完成'
        : '报告未完成';
    final focus = _cancelled
        ? null
        : focusDuration(
            calculateExecutionTimes(
              detail.events,
              detail.events.last.occurredAt,
            ).focus,
          );
    final evidence = _cancelled ? '' : evidenceStatusLabel(detail);
    return Padding(
      key: ValueKey('history-record-${detail.mission.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => _open(detail),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: completed
                                ? AppColors.primary
                                : AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            completed
                                ? Icons.check_rounded
                                : _cancelled
                                ? Icons.close_rounded
                                : Icons.remove_rounded,
                            size: 17,
                            color: completed
                                ? AppColors.onPrimary
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            detail.mission.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(clock, style: theme.textTheme.bodyMedium),
                        Text(status, style: theme.textTheme.bodyMedium),
                        if (focus != null)
                          Text('专注 $focus', style: theme.textTheme.bodyMedium),
                        if (evidence.isNotEmpty)
                          Text(evidence, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in images.take(3))
                      SizedBox(width: 104, child: _thumbnail(item)),
                    if (images.length > 3)
                      SizedBox(
                        height: 88,
                        child: Center(
                          child: Text(
                            '另有 ${images.length - 3} 张',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (detail.phase == MissionPhase.evidencePending) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _open(detail),
                    icon: const Icon(Icons.attach_file_rounded, size: 18),
                    label: const Text('打开记录并补交材料'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(Evidence item) {
    final key = item.attachmentStorageKey!;
    final future = _thumbnails.putIfAbsent(key, () async {
      await widget.service.initializeEvidenceImages();
      return widget.service.readEvidenceImage(key);
    });
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox(
            height: 88,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 88,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return EvidenceImagePreview(
          bytes: snapshot.data!,
          name: item.attachmentFileName ?? '图片材料',
          height: 88,
        );
      },
    );
  }
}
