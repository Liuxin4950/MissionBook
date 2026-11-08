import 'package:flutter/material.dart';
import 'package:agent_core/agent_core.dart';
import '../../application/assistant/assistant_controller.dart';
import '../../application/errors/user_error_message.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_settings_row.dart';
import '../widgets/app_dropdown_form_field.dart';
import '../widgets/app_confirm_dialog.dart';
import 'assistant_settings_form.dart';
import 'assistant_reasoning_display.dart';

/// 模型、协议、思考及凭据独立保存，不改写角色或语音配置。
class AssistantModelSettingsPage extends StatelessWidget {
  const AssistantModelSettingsPage({super.key, required this.controller});
  final AssistantController controller;
  @override
  Widget build(BuildContext context) => AssistantSettingsLoader(
    controller: controller,
    title: 'AI 模型',
    builder: (_) => _ModelForm(controller: controller),
  );
}

class _ModelForm extends StatefulWidget {
  const _ModelForm({required this.controller});
  final AssistantController controller;
  @override
  State<_ModelForm> createState() => _ModelFormState();
}

class _ModelFormState extends State<_ModelForm> {
  final _credential = TextEditingController();
  late final _endpoint = TextEditingController(
    text: widget.controller.customProfile?.endpoint.toString() ?? '',
  );
  late final _model = TextEditingController(
    text: widget.controller.customProfile?.model ?? '',
  );
  late final _contextWindow = TextEditingController(
    text: '${widget.controller.customProfile?.contextWindowTokens ?? 64000}',
  );
  late final _outputBudget = TextEditingController(
    text: '${widget.controller.customProfile?.maxOutputTokens ?? 2048}',
  );
  late ModelProtocol _protocol =
      widget.controller.customProfile?.protocol ??
      ModelProtocol.chatCompletions;
  late bool _images = widget.controller.customProfile?.supportsImages ?? false;
  late String _profile = widget.controller.modelProfileId;
  late ReasoningEffort _reasoning = widget.controller.reasoningEffort;
  bool _saving = false, _testing = false, _showKey = false;
  bool _attemptedSave = false;
  String? _error, _result, _connectionResult, _connectionError;
  String _errorText(Object error) =>
      userErrorMessage(error, fallback: '设置无效，请检查输入');
  void _changedListener() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    for (final field in [
      _credential,
      _endpoint,
      _model,
      _contextWindow,
      _outputBudget,
    ]) {
      field.addListener(_changedListener);
    }
    widget.controller.addListener(_changedListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changedListener);
    for (final field in [
      _credential,
      _endpoint,
      _model,
      _contextWindow,
      _outputBudget,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  String? get _validationError {
    if (_profile != 'custom') return null;
    try {
      _readCustomProfile();
      return null;
    } on ArgumentError catch (error) {
      return _errorText(error);
    }
  }

  @override
  Widget build(BuildContext context) => AssistantSettingsForm(
    title: 'AI 模型',
    changed: _modelChanged,
    busy: _saving || _testing || widget.controller.isBusy,
    error: _error ?? (_attemptedSave ? _validationError : null),
    message: _result,
    onSave: _modelChanged ? _save : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          padding: EdgeInsets.zero,
          child: AppSettingsRow(
            icon: Icons.auto_awesome_outlined,
            title: '当前模型',
            subtitle:
                '${widget.controller.modelProfileId == "custom" ? widget.controller.customProfile?.model : widget.controller.modelProfileId} · ${widget.controller.hasCredential ? "Key 已配置" : "未配置 Key"}',
          ),
        ),
        const SizedBox(height: AppLayout.spaceLg),
        _buildModelSection(),
      ],
    ),
  );
  Future<void> _save() async {
    if (_saving || _testing || widget.controller.isBusy) return;
    final validationError = _validationError;
    if (validationError != null) {
      setState(() {
        _attemptedSave = true;
        _error = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    final profileId = _profile;
    final profile = profileId == 'custom' ? _readCustomProfile() : null;
    final credential = _credential.text.trim();
    final reasoning = _reasoning;
    setState(() {
      _saving = true;
      _attemptedSave = false;
      _error = null;
      _result = null;
      _connectionError = null;
      _connectionResult = null;
    });
    try {
      if (profile != null) await widget.controller.saveCustomProfile(profile);
      if (credential.isNotEmpty) {
        await widget.controller.saveCredential(
          credential,
          profileId: profileId,
        );
        if (mounted) _credential.clear();
      }
      await widget.controller.selectModelProfile(profileId);
      await widget.controller.setReasoningEffort(reasoning);
      if (mounted) setState(() => _result = '设置已保存');
    } catch (error) {
      if (mounted) {
        setState(() => _error = userErrorMessage(error, fallback: '设置未保存，请重试'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _customChanged {
    if (_profile != 'custom') return false;
    final saved = widget.controller.customProfile;
    return saved == null ||
        saved.endpoint.toString() != _endpoint.text.trim() ||
        saved.model != _model.text.trim() ||
        saved.protocol != _protocol ||
        saved.contextWindowTokens.toString() != _contextWindow.text.trim() ||
        saved.maxOutputTokens.toString() != _outputBudget.text.trim() ||
        saved.supportsImages != _images;
  }

  bool get _modelChanged =>
      _profile != widget.controller.modelProfileId ||
      _reasoning != widget.controller.reasoningEffortFor(_profile) ||
      _customChanged ||
      _credential.text.trim().isNotEmpty;
  ModelProfile _readCustomProfile() {
    final contextWindow = int.tryParse(_contextWindow.text.trim());
    final output = int.tryParse(_outputBudget.text.trim());
    if (contextWindow == null || output == null) {
      throw ArgumentError('容量和回复预算应填写正整数');
    }
    return ModelProfile(
      id: 'custom',
      provider: 'custom',
      model: _model.text.trim(),
      endpoint: Uri.parse(_endpoint.text.trim()),
      protocol: _protocol,
      credentialKey: 'MISSIONBOOK_CUSTOM_API_KEY',
      contextWindowTokens: contextWindow,
      maxOutputTokens: output,
      supportsImages: _images,
      reasoningEffort: _reasoning,
    );
  }

  Widget _buildModelSection() => AppSectionCard(
    padding: const EdgeInsets.all(AppLayout.spaceLg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('模型与凭据', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppLayout.spaceLg),
        AppDropdownFormField<String>(
          isExpanded: true,
          initialValue: _profile,
          decoration: const InputDecoration(labelText: '模型服务'),
          items: const [
            DropdownMenuItem(
              value: 'deepseek-chat',
              child: Text('DeepSeek · Chat', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'deepseek',
              child: Text('DeepSeek · Messages'),
            ),
            DropdownMenuItem(value: 'custom', child: Text('自定义服务')),
          ],
          onChanged: _saving || _testing || widget.controller.isBusy
              ? null
              : (value) => setState(() {
                  _profile = value ?? _profile;
                  _reasoning =
                      _profile == 'custom' &&
                          widget.controller.customProfile == null
                      ? ReasoningEffort.off
                      : widget.controller.reasoningEffortFor(_profile);
                }),
        ),
        const SizedBox(height: AppLayout.spaceMd),
        AppDropdownFormField<ReasoningEffort>(
          key: ValueKey('assistant-reasoning-$_profile'),
          initialValue: _reasoning,
          decoration: const InputDecoration(labelText: '思考程度'),
          items: [
            for (final effort in ReasoningEffort.values)
              DropdownMenuItem(
                value: effort,
                child: Text(assistantReasoningLabel(effort)),
              ),
          ],
          onChanged: _saving || _testing || widget.controller.isBusy
              ? null
              : (value) => setState(() => _reasoning = value ?? _reasoning),
        ),
        if (_profile == 'custom') ..._customFields(),
        const SizedBox(height: AppLayout.spaceMd),
        TextField(
          key: const Key('assistant-credential-input'),
          enabled: !_saving && !_testing && !widget.controller.isBusy,
          controller: _credential,
          obscureText: !_showKey,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            suffixIcon: IconButton(
              tooltip: _showKey ? '隐藏 Key' : '显示 Key',
              onPressed: () => setState(() => _showKey = !_showKey),
              icon: Icon(
                _showKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            labelText: _profile == 'custom'
                ? '自定义服务 API Key'
                : 'DeepSeek API Key',
            hintText: widget.controller.profileHasCredential(_profile)
                ? '已保存，输入新 Key 可替换'
                : '输入 API Key',
          ),
        ),
        if (widget.controller.profileHasCredential(_profile))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('assistant-clear-credential'),
              onPressed: _saving || _testing || widget.controller.isBusy
                  ? null
                  : _clearCredential,
              icon: const Icon(Icons.delete_outline),
              label: const Text('清除已保存 Key'),
            ),
          ),
        if (!_modelChanged &&
            widget.controller.profileHasCredential(_profile)) ...[
          const SizedBox(height: AppLayout.spaceSm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('assistant-test-connection'),
              onPressed: _saving || _testing || widget.controller.isBusy
                  ? null
                  : _testConnection,
              icon: _testing
                  ? const SizedBox.square(
                      dimension: AppLayout.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.network_check_outlined,
                      size: AppLayout.iconSm,
                    ),
              label: Text(_testing ? '正在测试…' : '测试连接'),
            ),
          ),
        ],
        if (_connectionError != null || _connectionResult != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _connectionError ?? _connectionResult!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _connectionError != null
                    ? AppColors.error
                    : AppColors.primary,
              ),
            ),
          ),
      ],
    ),
  );

  List<Widget> _customFields() => [
    const SizedBox(height: AppLayout.spaceMd),
    TextField(
      key: const Key('assistant-custom-endpoint'),
      enabled: !_saving && !_testing && !widget.controller.isBusy,
      controller: _endpoint,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: '完整请求地址',
        hintText: _protocol == ModelProtocol.messages
            ? 'https://服务地址/v1/messages'
            : 'https://服务地址/v1/chat/completions',
      ),
    ),
    const SizedBox(height: AppLayout.spaceMd),
    TextField(
      key: const Key('assistant-custom-model'),
      enabled: !_saving && !_testing && !widget.controller.isBusy,
      controller: _model,
      autocorrect: false,
      decoration: const InputDecoration(
        labelText: '模型名称',
        hintText: '供应商提供的模型编号',
      ),
    ),
    const SizedBox(height: AppLayout.spaceMd),
    AppDropdownFormField<ModelProtocol>(
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
      onChanged: _saving || _testing || widget.controller.isBusy
          ? null
          : (value) => setState(() => _protocol = value ?? _protocol),
    ),
    const SizedBox(height: AppLayout.spaceMd),
    TextField(
      enabled: !_saving && !_testing && !widget.controller.isBusy,
      controller: _contextWindow,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: '上下文容量（token）'),
    ),
    const SizedBox(height: AppLayout.spaceMd),
    TextField(
      enabled: !_saving && !_testing && !widget.controller.isBusy,
      controller: _outputBudget,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: '每次回复预算（token）'),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('此模型支持图片'),
      value: _images,
      onChanged: _saving || _testing || widget.controller.isBusy
          ? null
          : (value) => setState(() => _images = value),
    ),
  ];

  Future<void> _clearCredential() async {
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: '清除已保存的 API Key？',
      message: '清除后不能发起新的模型请求，已有会话和任务数据不受影响。',
      cancelText: '保留 Key',
      confirmText: '清除 Key',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
      _result = null;
    });
    try {
      await widget.controller.saveCredential('', profileId: _profile);
      if (mounted) setState(() => _result = '已清除设备上的 API Key');
    } catch (error) {
      if (mounted) {
        setState(() => _error = userErrorMessage(error, fallback: '清除失败，请重试'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _connectionError = null;
      _connectionResult = null;
    });
    try {
      final result = await widget.controller.testConnection();
      if (mounted) setState(() => _connectionResult = '连接成功：$result');
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _connectionError = userErrorMessage(error, fallback: '连接失败，请重试'),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }
}
