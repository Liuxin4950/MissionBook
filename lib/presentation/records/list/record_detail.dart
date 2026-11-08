part of 'records_page.dart';

class RecordDetail extends StatefulWidget {
  const RecordDetail({super.key, required this.id});
  final String id;
  @override
  State<RecordDetail> createState() => _RecordDetailState();
}

class _RecordDetailState extends State<RecordDetail> {
  Future<RecordPage>? _data;
  int _contentOffset = 0;

  void load() {
    if (!mounted) return;
    setState(() {
      _data = RecordScope.maybeOf(context)!.service.readRecords(
        id: widget.id,
        content: true,
        contentOffset: _contentOffset,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) load();
  }

  Future<void> _editRecord(RecordService service) async {
    RecordDraft draft;
    try {
      draft = await service.readDraft(widget.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userErrorMessage(e, fallback: '记录读取失败，请重试'))),
        );
      }
      return;
    }
    if (!mounted) return;
    final input = TextEditingController(text: draft.content ?? '');
    final route = DialogRoute<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('修改记录文字'),
        content: TextField(controller: input, minLines: 3, maxLines: 10),
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
    final result = await Navigator.of(context).push<String>(route);
    await route.completed;
    input.dispose();
    if (result == null || !mounted) return;
    try {
      await service.updateContent(widget.id, draft.content, result);
      load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userErrorMessage(e, fallback: '记录操作未完成，请刷新后重试')),
          ),
        );
      }
    }
  }

  Future<void> _setRecordOwnership(RecordService service) async {
    final choice = await chooseRecordOwnership(context);
    if (choice == null || !mounted) return;
    try {
      await service.setOwnership(
        widget.id,
        goalId: choice['goal'],
        nodeId: choice['node'],
      );
      load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userErrorMessage(e, fallback: '归属未保存，请重试'))),
        );
      }
    }
  }

  Future<void> _useRecordAsMaterial(RecordService service) async {
    final choice = await chooseRecordMaterialTask(context);
    if (choice == null || !mounted) return;
    try {
      final draft = await service.readDraft(widget.id);
      if (!mounted) return;
      final confirmed = await AppConfirmDialog.show(
        context: context,
        title: '用作「${choice['title']}」的材料？',
        message:
            '${String.fromCharCodes((draft.content ?? draft.attachmentFileName ?? '当前记录').runes.take(300))}${(draft.content?.length ?? 0) > 300 ? '…（内容预览）' : ''}\n\n任务将保留此次内容，之后修改或删除记录不会改变已提交材料。',
        confirmText: '提交材料',
      );
      if (!confirmed || !mounted) return;
      await service.useAsMaterial(
        widget.id,
        choice['mission']!,
        expected: draft,
      );
      load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userErrorMessage(e, fallback: '材料未提交，请刷新重试'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = RecordScope.maybeOf(context)!;
    return Scaffold(
      appBar: AppTopBar(
        title: '记录详情',
        actions: [
          IconButton(
            tooltip: '编辑记录',
            onPressed: () => _editRecord(scope.service),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            popUpAnimationStyle: AppMotion.overlayStyle(context),
            tooltip: '更多记录操作',
            onSelected: (_) => _setRecordOwnership(scope.service),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'ownership', child: Text('设置记录归属')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
            child: FutureBuilder<RecordPage>(
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
                final items = s.data!.items;
                if (items.isEmpty) {
                  return const Center(
                    child: AppEmptyState(
                      title: '记录不存在或已删除',
                      details: Text('请返回记录列表后重试。'),
                    ),
                  );
                }
                final r = items.first;
                final occurredAt = r.occurredAt.toLocal();
                final localizations = MaterialLocalizations.of(context);
                return ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.horizontalPadding(context),
                    vertical: AppLayout.spaceLg,
                  ),
                  children: [
                    Wrap(
                      spacing: AppLayout.spaceMd,
                      runSpacing: AppLayout.spaceXs,
                      children: [
                        Text(
                          localizations.formatMediumDate(occurredAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          localizations.formatTimeOfDay(
                            TimeOfDay.fromDateTime(occurredAt),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${r.goalTitle ?? '独立记录'}${r.nodeTitle == null ? '' : ' / ${r.nodeTitle}'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (r.materialMissionId != null) ...[
                      const SizedBox(height: AppLayout.spaceSm),
                      Text(
                        '已提交到「${r.materialMissionTitle ?? '原任务'}」的材料内容保持不变',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (r.materialMissionId == null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _useRecordAsMaterial(scope.service),
                          icon: const Icon(Icons.task_alt_outlined),
                          label: const Text('用作任务材料'),
                        ),
                      ),
                    if (r.type == ContentType.image) ...[
                      const SizedBox(height: AppLayout.spaceLg),
                    ] else ...[
                      const SizedBox(height: AppLayout.spaceXl),
                    ],
                    if (r.type == ContentType.image)
                      _RecordImage(
                        service: scope.service,
                        storageKey: r.attachmentStorageKey!,
                        name: r.attachmentFileName ?? '记录图片',
                        width: double.infinity,
                        height: 220,
                      ),
                    SelectableText(
                      r.content ?? '',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
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
                        if (r.nextContentOffset != null)
                          TextButton(
                            onPressed: () {
                              _contentOffset = r.nextContentOffset!;
                              load();
                            },
                            child: const Text('下一段'),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 小型入口复用于今天、历史、目标与节点；点击后进入同一列表。
