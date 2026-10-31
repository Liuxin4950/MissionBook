import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_expansion.dart';
import '../widgets/app_confirm_dialog.dart';
import '../../core/theme/app_layout.dart';
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
  bool _requesting = false;
  String? _requestError;
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
    if (old.id != widget.id || old.scope != widget.scope) {
      _requesting = false;
      _requestError = null;
      load();
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> request({bool closing = false}) async {
    if (_requesting) return;
    final id = widget.id, targetScope = widget.scope;
    if (closing) {
      final confirmed = await AppConfirmDialog.show(
        context: context,
        title: '生成阶段收尾总结？',
        message: '将汇总当前事实和未确认部分，节点状态由你决定。',
        confirmText: '确认收尾总结',
      );
      if (!confirmed ||
          !mounted ||
          widget.id != id ||
          widget.scope != targetScope) {
        return;
      }
    }
    setState(() {
      _requesting = true;
      _requestError = null;
    });
    try {
      final analysis = RecordScope.maybeOf(context)!.analysis;
      await analysis.store.retry(targetScope, id, closing: closing);
      analysis.wake();
      if (mounted && widget.id == id && widget.scope == targetScope) load();
    } catch (_) {
      if (mounted && widget.id == id && widget.scope == targetScope) {
        setState(() => _requestError = '总结请求未能保存，请重试');
      }
    } finally {
      if (mounted && widget.id == id && widget.scope == targetScope) {
        setState(() => _requesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = RecordScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return FutureBuilder<Map<String, Object?>>(
      future: _data,
      builder: (c, s) {
        final a = s.data;
        final missing = a?['content'] == null;
        final busy =
            _requesting ||
            a?['state'] == 'running' ||
            (a?['manual'] == true && a?['state'] == 'pending');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppExpansionTile(
              title: Text(
                widget.scope == 'mission'
                    ? '任务评价'
                    : widget.scope == 'record'
                    ? '记录摘要'
                    : widget.scope == 'node'
                    ? '节点摘要'
                    : '目标摘要',
              ),
              subtitle: Text(
                '${!scope.analysis.automaticFor(widget.scope) && a?['manual'] != true && a?['state'] != 'ready' ? '自动总结已关闭 · 可手动生成' : switch (a?['state']) {
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
                    if (!missing)
                      OutlinedButton(
                        onPressed: busy ? null : request,
                        child: const Text('更新总结'),
                      ),
                    if (widget.scope == 'node')
                      OutlinedButton(
                        onPressed: busy ? null : () => request(closing: true),
                        child: const Text('阶段收尾总结'),
                      ),
                  ],
                ),
              ],
            ),
            if (_requestError != null)
              Text(
                _requestError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (missing)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.spaceLg,
                  0,
                  AppLayout.spaceLg,
                  AppLayout.spaceLg,
                ),
                child: OutlinedButton.icon(
                  key: Key('generate-summary-${widget.scope}-${widget.id}'),
                  onPressed: busy ? null : request,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(busy ? '等待总结…' : '生成总结'),
                ),
              ),
          ],
        );
      },
    );
  }
}
