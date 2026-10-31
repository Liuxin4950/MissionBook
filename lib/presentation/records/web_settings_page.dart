import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_layout.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_settings_row.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_info_sheet.dart';
import 'record_scope.dart';
import '../widgets/page_footer_bar.dart';

/// 搜索凭据和本地额度沿既有 WebService 保存，页面管理加载、草稿和反馈。
class WebSettingsPage extends StatefulWidget {
  const WebSettingsPage({super.key});
  @override
  State<WebSettingsPage> createState() => _WebSettingsPageState();
}

class _WebSettingsPageState extends State<WebSettingsPage> {
  final _key = TextEditingController(), _cap = TextEditingController();
  bool _started = false, _loading = true, _busy = false, _allowPop = false;
  Map<String, Object?>? _config;
  String? _message, _loadError;
  bool get _changed =>
      _key.text.isNotEmpty ||
      (_config != null && _cap.text.trim() != '${_config!['limit']}');
  bool get _ready => !_loading && _config != null && _loadError == null;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(load());
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _cap.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final config = await RecordScope.maybeOf(context)!.web!.configuration();
      if (mounted) {
        setState(() {
          _config = config;
          _cap.text = '${config['limit']}';
          _loading = false;
          _loadError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '搜索设置读取失败，请重试';
        });
      }
    }
  }

  Future<void> back() async {
    if (_busy) return;
    final leave =
        !_changed ||
        await AppConfirmDialog.show(
          context: context,
          title: '放弃搜索设置修改？',
          message: '尚未保存的 Key 和额度修改会丢失。',
          cancelText: '继续编辑',
          confirmText: '放弃修改',
        );
    if (!leave || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> perform(Future<String> Function() action) async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await action();
      if (mounted) {
        await load();
        if (mounted) setState(() => _message = message);
      }
    } catch (_) {
      if (mounted) setState(() => _message = '操作失败，请检查网络与设置后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> save() async {
    final limit = int.tryParse(_cap.text.trim());
    if (limit == null || limit < 0 || limit > 1000) {
      setState(() => _message = '每月上限请填写 0～1000 的整数');
      return;
    }
    final web = RecordScope.maybeOf(context)!.web!;
    await perform(() async {
      await web.settings.save(
        _key.text.trim().isEmpty ? null : _key.text.trim(),
        limit,
      );
      if (mounted) _key.clear();
      return '设置已保存';
    });
  }

  Future<void> removeKey() async {
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: '移除搜索 Key？',
      message: '移除后需要重新配置才能搜索，聊天与已有记录仍可使用。',
      cancelText: '保留 Key',
      confirmText: '移除 Key',
    );
    if (!confirmed || !mounted) return;
    final web = RecordScope.maybeOf(context)!.web!;
    await perform(() async {
      await web.settings.save('', _config!['limit'] as int);
      if (mounted) _key.clear();
      return '搜索 Key 已移除';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = _config?['configured'] == true;
    return PopScope<void>(
      canPop: _allowPop || (!_busy && !_changed),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(back());
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: '联网搜索',
          canGoBack: !_busy,
          onBack: back,
          actions: [
            IconButton(
              tooltip: '搜索设置说明',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showAppInfoSheet(
                context,
                '搜索与额度',
                '搜索使用独立的 Tavily Key。基础搜索每次预留 1 次额度，发出的请求取消或超时后仍保留预留数。本地上限不会替代服务商的实际账户额度，达到上限会停止搜索。Key 仅保存在设备安全存储，不写入日志或备份。网页读取与搜索独立。',
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxPageWidth,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _loadError != null
                        ? AppEmptyState(
                            title: _loadError!,
                            actions: OutlinedButton.icon(
                              onPressed: load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试'),
                            ),
                          )
                        : ListView(
                            padding: AppLayout.pagePadding(context),
                            children: [
                              AppSectionCard(
                                padding: EdgeInsets.zero,
                                child: AppSettingsRow(
                                  icon: Icons.travel_explore,
                                  title: configured ? '搜索 Key 已配置' : '搜索尚未配置',
                                  subtitle:
                                      '${_config?['month']} · 本地已预留 ${_config?['used'] ?? 0} 次搜索',
                                ),
                              ),
                              const SizedBox(height: AppLayout.spaceLg),
                              AppSectionCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const AppSectionHeader('搜索服务'),
                                    const SizedBox(height: AppLayout.spaceLg),
                                    TextField(
                                      key: const Key('web-api-key'),
                                      controller: _key,
                                      enabled: !_busy,
                                      obscureText: true,
                                      enableSuggestions: false,
                                      autocorrect: false,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText: 'Tavily API Key',
                                        hintText: configured
                                            ? '留空保留已保存的 Key'
                                            : '输入 Tavily API Key',
                                      ),
                                    ),
                                    if (configured)
                                      AppSettingsRow(
                                        icon: Icons.key_off_outlined,
                                        title: '移除已保存的 Key',
                                        enabled: !_busy,
                                        onTap: removeKey,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppLayout.spaceLg),
                              AppSectionCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '本地额度',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: AppLayout.spaceLg),
                                    TextField(
                                      key: const Key('web-monthly-limit'),
                                      controller: _cap,
                                      enabled: !_busy,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        labelText: '每月搜索上限',
                                        suffixText: '次',
                                        helperText: '0～1000；设为 0 暂停搜索',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppLayout.spaceLg),
                              AppSectionCard(
                                padding: EdgeInsets.zero,
                                child: AppSettingsRow(
                                  icon: Icons.wifi_tethering,
                                  title: '检查搜索连接',
                                  subtitle: !configured
                                      ? '保存 Key 后可检查连接'
                                      : _changed
                                      ? '请先保存当前修改'
                                      : '使用已保存的 Key，消耗 1 次额度',
                                  enabled: !_busy && configured && !_changed,
                                  onTap: () => perform(() async {
                                    final result =
                                        await RecordScope.maybeOf(
                                          context,
                                        )!.web!.search(
                                          'Tavily official documentation',
                                        );
                                    return result['state'] == 'ok'
                                        ? '搜索连接正常'
                                        : result['message'] as String? ??
                                              '连接检查失败，请检查网络与 Key';
                                  }),
                                ),
                              ),
                              if (_busy)
                                const Padding(
                                  padding: EdgeInsets.only(
                                    top: AppLayout.spaceLg,
                                  ),
                                  child: LinearProgressIndicator(),
                                ),
                              if (_message != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppLayout.spaceLg,
                                  ),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(_message!),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  PageFooterBar(
                    child: FilledButton(
                      key: const Key('web-save-settings'),
                      onPressed: _busy || !_ready ? null : save,
                      child: Text(_busy ? '正在处理…' : '保存设置'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
