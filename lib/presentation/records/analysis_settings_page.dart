import '../../domain/entities/analysis_scope.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_layout.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_settings_row.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_info_sheet.dart';
import 'record_scope.dart';
import 'package:flutter/foundation.dart' show setEquals;
import '../widgets/page_footer_bar.dart';

/// 各层总结共用分析服务的持久偏好，页面保存后立即约束后台取任务。
class AnalysisSettingsPage extends StatefulWidget {
  const AnalysisSettingsPage({super.key});
  @override
  State<AnalysisSettingsPage> createState() => _AnalysisSettingsPageState();
}

class _AnalysisSettingsPageState extends State<AnalysisSettingsPage> {
  static const labels = {
    AnalysisScope.record: ('记录', '照片、文字与附件内容摘要'),
    AnalysisScope.mission: ('任务', '结束后的评价与完成情况总结'),
    AnalysisScope.node: ('节点', '节点任务与子节点的阶段摘要'),
    AnalysisScope.goal: ('目标', '目标整体进展与分层摘要'),
  };
  Set<AnalysisScope>? _scopes;
  bool _started = false, _saving = false, _allowPop = false;
  String? _error, _message;
  bool get changed =>
      _scopes != null &&
      !setEquals(
        _scopes,
        RecordScope.maybeOf(context)!.analysis.automaticScopes,
      );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(load());
    }
  }

  Future<void> load() async {
    try {
      final analysis = RecordScope.maybeOf(context)!.analysis;
      await analysis.loadPreferences();
      if (mounted) {
        setState(() {
          _scopes = analysis.automaticScopes.toSet();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '自动总结设置读取失败，请重试');
    }
  }

  Future<void> save() async {
    if (_saving || _scopes == null) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await RecordScope.maybeOf(
        context,
      )!.analysis.saveAutomaticScopes(_scopes!);
      if (mounted) setState(() => _message = '自动总结设置已保存');
    } catch (_) {
      if (mounted) setState(() => _message = '设置保存失败，当前选择已保留');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> back() async {
    if (_saving) return;
    final leave =
        !changed ||
        await AppConfirmDialog.show(
          context: context,
          title: '放弃自动总结设置？',
          message: '尚未保存的开关修改会丢失。',
          cancelText: '继续编辑',
          confirmText: '放弃修改',
        );
    if (!leave || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _allowPop || (!_saving && !changed),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(back());
    },
    child: Scaffold(
      appBar: AppTopBar(
        title: '自动总结',
        canGoBack: !_saving,
        onBack: back,
        actions: [
          IconButton(
            tooltip: '自动总结说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAppInfoSheet(
              context,
              '自动与手动总结',
              '关闭某层后，新的记录和完成报告仍正常保存，该层背景总结暂停。已有总结继续保留，资料变化时标记待更新，可以在对应页面点击生成或更新。重新开启后会继续处理待总结内容。已经发出的请求可能完成。手动总结只处理选中的对象，不会偷偷开启其他层级；缺少子级摘要会注明覆盖不足。这里的开关不改变对话记忆整理规则。',
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
            child: Column(
              children: [
                Expanded(
                  child: _scopes == null
                      ? _error == null
                            ? const Center(child: CircularProgressIndicator())
                            : AppEmptyState(
                                title: _error!,
                                actions: OutlinedButton(
                                  onPressed: load,
                                  child: const Text('重试'),
                                ),
                              )
                      : ListView(
                          padding: AppLayout.pagePadding(context),
                          children: [
                            const Text('关闭后，可在对应页面手动生成总结。'),
                            const SizedBox(height: AppLayout.spaceLg),
                            AppSectionCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  for (final entry in labels.entries)
                                    AppSettingsRow(
                                      icon: switch (entry.key) {
                                        AnalysisScope.record =>
                                          Icons.notes_outlined,
                                        AnalysisScope.mission => Icons.task_alt,
                                        AnalysisScope.node =>
                                          Icons.account_tree_outlined,
                                        _ => Icons.flag_outlined,
                                      },
                                      title: entry.value.$1,
                                      subtitle: entry.value.$2,
                                      enabled: !_saving,
                                      trailing: Switch(
                                        key: Key(
                                          'analysis-auto-${entry.key.name}',
                                        ),
                                        value: _scopes!.contains(entry.key),
                                        onChanged: _saving
                                            ? null
                                            : (value) => setState(() {
                                                if (value) {
                                                  _scopes!.add(entry.key);
                                                } else {
                                                  _scopes!.remove(entry.key);
                                                }
                                              }),
                                      ),
                                      onTap: () => setState(() {
                                        if (!_scopes!.remove(entry.key)) {
                                          _scopes!.add(entry.key);
                                        }
                                      }),
                                    ),
                                ],
                              ),
                            ),
                            if (_message != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppLayout.spaceLg,
                                ),
                                child: Text(_message!),
                              ),
                          ],
                        ),
                ),
                PageFooterBar(
                  child: FilledButton(
                    key: const Key('analysis-save-settings'),
                    onPressed: _scopes == null || _saving ? null : save,
                    child: Text(_saving ? '正在保存…' : '保存设置'),
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
