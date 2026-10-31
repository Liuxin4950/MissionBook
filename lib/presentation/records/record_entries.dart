part of 'records_page.dart';

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
        title: label,
      ),
    );
  }
}

/// 今天页展示真实当日记录缩略图，仍复用同一记录详情和列表。
class DailyRecordsStrip extends StatefulWidget {
  const DailyRecordsStrip({super.key, required this.date});
  final String date;
  @override
  State<DailyRecordsStrip> createState() => _DailyRecordsStripState();
}

class _DailyRecordsStripState extends State<DailyRecordsStrip> {
  Future<Map<String, Object?>>? _data;
  StreamSubscription<void>? _changes;
  void load() {
    if (mounted) {
      setState(() {
        _data = RecordScope.maybeOf(
          context,
        )?.service.queryRecords(date: widget.date);
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
      )?.service.missions.changes.listen((_) => load());
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
    return FutureBuilder<Map<String, Object?>>(
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
        final items = s.data?['items'] as List<Map<String, Object?>>? ?? [];
        final total = s.data?['total'] as int? ?? 0;
        // 没有记录时不占位置，也不显示一个空入口。
        if (!s.hasData || total == 0) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordsEntry(
              date: widget.date,
              label: '当日记录 · ${s.data?['total'] ?? 0} 条',
            ),
            Wrap(
              spacing: AppLayout.spaceSm,
              runSpacing: AppLayout.spaceSm,
              children: [
                for (final r in items.take(3))
                  InkWell(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => RecordDetail(id: r['id'] as String),
                      ),
                    ),
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (r['type'] == 'IMAGE')
                            FutureBuilder<Uint8List>(
                              future: scope.service.missions.readEvidenceImage(
                                r['attachment_storage_key'] as String,
                              ),
                              builder: (c, i) => i.hasData
                                  ? Image.memory(
                                      i.data!,
                                      height: 80,
                                      width: 120,
                                      fit: BoxFit.cover,
                                    )
                                  : const SizedBox(
                                      height: 80,
                                      child: Icon(Icons.image_outlined),
                                    ),
                            ),
                          Text(
                            r['content'] as String? ??
                                r['attachment_file_name'] as String? ??
                                '记录',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
