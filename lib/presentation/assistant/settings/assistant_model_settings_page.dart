import 'package:flutter/material.dart';
import 'package:agent_core/agent_core.dart';

import '../../../application/assistant/assistant_controller.dart';
import '../../../application/errors/user_error_message.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../widgets/adaptive_columns.dart';
import '../../widgets/app_expansion.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_settings_row.dart';
import '../../widgets/app_top_bar.dart';
import 'assistant_model_picker.dart';
import 'assistant_provider_edit_page.dart';
import 'assistant_settings_form.dart';

/// 服务目录总览：默认/摘要/当前会话模型与服务列表。
///
/// 本页不持有草稿，保存动作只发生在单个服务的编辑页，避免多处写入互相覆盖。
class AssistantModelSettingsPage extends StatelessWidget {
  const AssistantModelSettingsPage({super.key, required this.controller});
  final AssistantController controller;

  @override
  Widget build(BuildContext context) => AssistantSettingsLoader(
    controller: controller,
    title: 'AI 模型',
    builder: (_) => _ModelOverview(controller: controller),
  );
}

class _ModelOverview extends StatefulWidget {
  const _ModelOverview({required this.controller});
  final AssistantController controller;

  @override
  State<_ModelOverview> createState() => _ModelOverviewState();
}

class _ModelOverviewState extends State<_ModelOverview> {
  bool _busy = false;
  String? _error;
  String? _message;

  AssistantController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onController);
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  List<({ProviderConfig provider, ProviderModel model})> get _choices {
    final catalog = _controller.providerCatalog;
    return [
      for (final model in catalog.models)
        if (catalog.isSelectable(model.profileId))
          if (catalog.providerForProfile(model.profileId) case final provider?)
            (provider: provider, model: model),
    ];
  }

  String _describe(ProviderModel? model, ProviderConfig? provider) {
    if (model == null) return '未选择';
    final name = model.label;
    final service = provider?.displayName;
    return service == null ? name : '$name · $service';
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _controller.providerCatalog;
    final defaultModel = catalog.modelOfProfile(
      catalog.selection.defaultProfileId,
    );
    final summaryModel = catalog.modelOfProfile(
      catalog.selection.effectiveSummaryProfileId,
    );
    final providers = [...catalog.providers]
      ..sort((a, b) => (a.archived ? 1 : 0).compareTo(b.archived ? 1 : 0));
    final archivedModels = catalog.models
        .where((model) => model.archived)
        .toList();
    final sessionOpen = _controller.currentSessionId != null;
    final sessionModel = sessionOpen
        ? catalog.modelOfProfile(_controller.modelProfileId)
        : null;

    return Scaffold(
      appBar: AppTopBar(
        title: 'AI 模型',
        maxContentWidth: AppLayout.formMaxWidth,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
            child: ListView(
              padding: AppLayout.pagePadding(context),
              children: [
                if (_controller.catalogWarning != null) ...[
                  AppSectionCard(
                    padding: const EdgeInsets.all(AppLayout.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '模型配置需要检查',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppLayout.spaceSm),
                        Text(
                          _controller.catalogWarning!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceLg),
                ],
                AdaptiveColumns(
                  minColumnWidth: AppLayout.paneLeftMin,
                  maxColumns: 2,
                  children: [
                    AppSectionCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          AppSettingsRow(
                            key: const Key('assistant-default-model'),
                            icon: Icons.star_outline,
                            title: '新会话默认模型',
                            subtitle: _describe(
                              defaultModel,
                              catalog.providerForProfile(
                                defaultModel?.profileId ?? '',
                              ),
                            ),
                            enabled: !_busy,
                            onTap: _chooseDefault,
                          ),
                          const Divider(height: 1),
                          AppSettingsRow(
                            key: const Key('assistant-summary-model'),
                            icon: Icons.summarize_outlined,
                            title: '摘要模型',
                            subtitle:
                                '${catalog.selection.summaryProfileId == null ? '跟随默认 · ' : ''}${_describe(summaryModel, catalog.providerForProfile(summaryModel?.profileId ?? ''))}',
                            enabled: !_busy,
                            onTap: _chooseSummary,
                          ),
                          if (sessionOpen) ...[
                            const Divider(height: 1),
                            AppSettingsRow(
                              key: const Key('assistant-session-model'),
                              icon: Icons.chat_bubble_outline,
                              title: '当前会话模型',
                              subtitle: _describe(
                                sessionModel,
                                catalog.providerForProfile(
                                  sessionModel?.profileId ?? '',
                                ),
                              ),
                              enabled: !_busy,
                              onTap: _chooseSessionModel,
                            ),
                          ],
                        ],
                      ),
                    ),
                    AppSectionCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final provider in providers) ...[
                            AppSettingsRow(
                              key: Key(
                                'assistant-provider-${provider.providerId}',
                              ),
                              icon: Icons.dns_outlined,
                              title: provider.displayName,
                              subtitle: [
                                provider.protocol == ModelProtocol.messages
                                    ? 'Messages'
                                    : 'Chat Completions',
                                '${catalog.modelsOfProvider(provider.providerId, includeArchived: false).length} 个模型',
                                if (provider.requiresCredential &&
                                    !_controller.providerHasCredential(
                                      provider.providerId,
                                    ))
                                  '未配置 Key',
                                if (provider.archived) '已停用',
                              ].join(' · '),
                              enabled: !_busy,
                              onTap: () => _openProvider(provider),
                            ),
                            const Divider(height: 1),
                          ],
                          AppSettingsRow(
                            key: const Key('assistant-add-provider'),
                            icon: Icons.add_rounded,
                            title: '添加服务',
                            enabled: !_busy,
                            onTap: _busy ? null : () => _openProvider(null),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (archivedModels.isNotEmpty) ...[
                  const SizedBox(height: AppLayout.spaceLg),
                  AppSectionCard(
                    padding: EdgeInsets.zero,
                    child: AppExpansionTile(
                      insetHeader: false,
                      leading: const Icon(Icons.pause_circle_outline),
                      title: Text('已停用模型 · ${archivedModels.length}'),
                      children: [
                        for (final model in archivedModels) ...[
                          AppSettingsRow(
                            icon: Icons.pause_circle_outline,
                            title: model.label,
                            subtitle: catalog
                                .providerForProfile(model.profileId)
                                ?.displayName,
                            trailing: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _restoreModel(model),
                              child: const Text('恢复'),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                ],
                if (_error != null || _message != null) ...[
                  const SizedBox(height: AppLayout.spaceLg),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error ?? _message!,
                      style: TextStyle(
                        color: _error != null
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = userErrorMessage(error, fallback: '操作未完成，请重试'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openProvider(ProviderConfig? provider) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssistantProviderEditPage(
          controller: _controller,
          provider: provider,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _chooseDefault() => _pickAndApply(
    title: '新会话默认模型',
    selectedProfileId: _controller.defaultProfileId,
    onApply: (profileId) => _controller.setDefaultModels(
      main: profileId,
      summary: _controller.providerCatalog.selection.summaryProfileId,
    ),
  );

  Future<void> _chooseSummary() => _pickAndApply(
    title: '摘要模型',
    followDefault: true,
    selectedProfileId: _controller.providerCatalog.selection.summaryProfileId,
    onApply: (profileId) => _controller.setDefaultModels(
      main: _controller.defaultProfileId,
      summary: profileId,
    ),
  );

  Future<void> _chooseSessionModel() => _pickAndApply(
    title: '当前会话模型',
    selectedProfileId: _controller.modelProfileId,
    onApply: _controller.selectSessionModel,
  );

  Future<void> _pickAndApply({
    required String title,
    required Future<void> Function(String profileId) onApply,
    String? selectedProfileId,
    bool followDefault = false,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (_) => AssistantModelChoicePicker(
        title: title,
        choices: _choices,
        selectedProfileId: selectedProfileId,
        followDefaultLabel: followDefault ? '跟随默认模型' : null,
      ),
    );
    if (!mounted || selected == null) return;
    if (selected.isEmpty) {
      await _run(
        () => _controller.setDefaultModels(main: _controller.defaultProfileId),
      );
      return;
    }
    await _run(() => onApply(selected));
    if (mounted && _error == null) setState(() => _message = '$title已更新');
  }

  Future<void> _restoreModel(ProviderModel model) => _run(() async {
    await _controller.setModelArchived(model.profileId, false);
    if (mounted) setState(() => _message = '已恢复 ${model.label}');
  });
}
