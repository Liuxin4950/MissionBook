part of 'records_page.dart';

class RecordDetail extends StatefulWidget {
  const RecordDetail({super.key, required this.id});
  final String id;
  @override
  State<RecordDetail> createState() => _RecordDetailState();
}

class _RecordDetailState extends State<RecordDetail> {
  Future<Map<String, Object?>>? _data;
  int _contentOffset = 0;
  void load() => setState(() {
    _data = RecordScope.maybeOf(context)!.service.queryRecords(
      id: widget.id,
      content: true,
      contentOffset: _contentOffset,
    );
  });
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) load();
  }

  @override
  Widget build(BuildContext context) {
    final scope = RecordScope.maybeOf(context)!;
    return Scaffold(
      appBar: const AppTopBar(title: '记录详情'),
      body: FutureBuilder<Map<String, Object?>>(
        future: _data,
        builder: (c, s) {
          if (s.hasError) {
            return Center(
              child: AppEmptyState(
                title: '记录读取失败',
                details: const Text('请稍后重试。'),
                actions: OutlinedButton.icon(
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ),
            );
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = (s.data!['items'] as List<Map<String, Object?>>).first;
          return ListView(
            padding: const EdgeInsets.all(AppLayout.spaceXl),
            children: [
              if (r['type'] == 'IMAGE')
                FutureBuilder<Uint8List>(
                  future: scope.service.missions.readEvidenceImage(
                    r['attachment_storage_key'] as String,
                  ),
                  builder: (c, i) => i.hasData
                      ? Image.memory(i.data!)
                      : Text(i.hasError ? '图片读取失败' : '正在读取图片…'),
                ),
              SelectableText(r['content'] as String? ?? ''),
              Wrap(
                children: [
                  if (_contentOffset > 0)
                    TextButton(
                      onPressed: () {
                        _contentOffset = (_contentOffset - 6000).clamp(
                          0,
                          1 << 30,
                        );
                        load();
                      },
                      child: const Text('上一段'),
                    ),
                  if (r['nextContentOffset'] != null)
                    TextButton(
                      onPressed: () {
                        _contentOffset = r['nextContentOffset'] as int;
                        load();
                      },
                      child: const Text('下一段'),
                    ),
                ],
              ),
              if (r['mission_id'] == null &&
                  r['contentTruncated'] != true &&
                  _contentOffset == 0)
                OutlinedButton(
                  onPressed: () async {
                    final input = TextEditingController(
                      text: r['content'] as String? ?? '',
                    );
                    final route = DialogRoute<String>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('修改记录文字'),
                        content: TextField(
                          controller: input,
                          minLines: 3,
                          maxLines: 10,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, input.text),
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    );
                    final result = await Navigator.of(
                      context,
                    ).push<String>(route);
                    await route.completed;
                    input.dispose();
                    if (result != null) {
                      try {
                        await scope.service.updateContent(
                          widget.id,
                          r['content'] as String?,
                          result,
                        );
                        load();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    }
                  },
                  child: const Text('修改文字 / 说明'),
                ),
              Text(
                '发生：${DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int).toLocal()}',
              ),
              Text(
                '保存：${DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int).toLocal()}',
              ),
              Text(
                r['mission_id'] == null ? '可补关联到目标、节点或任务' : '已成为任务正式材料，原引用保留',
              ),
              if (r['mission_id'] == null)
                TextButton(
                  onPressed: () async {
                    final choice = await chooseRecordAssociation(context);
                    if (choice != null) {
                      try {
                        await scope.service.link(
                          widget.id,
                          goalId: choice['goal'],
                          nodeId: choice['node'],
                          missionId: choice['mission'],
                        );
                        load();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    }
                  },
                  child: const Text('补关联'),
                ),
              const Divider(),
              AppSectionCard(
                padding: EdgeInsets.zero,
                child: AnalysisPanel(
                  scope: AnalysisScope.record,
                  id: widget.id,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 小型入口复用于今天、历史、目标与节点；点击后进入同一列表。
