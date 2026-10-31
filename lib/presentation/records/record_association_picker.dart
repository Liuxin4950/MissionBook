part of 'records_page.dart';

class _AssociationDialog extends StatefulWidget {
  const _AssociationDialog();
  @override
  State<_AssociationDialog> createState() => _AssociationDialogState();
}

class _AssociationDialogState extends State<_AssociationDialog> {
  String _kind = 'mission', _search = '';
  int _offset = 0;
  Future<Map<String, Object?>>? _data;
  void load() {
    setState(() {
      _data = RecordScope.maybeOf(
        context,
      )!.service.associationChoices(_kind, search: _search, offset: _offset);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= RecordScope.maybeOf(context)!.service.associationChoices(_kind);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(AppLayout.spaceXxl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
    ),
    title: const Text('关联到'),
    content: SizedBox(
      width: 440,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 440),
        child: Column(
          children: [
            AppDropdownFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: '关联类型'),
              items: const [
                DropdownMenuItem(value: 'goal', child: Text('目标')),
                DropdownMenuItem(value: 'node', child: Text('目标节点')),
                DropdownMenuItem(value: 'mission', child: Text('任务材料')),
              ],
              onChanged: (v) {
                if (v == null) return;
                _kind = v;
                _offset = 0;
                load();
              },
            ),
            const SizedBox(height: AppLayout.spaceMd),
            TextField(
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(labelText: '搜索名称'),
              onChanged: (v) {
                _search = v;
                _offset = 0;
                load();
              },
            ),
            Expanded(
              child: FutureBuilder<Map<String, Object?>>(
                future: _data,
                builder: (c, s) {
                  if (s.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('关联选项读取失败'),
                          TextButton(onPressed: load, child: const Text('重试')),
                        ],
                      ),
                    );
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final d = s.data!;
                  return ListView(
                    children: [
                      for (final e in d['items'] as List<Map<String, Object?>>)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e['title'] as String),
                          subtitle: Text(e['id'] as String),
                          onTap: () => Navigator.pop(context, {
                            _kind: e['id'] as String,
                            'title': e['title'] as String,
                          }),
                        ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _offset == 0
                                ? null
                                : () {
                                    _offset -= 20;
                                    load();
                                  },
                            child: const Text('上一页'),
                          ),
                          TextButton(
                            onPressed: d['nextOffset'] == null
                                ? null
                                : () {
                                    _offset = d['nextOffset'] as int;
                                    load();
                                  },
                            child: const Text('下一页'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, <String, String>{}),
        child: const Text('独立记录'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
    ],
  );
}
