import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_expansion.dart';
import 'record_scope.dart';

class AnalysisPanel extends StatefulWidget {
  const AnalysisPanel({super.key, required this.scope, required this.id});
  final String scope, id;
  @override
  State<AnalysisPanel> createState() => _AnalysisPanelState();
}

class _AnalysisPanelState extends State<AnalysisPanel> {
  Future<Map<String, Object?>>? _data;
  StreamSubscription<void>? _changes;
  void load() {
    if (mounted) {
      setState(() {
        _data = RecordScope.maybeOf(
          context,
        )?.service.repository.analysis(widget.scope, widget.id);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) {
      load();
      _changes = RecordScope.maybeOf(
        context,
      )?.analysis.changes.listen((_) => load());
    }
  }

  @override
  void didUpdateWidget(AnalysisPanel old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.scope != widget.scope) load();
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
        final a = s.data;
        return AppExpansionTile(
          title: Text(
            widget.scope == 'mission'
                ? '任务评价'
                : widget.scope == 'node'
                ? '节点摘要'
                : '目标摘要',
          ),
          subtitle: Text(
            '${switch (a?['state']) {
              'ready' => '已更新',
              'pending' => '待分析',
              'running' => '正在分析',
              'failed' => '分析失败',
              'blocked' => '需要配置模型能力',
              _ => '尚未分析',
            }}${a?['stale'] == true ? ' · 来源已变化' : ''}',
          ),
          children: [
            if (s.hasError) const Text('摘要读取失败'),
            if (a?['content'] != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(a!['content'] as String),
              ),
            if (a?['error'] != null) Text(a!['error'] as String),
            Text('已覆盖直接子项：${a?['coverage'] ?? 0}'),
            Wrap(
              children: [
                TextButton(
                  onPressed: () async {
                    await scope.analysis.store.retry(widget.scope, widget.id);
                    scope.analysis.wake();
                    load();
                  },
                  child: const Text('生成 / 更新摘要'),
                ),
                if (widget.scope == 'node')
                  TextButton(
                    onPressed: () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('生成阶段收尾总结？'),
                          content: const Text('将汇总当前事实和未确认部分，节点状态由你决定。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('确认收尾总结'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) {
                        await scope.analysis.store.retry(
                          'node',
                          widget.id,
                          closing: true,
                        );
                        scope.analysis.wake();
                        load();
                      }
                    },
                    child: const Text('阶段收尾总结'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
