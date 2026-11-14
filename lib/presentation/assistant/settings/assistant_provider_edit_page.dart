import 'package:flutter/material.dart';
import 'package:agent_core/agent_core.dart';

import '../../../application/assistant/assistant_controller.dart';
import '../../../application/errors/user_error_message.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_dropdown_form_field.dart';
import '../shared/assistant_reasoning_display.dart';
import 'assistant_settings_form.dart';
import 'assistant_model_picker.dart';

/// 单个服务及其模型的一次性编辑页：保存时才提交目录。
class AssistantProviderEditPage extends StatefulWidget {
  const AssistantProviderEditPage({
    super.key,
    required this.controller,
    this.provider,
  });

  final AssistantController controller;

  /// 为空表示新建服务。
  final ProviderConfig? provider;

  @override
  State<AssistantProviderEditPage> createState() =>
      _AssistantProviderEditPageState();
}

class _AssistantProviderEditPageState extends State<AssistantProviderEditPage> {
  late final String _providerId;
  late String _credentialRef;
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _credential;
  late ModelProtocol _protocol;
  late String _modelProvider;
  ProviderConfig? _initialProvider;
  late bool _requiresCredential;
  late List<ProviderModel> _models;
  late List<ProviderModel> _initialModels;

  bool _saving = false;
  bool _fetching = false;
  bool _showKey = false;
  bool _clearCredential = false;
  String? _error;
  String? _result;
  String? _modelsError;
  CancellationToken? _modelFetch;

  bool get _isNew => _initialProvider == null;
  bool get _busy => _saving || _fetching || widget.controller.isBusy;

  @override
  void initState() {
    super.initState();
    final catalog = widget.controller.providerCatalog;
    final existing = widget.provider;
    _initialProvider = existing;
    _providerId =
        existing?.providerId ??
        ProviderCatalog.nextId(
          'provider',
          catalog.providers.map((provider) => provider.providerId),
        );
    _credentialRef =
        existing?.credentialRef ??
        ProviderCatalog.credentialRefFor(_providerId);
    _name = TextEditingController(text: existing?.displayName ?? '');
    _address = TextEditingController(text: existing?.baseAddress ?? '');
    _protocol = existing?.protocol ?? ModelProtocol.chatCompletions;
    _modelProvider = existing?.modelProvider ?? 'custom';
    _requiresCredential = existing?.requiresCredential ?? true;
    _credential = TextEditingController();
    _initialModels = existing == null
        ? const []
        : catalog.modelsOfProvider(existing.providerId);
    _models = [..._initialModels];
    for (final field in [_name, _address, _credential]) {
      field.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _modelFetch?.cancel();
    for (final field in [_name, _address, _credential]) {
      field.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _changed {
    final existing = _initialProvider;
    if (_isNew) {
      return _name.text.trim().isNotEmpty ||
          _address.text.trim().isNotEmpty ||
          _models.isNotEmpty ||
          _modelProvider != 'custom' ||
          _protocol != ModelProtocol.chatCompletions ||
          !_requiresCredential ||
          _credential.text.trim().isNotEmpty;
    }
    if (existing!.displayName != _name.text.trim() ||
        existing.baseAddress != _address.text.trim() ||
        existing.protocol != _protocol ||
        existing.modelProvider != _modelProvider ||
        existing.requiresCredential != _requiresCredential ||
        _clearCredential ||
        _credential.text.trim().isNotEmpty) {
      return true;
    }
    if (_models.length != _initialModels.length) return true;
    for (final model in _models) {
      final original = _initialModels
          .where((item) => item.profileId == model.profileId)
          .firstOrNull;
      if (original == null ||
          original.toJson().toString() != model.toJson().toString()) {
        return true;
      }
    }
    return false;
  }

  ProviderConfig _readProvider() => ProviderConfig(
    providerId: _providerId,
    displayName: _name.text.trim(),
    baseAddress: _address.text.trim(),
    protocol: _protocol,
    credentialRef: _credentialRef,
    modelProvider: _modelProvider,
    requiresCredential: _requiresCredential,
    archived: _initialProvider?.archived ?? false,
  );

  @override
  Widget build(BuildContext context) => AssistantSettingsForm(
    title: _isNew ? '添加服务' : '编辑服务',
    changed: _changed,
    busy: _busy,
    error: _error,
    message: _result,
    onSave: _changed ? _save : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          padding: const EdgeInsets.all(AppLayout.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('服务信息', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppLayout.spaceLg),
              TextField(
                key: const Key('assistant-provider-name'),
                enabled: !_busy,
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '服务名称',
                  hintText: '例如 本机 Ollama、公司网关',
                ),
              ),
              const SizedBox(height: AppLayout.spaceMd),
              TextField(
                key: const Key('assistant-provider-address'),
                enabled: !_busy,
                controller: _address,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: '服务地址',
                  hintText: _protocol == ModelProtocol.messages
                      ? 'http://localhost:11434/v1/messages'
                      : 'http://localhost:11434/v1',
                ),
              ),
              const SizedBox(height: AppLayout.spaceMd),
              AppDropdownFormField<ModelProtocol>(
                key: ValueKey('assistant-provider-protocol-$_protocol'),
                isExpanded: true,
                initialValue: _protocol,
                decoration: const InputDecoration(labelText: '请求协议'),
                items: const [
                  DropdownMenuItem(
                    value: ModelProtocol.chatCompletions,
                    child: Text('Chat Completions'),
                  ),
                  DropdownMenuItem(
                    value: ModelProtocol.messages,
                    child: Text('Messages'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _protocol = value ?? _protocol;
                        _modelsError = null;
                      }),
              ),
              const SizedBox(height: AppLayout.spaceMd),
              AppDropdownFormField<String>(
                initialValue: _modelProvider,
                decoration: const InputDecoration(labelText: '供应商适配'),
                items: [
                  const DropdownMenuItem(value: 'custom', child: Text('通用协议')),
                  const DropdownMenuItem(
                    value: 'deepseek',
                    child: Text('DeepSeek'),
                  ),
                  if (!['custom', 'deepseek'].contains(_modelProvider))
                    DropdownMenuItem(
                      value: _modelProvider,
                      child: Text(_modelProvider),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _modelProvider = value ?? _modelProvider;
                      }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('此服务需要 API Key'),
                subtitle: const Text('本机或内网兼容服务可以关闭，关闭后请求不发送鉴权头'),
                value: _requiresCredential,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _requiresCredential = value),
              ),
              if (_requiresCredential) ...[
                TextField(
                  key: const Key('assistant-provider-credential'),
                  enabled: !_busy && !_clearCredential,
                  controller: _credential,
                  obscureText: !_showKey,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: _hasSavedKey ? '已保存，输入新 Key 可替换' : '输入 API Key',
                    suffixIcon: IconButton(
                      tooltip: _showKey ? '隐藏 Key' : '显示 Key',
                      onPressed: () => setState(() => _showKey = !_showKey),
                      icon: Icon(
                        _showKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                if (_hasSavedKey)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('assistant-provider-clear-credential'),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _clearCredential = !_clearCredential;
                              if (_clearCredential) _credential.clear();
                            }),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(_clearCredential ? '取消清除' : '清除已保存 Key'),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppLayout.spaceLg),
        AppSectionCard(
          padding: const EdgeInsets.all(AppLayout.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '模型（${_models.where((m) => !m.archived).length}）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('assistant-provider-fetch-models'),
                    onPressed: _fetching
                        ? () => _modelFetch?.cancel()
                        : _busy
                        ? null
                        : _fetchModels,
                    icon: _fetching
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined),
                    label: Text(_fetching ? '取消获取' : '获取列表'),
                  ),
                ],
              ),
              if (_modelsError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _modelsError!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              if (_models.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppLayout.spaceMd),
                  child: Text('还没有模型。可以从服务获取列表，或手动添加模型编号。'),
                ),
              for (final model in _models)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(model.label),
                  subtitle: Text(
                    model.archived
                        ? '已停用 · ${model.modelId}'
                        : '${model.providerId == _providerId ? model.modelId : model.providerId}/${model.modelId} · 上下文 ${model.contextWindowTokens} · 回复 ${model.maxOutputTokens}',
                  ),
                  onTap: _busy ? null : () => _editModel(model),
                  trailing: TextButton(
                    key: Key('assistant-provider-toggle-${model.profileId}'),
                    onPressed: _busy ? null : () => _toggleModelArchived(model),
                    child: Text(model.archived ? '恢复' : '停用'),
                  ),
                ),
              const SizedBox(height: AppLayout.spaceSm),
              OutlinedButton.icon(
                key: const Key('assistant-provider-add-model'),
                onPressed: _busy ? null : () => _editModel(null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('手动添加模型'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  bool get _hasSavedKey =>
      _requiresCredential &&
      widget.controller.providerHasCredential(_providerId);

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final ProviderConfig provider;
    try {
      provider = _readProvider();
    } on ArgumentError catch (error) {
      setState(() {
        _error = userErrorMessage(error, fallback: '设置无效，请检查输入');
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _result = null;
    });
    try {
      final receipt = await widget.controller.saveProvider(
        provider: provider,
        models: _models,
        credential: _credential.text,
        clearCredential: _clearCredential,
      );
      if (!mounted) return;
      setState(() {
        final saved = widget.controller.providerCatalog;
        _initialProvider = saved.providerOf(receipt.providerId);
        _credentialRef = _initialProvider!.credentialRef;
        _initialModels = saved.modelsOfProvider(receipt.providerId);
        _models = [..._initialModels];
        _credential.clear();
        _clearCredential = false;
        _result = receipt.warnings.isEmpty
            ? '服务已保存'
            : '服务已保存；${receipt.warnings.join('；')}';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = userErrorMessage(error, fallback: '服务未保存，请重试'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _fetchModels() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final token = CancellationToken();
    _modelFetch = token;
    setState(() {
      _fetching = true;
      _modelsError = null;
    });
    try {
      final models = await widget.controller.fetchProviderModels(
        address: _address.text,
        protocol: _protocol,
        credential: _requiresCredential ? _credential.text : '',
        credentialRef: _requiresCredential && !_clearCredential
            ? _credentialRef
            : null,
        cancellation: token,
      );
      if (!mounted) return;
      // 选择弹层打开前结束“获取中”，避免进度动画一直旋转并锁住表单。
      setState(() => _fetching = false);
      final selected = await showDialog<String>(
        context: context,
        builder: (_) => AssistantModelPicker(models: models, selected: ''),
      );
      if (!mounted || selected == null) return;
      _addFetchedModel(selected);
    } on AgentCancelled {
      // 用户取消时保留表单与已添加模型。
    } catch (error) {
      if (mounted) {
        setState(
          () => _modelsError = userErrorMessage(
            error,
            fallback: '获取模型失败，请检查网络或服务地址后重试',
          ),
        );
      }
    } finally {
      if (identical(_modelFetch, token)) _modelFetch = null;
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _addFetchedModel(String modelId) {
    final existing = _models
        .where((model) => model.modelId == modelId)
        .firstOrNull;
    if (existing != null) {
      if (existing.archived) {
        setState(() {
          _models = [
            for (final model in _models)
              model.profileId == existing.profileId
                  ? model.copyWith(archived: false)
                  : model,
          ];
        });
      }
      return;
    }
    final profileId = _newProfileId();
    setState(() {
      _models = [
        ..._models,
        ProviderModel(
          profileId: profileId,
          providerId: _providerId,
          modelId: modelId,
        ),
      ];
    });
    _editModel(_models.last);
  }

  String _newProfileId() {
    final used = {
      for (final model in widget.controller.providerCatalog.models)
        model.profileId,
      for (final model in _models) model.profileId,
    };
    // 本地身份独立生成，供应商编号可以包含任意字符或超过 64 字符。
    return ProviderCatalog.nextId('model', used);
  }

  Future<void> _editModel(ProviderModel? model) async {
    final result = await showModalBottomSheet<ProviderModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ModelEditSheet(
        providerId: _providerId,
        profileId: model?.profileId ?? _newProfileId(),
        initial: model,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      final existing = _models.indexWhere(
        (item) => item.profileId == result.profileId,
      );
      if (existing >= 0) {
        _models[existing] = result;
      } else {
        _models = [..._models, result];
      }
    });
  }

  void _toggleModelArchived(ProviderModel model) {
    if (_busy) return;
    setState(() {
      _models = [
        for (final item in _models)
          item.profileId == model.profileId
              ? item.copyWith(archived: !model.archived)
              : item,
      ];
    });
  }
}

class _ModelEditSheet extends StatefulWidget {
  const _ModelEditSheet({
    required this.providerId,
    required this.profileId,
    this.initial,
  });

  final String providerId;
  final String profileId;
  final ProviderModel? initial;

  @override
  State<_ModelEditSheet> createState() => _ModelEditSheetState();
}

class _ModelEditSheetState extends State<_ModelEditSheet> {
  late final TextEditingController _modelId;
  late final TextEditingController _label;
  late final TextEditingController _contextWindow;
  late final TextEditingController _outputBudget;
  late final TextEditingController _outputLimit;
  late bool _images;
  late ReasoningEffort _reasoning;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _modelId = TextEditingController(text: initial?.modelId ?? '');
    _label = TextEditingController(text: initial?.displayName ?? '');
    _contextWindow = TextEditingController(
      text: '${initial?.contextWindowTokens ?? 64000}',
    );
    _outputBudget = TextEditingController(
      text: '${initial?.maxOutputTokens ?? 4096}',
    );
    _outputLimit = TextEditingController(
      text: initial?.outputTokenLimit?.toString() ?? '',
    );
    _images = initial?.supportsImages ?? true;
    _reasoning = initial?.reasoningEffort ?? ReasoningEffort.off;
  }

  @override
  void dispose() {
    for (final field in [
      _modelId,
      _label,
      _contextWindow,
      _outputBudget,
      _outputLimit,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final contextWindow = int.tryParse(_contextWindow.text.trim());
    final output = int.tryParse(_outputBudget.text.trim());
    final limitText = _outputLimit.text.trim();
    final limit = limitText.isEmpty ? null : int.tryParse(limitText);
    try {
      final model = ProviderModel(
        profileId: widget.profileId,
        providerId: widget.providerId,
        modelId: _modelId.text.trim(),
        displayName: _label.text.trim().isEmpty ? null : _label.text.trim(),
        contextWindowTokens: contextWindow ?? 0,
        maxOutputTokens: output ?? 0,
        outputTokenLimit: limit,
        supportsImages: _images,
        reasoningEffort: _reasoning,
        archived: widget.initial?.archived ?? false,
      );
      Navigator.of(context).pop(model);
    } on ArgumentError catch (error) {
      setState(
        () => _error = userErrorMessage(error, fallback: '模型设置无效，请检查输入'),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: AppLayout.spaceLg,
      right: AppLayout.spaceLg,
      top: AppLayout.spaceLg,
      bottom: MediaQuery.viewInsetsOf(context).bottom + AppLayout.spaceLg,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? '添加模型' : '编辑模型',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            key: const Key('assistant-model-id'),
            controller: _modelId,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '模型编号',
              hintText: '供应商要求的 model id',
            ),
          ),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: '显示名称（可选）',
              hintText: '聊天页展示用',
            ),
          ),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            controller: _contextWindow,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '上下文容量（token）'),
          ),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            controller: _outputBudget,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '每次回复预算（token）'),
          ),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            controller: _outputLimit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '模型输出硬上限（可选）'),
          ),
          const SizedBox(height: AppLayout.spaceMd),
          AppDropdownFormField<ReasoningEffort>(
            isExpanded: true,
            initialValue: _reasoning,
            decoration: const InputDecoration(labelText: '思考程度'),
            items: [
              for (final effort in ReasoningEffort.values)
                DropdownMenuItem(
                  value: effort,
                  child: Text(assistantReasoningLabel(effort)),
                ),
            ],
            onChanged: (value) =>
                setState(() => _reasoning = value ?? _reasoning),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('此模型支持图片'),
            value: _images,
            onChanged: (value) => setState(() => _images = value),
          ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          const SizedBox(height: AppLayout.spaceMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: AppLayout.spaceMd),
              Expanded(
                child: FilledButton(
                  key: const Key('assistant-model-save'),
                  onPressed: _submit,
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
