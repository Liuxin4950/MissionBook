part of 'records_page.dart';

/// 目标/节点内的真实记录入口；空集合不占位，读取失败保留重试。
class RelatedRecordsEntry extends StatefulWidget {
  const RelatedRecordsEntry({super.key, required this.goalId, this.nodeId});
  final String goalId;
  final String? nodeId;

  @override
  State<RelatedRecordsEntry> createState() => _RelatedRecordsEntryState();
}

class _RelatedRecordsEntryState extends State<RelatedRecordsEntry> {
  RecordService? _service;
  Future<RecordPage>? _records;
  StreamSubscription<void>? _changes;

  void _load() {
    _records = _service?.readRecords(
      goalId: widget.goalId,
      nodeId: widget.nodeId,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = RecordScope.maybeOf(context)?.service;
    if (identical(service, _service)) return;
    unawaited(_changes?.cancel());
    _service = service;
    _load();
    _changes = service?.changes.listen((_) {
      if (mounted) setState(_load);
    });
  }

  @override
  void didUpdateWidget(RelatedRecordsEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goalId != widget.goalId ||
        oldWidget.nodeId != widget.nodeId) {
      _load();
    }
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _open() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RecordsPage(goalId: widget.goalId, nodeId: widget.nodeId),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_service == null) return const SizedBox.shrink();
    return FutureBuilder<RecordPage>(
      // 换归属后不能短暂展示上一节点的记录数量。
      key: ValueKey((widget.goalId, widget.nodeId, _service)),
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton.icon(
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
            label: const Text('记录读取失败，点击重试'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.total == 0) {
          return const SizedBox.shrink();
        }
        return AppSettingsRow(
          icon: Icons.photo_library_outlined,
          title:
              '${widget.nodeId == null ? '目标记录' : '节点记录'} · ${snapshot.data!.total}',
          subtitle: widget.nodeId == null ? '包含各节点的记录' : null,
          onTap: _open,
        );
      },
    );
  }
}

class RecordsEntry extends StatelessWidget {
  const RecordsEntry({
    super.key,
    this.goalId,
    this.nodeId,
    this.missionId,
    this.date,
    this.label = '查看记录',
    this.iconOnly = false,
    this.onReturn,
  });
  final String? goalId, nodeId, missionId, date;
  final String label;
  final bool iconOnly; // 主导航页顶栏只保留图标，名称由 Tooltip 与读屏提供。
  final VoidCallback? onReturn;
  @override
  Widget build(BuildContext context) {
    if (RecordScope.maybeOf(context) == null) return const SizedBox.shrink();
    Future<void> open() async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RecordsPage(
            goalId: goalId,
            nodeId: nodeId,
            missionId: missionId,
            date: date,
          ),
        ),
      );
      if (context.mounted) onReturn?.call();
    }

    if (iconOnly) {
      return IconButton(
        onPressed: open,
        tooltip: label,
        icon: const Icon(Icons.photo_library_outlined),
      );
    }
    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: AppSettingsRow(
        onTap: open,
        icon: Icons.photo_library_outlined,
        title: missionId == null ? label : '查看材料来源记录',
      ),
    );
  }
}

/// 记录图片的统一读取壳：缓存 Future，失败时可重新读取同一附件。
class _RecordImage extends StatefulWidget {
  const _RecordImage({
    required this.service,
    required this.storageKey,
    required this.name,
    required this.width,
    required this.height,
    this.compact = false,
  });
  final RecordService service;
  final String storageKey;
  final String name;
  final double width;
  final double height;
  final bool compact;

  @override
  State<_RecordImage> createState() => _RecordImageState();
}

class _RecordImageState extends State<_RecordImage> {
  late Future<Uint8List> _image;
  Future<Uint8List> _read() => widget.service.readAttachment(widget.storageKey);

  @override
  void initState() {
    super.initState();
    _image = _read();
  }

  @override
  void didUpdateWidget(_RecordImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageKey != widget.storageKey ||
        oldWidget.service != widget.service) {
      _image = _read();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: AttachmentImageLoader(
      future: _image,
      name: widget.name,
      height: widget.height,
      compact: widget.compact,
      onRetry: () => setState(() {
        _image = _read();
      }),
    ),
  );
}

/// 今天页展示真实当日记录缩略图，仍复用同一记录详情和列表。
class DailyRecordsStrip extends StatefulWidget {
  const DailyRecordsStrip({super.key, required this.date});
  final String date;
  @override
  State<DailyRecordsStrip> createState() => _DailyRecordsStripState();
}

class _DailyRecordsStripState extends State<DailyRecordsStrip> {
  Future<RecordPage>? _data;
  StreamSubscription<void>? _changes;
  void load() {
    if (mounted) {
      setState(() {
        _data = RecordScope.maybeOf(
          context,
        )?.service.readRecords(date: widget.date);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) {
      load();
      _changes ??= RecordScope.maybeOf(
        context,
      )?.service.changes.listen((_) => load());
    }
  }

  @override
  void didUpdateWidget(DailyRecordsStrip old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) load();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = RecordScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return FutureBuilder<RecordPage>(
      key: ValueKey(widget.date),
      future: _data,
      builder: (c, s) {
        if (s.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: AppLayout.spaceSm),
            child: TextButton(
              onPressed: load,
              child: const Text('当日记录读取失败，点击重试'),
            ),
          );
        }
        final items = s.data?.items ?? [];
        final total = s.data?.total ?? 0;
        // 没有记录时不占位置，也不显示一个空入口。
        if (!s.hasData || total == 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppLayout.spaceMd),
          child: AppSectionCard(
            padding: const EdgeInsets.all(AppLayout.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '当日记录 · $total 条',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => RecordsPage(date: widget.date),
                        ),
                      ),
                      child: const Text('查看全部'),
                    ),
                  ],
                ),
                for (final r in items.take(3))
                  InkWell(
                    borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => RecordDetail(id: r.id)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppLayout.spaceSm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (r.type == ContentType.image) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppLayout.radiusSm,
                              ),
                              child: _RecordImage(
                                service: scope.service,
                                storageKey: r.attachmentStorageKey!,
                                name: r.attachmentFileName ?? '记录图片',
                                width: 80,
                                height: 64,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: AppLayout.spaceMd),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.content?.trim().isNotEmpty == true
                                      ? r.content!
                                      : (r.attachmentFileName ?? '记录'),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: AppLayout.spaceXs),
                                Text(
                                  '${r.occurredAt.toLocal().hour.toString().padLeft(2, '0')}:${r.occurredAt.toLocal().minute.toString().padLeft(2, '0')}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: AppLayout.iconSm,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
