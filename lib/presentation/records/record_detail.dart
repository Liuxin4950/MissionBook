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

  @override
  Widget build(BuildContext context) {
    final scope = RecordScope.maybeOf(context)!;
    return Scaffold(
      appBar: const AppTopBar(title: '记录详情'),
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
                return ListView(
                  padding: const EdgeInsets.all(AppLayout.spaceXl),
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        RecordDraft draft;
                        try {
                          draft = await scope.service.readDraft(widget.id);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  userErrorMessage(e, fallback: '记录读取失败，请重试'),
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        if (!context.mounted) return;
                        final input = TextEditingController(
                          text: draft.content ?? '',
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
                              draft.content,
                              result,
                            );
                            load();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    userErrorMessage(
                                      e,
                                      fallback: '记录操作未完成，请刷新后重试',
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('修改文字 / 说明'),
                    ),
                    Text('发生：${r.occurredAt.toLocal()}'),
                    Text('保存：${r.createdAt.toLocal()}'),
                    Text(
                      r.materialMissionId == null
                          ? '可设置归属或用作任务材料'
                          : '任务已保留提交时的材料，修改记录不会改写材料',
                    ),
                    Text(
                      '归属：${r.goalTitle ?? '独立记录'}${r.nodeTitle == null ? '' : ' / ${r.nodeTitle}'}',
                    ),
                    if (r.attachmentFileName != null)
                      Text('附件：${r.attachmentFileName}'),
                    TextButton(
                      onPressed: () async {
                        final choice = await chooseRecordOwnership(context);
                        if (choice == null) return;
                        try {
                          await scope.service.setOwnership(
                            widget.id,
                            goalId: choice['goal'],
                            nodeId: choice['node'],
                          );
                          load();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  userErrorMessage(e, fallback: '归属未保存，请重试'),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('设置记录归属'),
                    ),
                    if (r.materialMissionId != null)
                      Text('已用于任务：${r.materialMissionTitle ?? '原任务'}'),
                    if (r.materialMissionId == null)
                      TextButton(
                        onPressed: () async {
                          final choice = await chooseRecordMaterialTask(
                            context,
                          );
                          if (choice == null || !context.mounted) return;
                          try {
                            final draft = await scope.service.readDraft(
                              widget.id,
                            );
                            if (!context.mounted) return;
                            final confirmed = await AppConfirmDialog.show(
                              context: context,
                              title: '用作「${choice['title']}」的材料？',
                              message:
                                  '${String.fromCharCodes((draft.content ?? draft.attachmentFileName ?? '当前记录').runes.take(300))}${(draft.content?.length ?? 0) > 300 ? '…（内容预览）' : ''}\n\n任务将保留此次内容，之后修改或删除记录不会改变已提交材料。',
                              confirmText: '提交材料',
                            );
                            if (!confirmed) return;
                            await scope.service.useAsMaterial(
                              widget.id,
                              choice['mission']!,
                              expected: draft,
                            );
                            load();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    userErrorMessage(
                                      e,
                                      fallback: '材料未提交，请刷新重试',
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('用作任务材料'),
                      ),
                    if (r.type == ContentType.image)
                      _RecordImage(
                        service: scope.service,
                        storageKey: r.attachmentStorageKey!,
                        name: r.attachmentFileName ?? '记录图片',
                        width: double.infinity,
                        height: 220,
                      ),
                    SelectableText(r.content ?? ''),
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
          ),
        ),
      ),
    );
  }
}

/// 小型入口复用于今天、历史、目标与节点；点击后进入同一列表。
