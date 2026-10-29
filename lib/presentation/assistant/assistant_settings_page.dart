import 'package:flutter/material.dart';
import 'package:agent_core/agent_core.dart';

import '../../application/assistant/assistant_controller.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/adaptive_columns.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_top_bar.dart';

class AssistantSettingsPage extends StatefulWidget {
  const AssistantSettingsPage({super.key, required this.controller});

  final AssistantController controller;

  @override
  State<AssistantSettingsPage> createState() => _AssistantSettingsPageState();
}

class _AssistantSettingsPageState extends State<AssistantSettingsPage> {
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
  late bool _autoApprove = widget.controller.autoApproveWrites;
  bool _saving = false;
  bool _testing = false;
  String? _error;
  String? _result;

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
      field.addListener(_fieldChanged);
    }
    widget.controller.addListener(_fieldChanged);
  }

  void _fieldChanged() {
    if (mounted) setState(() {});
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
      _customChanged ||
      _credential.text.trim().isNotEmpty;
  bool get _changed =>
      _modelChanged || _autoApprove != widget.controller.autoApproveWrites;
  bool get _valid {
    if (_profile != 'custom') return true;
    try {
      _readCustomProfile();
      return true;
    } catch (_) {
      return false;
    }
  }

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
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_fieldChanged);
    _credential.dispose();
    _endpoint.dispose();
    _model.dispose();
    _contextWindow.dispose();
    _outputBudget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(
      title: '助手设置',
      maxContentWidth: AppLayout.dashboardMaxWidth,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.dashboardMaxWidth,
          ),
          child: ListView(
            padding: AppLayout.pagePadding(context),
            children: [
              AdaptiveColumns(
                minColumnWidth: 340,
                maxColumns: 2,
                children: [_buildModelSection(), _buildPermissionSection()],
              ),
              const SizedBox(height: 20),
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '数据与隐私',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'API Key 只保存在这台设备的安全存储中，不进入会话数据库或备份。使用云端模型时，当前对话、显式引用和工具查询结果会发送给所选供应商；MissionBook 不经过自建服务器。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (_error != null || _result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error ?? _result!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _error != null
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildModelSection() => AppSectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('模型与凭据', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _profile,
          decoration: const InputDecoration(labelText: '模型服务'),
          items: const [
            DropdownMenuItem(
              value: 'deepseek-chat',
              child: Text('DeepSeek · Chat Completions'),
            ),
            DropdownMenuItem(
              value: 'deepseek',
              child: Text('DeepSeek · Messages'),
            ),
            DropdownMenuItem(value: 'custom', child: Text('自定义服务')),
          ],
          onChanged: _saving || _testing || widget.controller.isBusy
              ? null
              : (value) => setState(() => _profile = value ?? _profile),
        ),
        if (_profile == 'custom') ..._customFields(),
        const SizedBox(height: 12),
        TextField(
          key: const Key('assistant-credential-input'),
          controller: _credential,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: _profile == 'custom'
                ? '自定义服务 API Key'
                : 'DeepSeek API Key',
            hintText: widget.controller.profileHasCredential(_profile)
                ? '已保存，输入新 Key 可替换'
                : '输入测试或正式 Key',
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                foregroundColor: AppColors.onPrimary,
                iconColor: AppColors.onPrimary,
                backgroundColor: AppColors.primary,
                disabledForegroundColor: AppColors.onDisabled,
                disabledBackgroundColor: AppColors.disabled,
              ),
              key: const Key('assistant-save-settings'),
              onPressed:
                  _saving ||
                      _testing ||
                      widget.controller.isBusy ||
                      !_changed ||
                      !_valid
                  ? null
                  : _save,
              child: Text(_saving ? '正在保存…' : '保存设置'),
            ),
            OutlinedButton.icon(
              key: const Key('assistant-test-connection'),
              onPressed:
                  _saving ||
                      _testing ||
                      _modelChanged ||
                      !widget.controller.profileHasCredential(_profile)
                  ? null
                  : _testConnection,
              icon: const Icon(Icons.network_check_outlined),
              label: Text(_testing ? '正在测试…' : '测试已保存配置'),
            ),
          ],
        ),
      ],
    ),
  );

  List<Widget> _customFields() => [
    const SizedBox(height: 12),
    TextField(
      key: const Key('assistant-custom-endpoint'),
      controller: _endpoint,
      autocorrect: false,
      decoration: const InputDecoration(
        labelText: '完整请求地址',
        hintText: 'https://服务地址/v1/chat/completions',
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      key: const Key('assistant-custom-model'),
      controller: _model,
      autocorrect: false,
      decoration: const InputDecoration(
        labelText: '模型名称',
        hintText: '供应商提供的模型编号',
      ),
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<ModelProtocol>(
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
      onChanged: _saving || _testing
          ? null
          : (value) => setState(() => _protocol = value ?? _protocol),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _contextWindow,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: '上下文容量（token）'),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _outputBudget,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: '每次回复预算（token）'),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('此模型支持图片'),
      subtitle: const Text('仅在供应商明确支持图片输入时开启。'),
      value: _images,
      onChanged: _saving || _testing
          ? null
          : (value) => setState(() => _images = value),
    ),
    const Text('完整地址必须与所选协议一致；容量和图片能力以供应商说明为准。保存不会发起模型请求。'),
  ];

  Widget _buildPermissionSection() => AppSectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('操作权限', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('assistant-auto-approve'),
          contentPadding: EdgeInsets.zero,
          title: const Text('自动执行已提供的写入工具'),
          subtitle: const Text('关闭时，每份任务或目标修改都先在卡片中确认。业务规则与冲突检查始终有效。'),
          value: _autoApprove,
          onChanged: _saving || _testing || widget.controller.isBusy
              ? null
              : (value) => setState(() => _autoApprove = value),
        ),
        Text(
          _autoApprove
              ? '开启后，模型可直接调用当前已接入的创建、改期、执行和取消工具；结果仍必须来自真实提交。'
              : '当前为逐次确认模式。你可以先修改卡片，再决定执行或取消。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '宽松模式的更细分类尚未定稿，本设置不暗中扩大权限范围。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _result = null;
    });
    try {
      if (_profile == 'custom') {
        final profile = _readCustomProfile();
        await widget.controller.saveCustomProfile(profile);
      }
      if (_credential.text.trim().isNotEmpty) {
        await widget.controller.saveCredential(
          _credential.text,
          profileId: _profile,
        );
        _credential.clear();
      }
      await widget.controller.selectModelProfile(_profile);
      await widget.controller.setAutoApproveWrites(_autoApprove);
      if (mounted) setState(() => _result = '设置已保存');
    } catch (error) {
      if (mounted) setState(() => _error = '设置未保存：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearCredential() async {
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: '清除已保存的 API Key？',
      message: '清除后不能发起新的模型请求，已有会话和任务数据不受影响。',
      cancelText: '保留 Key',
      confirmText: '清除 Key',
    );
    if (confirmed != true) return;
    try {
      await widget.controller.saveCredential('', profileId: _profile);
      if (mounted) setState(() => _result = '已清除设备上的 API Key');
    } catch (error) {
      if (mounted) setState(() => _error = '清除失败：$error');
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.controller.testConnection();
      if (mounted) setState(() => _result = '连接成功：$result');
    } catch (error) {
      if (mounted) setState(() => _error = '连接失败：$error');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }
}
