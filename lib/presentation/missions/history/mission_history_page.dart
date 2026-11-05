import '../../../domain/entities/content_draft.dart';
import '../../../domain/entities/execution_event.dart';
import '../../records/record_scope.dart';
import '../../records/records_page.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_segmented_control.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/evidence.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/rules/execution_time_rules.dart';
import '../detail/mission_detail_page.dart';
import '../record/mission_record_workspace.dart';
import '../shared/mission_execution_display.dart';
import '../shared/mission_phase_display.dart';
import '../../attachments/attachment_image_loader.dart';

/// 执行历史与取消记录分开读取。没有 END 的任务通过“当前任务”恢复执行。
class MissionHistoryPage extends StatefulWidget {
  const MissionHistoryPage({
    super.key,
    required this.service,
    this.active = true,
  });
  final MissionService service;
  final bool active;
  @override
  State<MissionHistoryPage> createState() => _MissionHistoryPageState();
}

class _MissionHistoryPageState extends State<MissionHistoryPage>
    with WidgetsBindingObserver {
  late Future<List<MissionDetail>> _records;
  StreamSubscription<void>? _changes;
  bool _cancelled = false;
  bool _refreshWhenActive = false;
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
    _records = widget.active ? _load() : Future.value(const []);
    _refreshWhenActive = !widget.active;
    _changes = widget.service.changes.listen((_) => _refresh());
  }

  Future<List<MissionDetail>> _load() {
    final result = _cancelled
        ? widget.service.findCancelled()
        : widget.service.findFinishedAndReconcile();
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
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        if (_refreshWhenActive) _refresh();
      } else {
        _refreshWhenActive = true;
      }
    }
  }

  void _refresh() {
    if (!widget.active) {
      _refreshWhenActive = true;
      return;
    }
    _refreshWhenActive = false;
    if (mounted) {
      setState(() {
        _records = _load();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) _refresh();
  }

  Future<void> _open(MissionDetail detail) async {
    unawaited(
      openDetailPane<void>(
        context,
        label: _cancelled ? '任务详情' : '执行记录',
        builder: (_) => _cancelled
            ? MissionDetailPage.fromHistory(
                missionId: detail.mission.id,
                missionService: widget.service,
              )
            : MissionRecordWorkspace(detail: detail, service: widget.service),
      ).then((_) => _refresh()),
    );
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
          constraints: const BoxConstraints(
            maxWidth: AppLayout.dashboardMaxWidth,
          ),
          child: FutureBuilder<List<MissionDetail>>(
            // 切换分类时不复用另一类的旧快照；同类刷新保留已读记录。
            key: ValueKey(_cancelled),
            future: _records,
            builder: (context, snapshot) {
              final waiting =
                  snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData &&
                  _lastRecords == null;
              final failed = snapshot.hasError && _lastRecords == null;
              final records =
                  snapshot.data ?? _lastRecords ?? const <MissionDetail>[];
              if (snapshot.hasData) _lastRecords = snapshot.data;
              final entries = _historyEntries(records);
              return RefreshIndicator(
                onRefresh: () async {
                  _refresh();
                  try {
                    await _records;
                  } on Object {
                    // 错误在原页提示；结束下拉动画即可。
                  }
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: AppLayout.pagePadding(context),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          AppPageHeader(
                            title: '历史',
                            showTitle: false,
                            subtitle: Text(
                              waiting
                                  ? '读取中…'
                                  : failed
                                  ? '读取失败'
                                  : '${records.length} 条记录',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            action: RecordScope.maybeOf(context) == null
                                ? null
                                : const RecordsEntry(
                                    key: Key('history-records-entry'),
                                    label: '全部照片与文字记录',
                                    iconOnly: true,
                                  ),
                          ),
                          const SizedBox(height: AppLayout.spaceLg),
                          AppSegmentedControl<bool>(
                            options: const {false: '执行记录', true: '已取消'},
                            selected: _cancelled,
                            optionKey: (value) => value
                                ? const Key('history-cancelled')
                                : const Key('history-finished'),
                            onSelected: _selectCancelled,
                          ),
                          const SizedBox(height: AppLayout.spaceXl),
                          if (waiting)
                            const Padding(
                              padding: EdgeInsets.all(AppLayout.space3Xl),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (failed)
                            TextButton(
                              onPressed: _refresh,
                              child: const Text('记录读取失败，点击重试'),
                            )
                          else ...[
                            if (snapshot.hasError)
                              TextButton(
                                onPressed: _refresh,
                                child: const Text('刷新失败，当前保留上次读取的记录，点击重试'),
                              ),
                            if (records.isEmpty)
                              AppSectionCard(
                                key: const Key('history-empty-state'),
                                paperBackground: true,
                                child: AppEmptyState(
                                  horizontalWhenWide: true,
                                  title: _cancelled ? '还没有取消的任务' : '还没有执行结束的记录',
                                  asset:
                                      'assets/illustrations/history-pages.png',
                                  details: Text(
                                    _cancelled
                                        ? '取消的任务会保留在这里，方便回看。'
                                        : '每次结束后，在这里回看报告、专注与材料。',
                                  ),
                                ),
                              ),
                          ],
                        ]),
                      ),
                    ),
                    if (!waiting && !failed && entries.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppLayout.horizontalPadding(context),
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final entry = entries[index];
                            if (entry.day case final day?) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppLayout.spaceMd,
                                ),
                                child: Text(
                                  day,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              );
                            }
                            final record = entry.record!;
                            return KeyedSubtree(
                              key: ValueKey(record.mission.id),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppLayout.spaceMd,
                                ),
                                child: _recordCard(record),
                              ),
                            );
                          }, childCount: entries.length),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  /// 历史按实际发生时刻在设备上的日期回看；排期时区只解释原计划。
  DateTime _localRecordTime(MissionDetail detail) {
    if (!_cancelled && detail.effectiveOccurrenceDate != null) {
      return DateTime.parse(detail.effectiveOccurrenceDate!);
    }
    final instant = _cancelled
        ? detail.mission.cancelledAt!
        : detail.events.last.occurredAt;
    return instant.toLocal();
  }

  String _day(MissionDetail detail) {
    final local = _localRecordTime(detail);
    return '${local.year}年${local.month}月${local.day}日';
  }

  /// 一次遍历形成日期标题和记录项，列表按需构建可见范围内的卡片。
  List<_HistoryEntry> _historyEntries(List<MissionDetail> records) {
    final byDay = <String, List<MissionDetail>>{};
    for (final record in records) {
      (byDay[_day(record)] ??= []).add(record);
    }
    return [
      for (final entry in byDay.entries) ...[
        _HistoryEntry.day(entry.key),
        for (final record in entry.value) _HistoryEntry.record(record),
      ],
    ];
  }

  Widget _recordCard(MissionDetail detail) {
    final theme = Theme.of(context);
    final local = _localRecordTime(detail);
    final claimed = detail.effectiveUserReport;
    final measuredInstant =
        detail.events
            .where((e) => e.type == ExecutionEventType.stop)
            .firstOrNull
            ?.occurredAt ??
        (detail.events.isEmpty ? null : detail.events.last.occurredAt);
    final displayTime =
        claimed?.actualStart?.toLocal() ?? measuredInstant?.toLocal() ?? local;
    final retrospective = detail.completionReport?.isRetrospective == true;
    final clock =
        retrospective || (claimed != null && claimed.actualStart == null)
        ? '具体时段未知'
        : '${displayTime.hour.toString().padLeft(2, '0')}:${displayTime.minute.toString().padLeft(2, '0')}';
    // 是否报告完成的判定口径统一走 MissionDetail 的派生属性。
    final completed = !_cancelled && detail.endReportedCompleted;
    final images = _cancelled
        ? <Evidence>[]
        : detail.effectiveEvidence
              .where((item) => item.type == ContentType.image)
              .toList();
    final status = _cancelled
        ? '已取消'
        : completed
        ? '报告完成'
        : '报告未完成';
    final focus =
        _cancelled ||
            !detail.events.any((e) => e.type == ExecutionEventType.start)
        ? null
        : focusDuration(
            calculateExecutionTimes(
              detail.events,
              detail.events.last.occurredAt,
              schedule: detail.schedule,
            ).focus,
          );
    final evidence = _cancelled ? '' : evidenceStatusLabel(detail);
    return Padding(
      key: ValueKey('history-record-${detail.mission.id}'),
      padding: const EdgeInsets.only(bottom: AppLayout.spaceMd),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusXl),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppLayout.spaceLg,
            AppLayout.spaceMd,
            AppLayout.spaceLg,
            AppLayout.spaceMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => _open(detail),
                borderRadius: BorderRadius.circular(AppLayout.radiusMd),
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
                            size: AppLayout.iconSm,
                            color: completed
                                ? AppColors.onPrimary
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppLayout.spaceMd),
                        Expanded(
                          child: Text(
                            detail.mission.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceSm),
                    Wrap(
                      spacing: AppLayout.spaceMd,
                      runSpacing: AppLayout.spaceXs,
                      children: [
                        Text(clock, style: theme.textTheme.bodyMedium),
                        Text(status, style: theme.textTheme.bodyMedium),
                        if (focus != null)
                          Text(
                            '应用计时 $focus',
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (claimed?.duration != null)
                          Text(
                            '自报 ${claimed!.duration!.inMinutes} 分钟',
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (evidence.isNotEmpty)
                          Text(evidence, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: AppLayout.spaceMd),
                Wrap(
                  spacing: AppLayout.spaceSm,
                  runSpacing: AppLayout.spaceSm,
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
                const SizedBox(height: AppLayout.spaceSm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _open(detail),
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      size: AppLayout.iconSm,
                    ),
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
    final future =
        _thumbnails.remove(key) ??
        () async {
          await widget.service.initializeEvidenceImages();
          return widget.service.readEvidenceImage(key);
        }();
    _thumbnails[key] = future;
    while (_thumbnails.length > 36) {
      _thumbnails.remove(_thumbnails.keys.first);
    }
    return AttachmentImageLoader(
      future: future,
      name: item.attachmentFileName ?? '图片材料',
      height: 88,
      onRetry: () => setState(() => _thumbnails.remove(key)),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry.day(this.day) : record = null;
  const _HistoryEntry.record(this.record) : day = null;

  final String? day;
  final MissionDetail? record;
}
