import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_dropdown_form_field.dart';
import 'record_scope.dart';

/// 用户能检查来源、纠正和忘记记忆，而不是把助手日记做成不可见黑箱。
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});
  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  Future<Map<String, Object?>>? _data;
  int _offset = 0;
  void load() => setState(() {
    _data = RecordScope.maybeOf(
      context,
    )!.memory!.query(offset: _offset, includeExpired: true);
  });
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) load();
  }

  Future<void> edit([Map<String, Object?>? e]) async {
    final content = TextEditingController(text: e?['content'] as String? ?? '');
    final source = TextEditingController(
      text: e?['source'] as String? ?? '用户手动记录',
    );
    final expiry = TextEditingController(
      text: e?['expires_at'] == null
          ? ''
          : DateTime.fromMillisecondsSinceEpoch(
              e!['expires_at'] as int,
            ).toIso8601String(),
    );
    var kind = e?['kind'] as String? ?? 'fact';
    String? error;
    if (!mounted) return;
    final route = DialogRoute<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(e == null ? '添加记忆' : '更正记忆'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: content,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: '内容'),
                  ),
                  const SizedBox(height: AppLayout.spaceMd),
                  AppDropdownFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: '类型'),
                    items: const [
                      DropdownMenuItem(value: 'preference', child: Text('偏好')),
                      DropdownMenuItem(value: 'fact', child: Text('明确事实')),
                      DropdownMenuItem(
                        value: 'constraint',
                        child: Text('临时约束'),
                      ),
                      DropdownMenuItem(
                        value: 'observation',
                        child: Text('待验证观察'),
                      ),
                    ],
                    onChanged: (v) => set(() => kind = v!),
                  ),
                  const SizedBox(height: AppLayout.spaceMd),
                  TextField(
                    controller: source,
                    decoration: const InputDecoration(labelText: '来源'),
                  ),
                  const SizedBox(height: AppLayout.spaceMd),
                  TextField(
                    controller: expiry,
                    decoration: const InputDecoration(
                      labelText: '有效期，可空；ISO8601日期时刻',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: AppLayout.spaceSm),
                    Text(
                      error!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await RecordScope.maybeOf(context)!.memory!.save({
                    'id': e?['id'] ?? const Uuid().v4(),
                    'goalId': e?['goal_id'],
                    'content': content.text,
                    'kind': kind,
                    'certainty': kind == 'observation'
                        ? 'unverified'
                        : 'stated',
                    'source': source.text,
                    'conflictKey': e?['conflict_key'] ?? content.text,
                    'expiresAt': expiry.text.trim().isEmpty
                        ? null
                        : DateTime.parse(
                            expiry.text.trim(),
                          ).millisecondsSinceEpoch,
                  }, userEdited: true);
                  if (c.mounted) Navigator.pop(c);
                  if (mounted) load();
                } catch (err) {
                  set(() => error = '$err');
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    await Navigator.of(context).push<void>(route);
    await route.completed;
    content.dispose();
    source.dispose();
    expiry.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('助手记忆'),
      actions: [
        IconButton(
          onPressed: edit,
          tooltip: '添加记忆',
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, Object?>>(
      future: _data,
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('读取失败：${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final d = s.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('记忆保存偏好、明确事实与约束。任务进度来自任务事实和分层摘要；过期约束不再自动载入。'),
            if (d['extraction'] is Map)
              Text('等待记忆提取：${(d['extraction'] as Map)['pending']} 条'),
            if (d['extraction'] is Map &&
                ((d['extraction'] as Map)['retriable'] as List).isNotEmpty)
              TextButton(
                onPressed: () async {
                  final scope = RecordScope.maybeOf(context)!;
                  for (final job
                      in (d['extraction'] as Map)['retriable'] as List) {
                    await scope.analysis.store.retry(
                      'memory',
                      job['target_id'] as String,
                    );
                  }
                  scope.analysis.wake();
                  load();
                },
                child: const Text('重试失败的记忆提取（本页最多20条）'),
              ),
            for (final e in d['items'] as List<Map<String, Object?>>)
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(e['content'] as String),
                      subtitle: Text(
                        '性质：${e['certainty'] == 'stated' ? '用户明确陈述' : '待验证'} · ${switch (e['kind']) {
                          'preference' => '偏好',
                          'constraint' => '临时约束',
                          'observation' => '观察',
                          _ => '事实',
                        }}${e['user_edited'] == 1 ? ' · 用户已修订' : ''}\n来源：${e['source']}${e['sourceText'] == null ? '' : '\n来源原话：${e['sourceText']}'}\n更新：${DateTime.fromMillisecondsSinceEpoch(e['updated_at'] as int).toLocal()}${e['expires_at'] == null ? '' : '\n到期：${DateTime.fromMillisecondsSinceEpoch(e['expires_at'] as int).toLocal()}'}${e['goal_id'] == null ? '' : '\n目标：${e['goal_id']}'}',
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => edit(e),
                          child: const Text('更正'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('忘记这条记忆？'),
                                content: Text(e['content'] as String),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('忘记'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              if (!context.mounted) return;
                              await RecordScope.maybeOf(
                                context,
                              )!.memory!.forget(e['id'] as String);
                              load();
                            }
                          },
                          child: const Text('忘记'),
                        ),
                      ],
                    ),
                  ],
                ),
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
                Text('共 ${d['total']} 条'),
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
  );
}

class WebSettingsPage extends StatefulWidget {
  const WebSettingsPage({super.key});
  @override
  State<WebSettingsPage> createState() => _WebSettingsPageState();
}

class _WebSettingsPageState extends State<WebSettingsPage> {
  final _key = TextEditingController(), _cap = TextEditingController();
  bool _loaded = false, _busy = false;
  Map<String, Object?>? _config;
  String? _message;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      load();
    }
  }

  Future<void> load() async {
    final c = await RecordScope.maybeOf(context)!.web!.configuration();
    if (mounted) {
      setState(() {
        _config = c;
        _cap.text = '${c['limit']}';
      });
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _cap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final web = RecordScope.maybeOf(context)!.web!;
    return Scaffold(
      appBar: AppBar(title: const Text('联网搜索设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tavily 免费账户当前每月提供1000 credits；基础搜索每次1 credit。联网能力与聊天模型分开配置。',
          ),
          Text(
            '状态：${_config?['configured'] == true ? '已配置Key' : '未配置Key'} · ${_config?['month'] ?? ''} 已预留 ${_config?['used'] ?? 0} credits',
          ),
          TextField(
            controller: _key,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Tavily API Key',
              hintText: '留空保留现有Key',
            ),
          ),
          TextField(
            controller: _cap,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '本地月度上限 0～1000'),
          ),
          const Text(
            '发出的请求即预留额度，取消或超时后保留预留数，避免响应丢失导致超额。Key只保存到设备安全存储，不进入日志或备份。',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await web.settings.save(
                        _key.text.trim().isEmpty ? null : _key.text,
                        int.parse(_cap.text),
                      );
                      _key.clear();
                      await load();
                      setState(() => _message = '设置已保存');
                    } catch (e) {
                      setState(() => _message = '保存失败：$e');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('保存设置'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    await web.settings.save('', int.parse(_cap.text));
                    await load();
                  },
            child: const Text('移除搜索Key'),
          ),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final result = await web.search(
                        'Tavily official documentation',
                      );
                      setState(() => _message = '连接检查：${result['state']}');
                      await load();
                    } catch (_) {
                      setState(() => _message = '连接检查失败，请检查网络与Key');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('搜索连接检查（消耗1 credit）'),
          ),
          if (_message != null) Text(_message!),
        ],
      ),
    );
  }
}
