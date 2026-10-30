import '../records/context_settings_page.dart';
import '../records/record_scope.dart';
import '../widgets/app_dropdown_form_field.dart';
import 'package:flutter/material.dart';
import 'package:agent_core/agent_core.dart';
import 'assistant_avatar.dart';
import 'offline_speech_model_section.dart';
import 'assistant_scope.dart';
import '../widgets/data_export_card.dart';

import '../../application/assistant/assistant_controller.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/adaptive_columns.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_expansion.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_settings_row.dart';
import '../widgets/app_top_bar.dart';

class AssistantSettingsPage extends StatefulWidget {
  const AssistantSettingsPage({super.key, required this.controller});

  final AssistantController controller;

  @override
  State<AssistantSettingsPage> createState() => _AssistantSettingsPageState();
}

class _AssistantSettingsPageState extends State<AssistantSettingsPage> {
  final _credential = TextEditingController();
  late final _personaName = TextEditingController(
    text: widget.controller.persona.name,
  );
  late AssistantRole _role = widget.controller.persona.role;
  late AssistantReplyStyle _replyStyle = widget.controller.persona.replyStyle;
  late AssistantAvatar _avatar = widget.controller.persona.avatar;
  late final _speechEndpoint = TextEditingController(
    text: widget.controller.speechSettings.endpoint,
  );
  late final _speechModel = TextEditingController(
    text: widget.controller.speechSettings.model,
  );
  final _speechCredential = TextEditingController();
  late bool _transcription = widget.controller.speechSettings.useTranscription;
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
  late AssistantPermissionMode _permission = widget.controller.permissionMode;
  bool _saving = false;
  bool _testing = false;
  bool _leaving = false;
  bool _allowPop = false;
  String? _error;
  String? _result;

  Future<void> _back() async {
    if (_saving || _testing || _leaving) return;
    _leaving = true;
    try {
      final leave =
          !_changed ||
          await AppConfirmDialog.show(
            context: context,
            title: '放弃助手设置修改？',
            message: '尚未保存的模型、角色、语音和权限设置会丢失。',
            cancelText: '继续编辑',
            confirmText: '放弃修改',
          );
      if (!mounted || !leave) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } finally {
      _leaving = false;
    }
  }

  @override
  void initState() {
    super.initState();
    for (final field in [
      _credential,
      _personaName,
      _endpoint,
      _model,
      _contextWindow,
      _outputBudget,
      _speechEndpoint,
      _speechModel,
      _speechCredential,
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
      _modelChanged ||
      _permission != widget.controller.permissionMode ||
      _personaChanged ||
      _speechChanged;
  bool get _personaChanged =>
      _personaName.text.trim() != widget.controller.persona.name ||
      _role != widget.controller.persona.role ||
      _replyStyle != widget.controller.persona.replyStyle ||
      _avatar != widget.controller.persona.avatar;
  AssistantPersona _readPersona() => AssistantPersona(
    name: _personaName.text.trim(),
    role: _role,
    replyStyle: _replyStyle,
    avatar: _avatar,
  );
  bool get _speechChanged =>
      _transcription != widget.controller.speechSettings.useTranscription ||
      _speechEndpoint.text.trim() !=
          widget.controller.speechSettings.endpoint ||
      _speechModel.text.trim() != widget.controller.speechSettings.model ||
      _speechCredential.text.isNotEmpty;
  AssistantSpeechSettings _readSpeechSettings() => AssistantSpeechSettings(
    useTranscription: _transcription,
    endpoint: _speechEndpoint.text.trim(),
    model: _speechModel.text.trim(),
  );

  /// 保存前置校验的可读原因；无错误时返回 null。
  String? get _validationError {
    try {
      _readSpeechSettings().validate();
    } on ArgumentError catch (error) {
      return _errorText(error);
    }
    try {
      _readPersona().validate();
    } on ArgumentError catch (error) {
      return _errorText(error);
    }
    if (_profile != 'custom') return null;
    try {
      _readCustomProfile();
      return null;
    } on ArgumentError catch (error) {
      return _errorText(error);
    }
  }

  bool get _valid => _validationError == null;

  static String _errorText(Object error) => error
      .toString()
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Bad state: ', '');

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
    _personaName.dispose();
    _speechEndpoint.dispose();
    _speechModel.dispose();
    _speechCredential.dispose();
    _endpoint.dispose();
    _model.dispose();
    _contextWindow.dispose();
    _outputBudget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_saving && !_testing && !_changed),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: AppTopBar(
        title: '助手设置',
        maxContentWidth: AppLayout.dashboardMaxWidth,
        canGoBack: !_saving && !_testing,
        onBack: _back,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.dashboardMaxWidth,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppLayout.horizontalPadding(context),
                8,
                AppLayout.horizontalPadding(context),
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null || _result != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error ?? _result!,
                          style: TextStyle(
                            color: _error != null
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  if (_changed && _validationError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _validationError!,
                          key: const Key('assistant-settings-validation'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ),
                  _buildSaveActions(),
                ],
              ),
            ),
          ),
        ),
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
                if (RecordScope.maybeOf(context) != null) ...[
                  AppSectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        AppSettingsRow(
                          key: const Key('assistant-memory-entry'),
                          icon: Icons.psychology_outlined,
                          title: '助手记忆',
                          subtitle: '查看与管理',
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => const MemoryPage(),
                            ),
                          ),
                        ),
                        if (RecordScope.maybeOf(context)?.web != null) ...[
                          const Divider(
                            height: 1,
                            indent: AppLayout.spaceLg,
                            endIndent: AppLayout.spaceLg,
                          ),
                          AppSettingsRow(
                            key: const Key('assistant-web-settings-entry'),
                            icon: Icons.travel_explore,
                            title: '联网搜索',
                            subtitle: '搜索与网页读取设置',
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => const WebSettingsPage(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceLg),
                ],
                AdaptiveColumns(
                  minColumnWidth: 390,
                  maxColumns: 2,
                  spacing: 16,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildModelSection(),
                        const SizedBox(height: AppLayout.spaceLg),
                        _buildSpeechSection(),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPersonaSection(),
                        const SizedBox(height: AppLayout.spaceLg),
                        _buildPermissionSection(),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceLg),
                if (AssistantScope.maybeOf(context) case final scope?)
                  if (scope.backup != null && scope.device != null) ...[
                    DataExportCard(
                      backup: scope.backup!,
                      device: scope.device!,
                    ),
                    const SizedBox(height: AppLayout.spaceLg),
                  ],
                AppSectionCard(
                  padding: EdgeInsets.zero,
                  child: AppSettingsRow(
                    icon: Icons.shield_outlined,
                    title: '数据与隐私',
                    subtitle: 'API Key 仅保存在本机；对话会发送给所选模型供应商。',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildPersonaSection() => AppSectionCard(
    padding: EdgeInsets.zero,
    child: AppExpansionTile(
      key: const Key('assistant-persona-section'),
      leading: CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(assistantAvatarIcon(_avatar), color: AppColors.primary),
      ),
      title: const Text('角色与风格'),
      subtitle: Text(
        '${_personaName.text.trim().isEmpty ? '助手' : _personaName.text.trim()} · ${_role.label} · ${_replyStyle.label}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppLayout.spaceLg,
        AppLayout.spaceSm,
        AppLayout.spaceLg,
        AppLayout.spaceLg,
      ),
      children: [
        TextField(
          key: const Key('assistant-persona-name'),
          controller: _personaName,
          enabled: !_saving && !_testing && !widget.controller.isBusy,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: '角色名称',
            hintText: '例如：小书、阿青',
          ),
        ),
        const SizedBox(height: AppLayout.spaceMd),
        AdaptiveColumns(
          minColumnWidth: 240,
          maxColumns: 2,
          children: [
            AppDropdownFormField<AssistantRole>(
              key: const Key('assistant-persona-role'),
              isExpanded: true,
              initialValue: _role,
              decoration: const InputDecoration(labelText: '角色定位'),
              items: [
                for (final role in AssistantRole.values)
                  DropdownMenuItem(value: role, child: Text(role.label)),
              ],
              onChanged: _saving || _testing || widget.controller.isBusy
                  ? null
                  : (value) => setState(() => _role = value ?? _role),
            ),
            AppDropdownFormField<AssistantReplyStyle>(
              key: const Key('assistant-reply-style'),
              isExpanded: true,
              initialValue: _replyStyle,
              decoration: const InputDecoration(labelText: '回答风格'),
              items: [
                for (final style in AssistantReplyStyle.values)
                  DropdownMenuItem(value: style, child: Text(style.label)),
              ],
              onChanged: _saving || _testing || widget.controller.isBusy
                  ? null
                  : (value) =>
                        setState(() => _replyStyle = value ?? _replyStyle),
            ),
          ],
        ),
        const SizedBox(height: AppLayout.spaceLg),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('角色图标', style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: AppLayout.spaceSm),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in [
                (AssistantAvatar.spark, '灵感'),
                (AssistantAvatar.book, '书页'),
                (AssistantAvatar.compass, '指南针'),
              ])
                ChoiceChip(
                  avatar: Icon(
                    assistantAvatarIcon(choice.$1),
                    size: AppLayout.iconSm,
                  ),
                  label: Text(choice.$2),
                  selected: _avatar == choice.$1,
                  onSelected: _saving || _testing || widget.controller.isBusy
                      ? null
                      : (_) => setState(() => _avatar = choice.$1),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppLayout.spaceMd),
        Text(
          '角色决定帮助的侧重点，回答风格决定表达方式；保存后也会应用到已有会话。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

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
              : (value) => setState(() => _profile = value ?? _profile),
        ),
        if (_profile == 'custom') ..._customFields(),
        const SizedBox(height: AppLayout.spaceMd),
        TextField(
          key: const Key('assistant-credential-input'),
          enabled: !_saving && !_testing && !widget.controller.isBusy,
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
      ],
    ),
  );

  Widget _buildSaveActions() => Wrap(
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
        label: Text(_testing ? '正在测试…' : '测试连接'),
      ),
    ],
  );

  List<Widget> _customFields() => [
    const SizedBox(height: AppLayout.spaceMd),
    TextField(
      key: const Key('assistant-custom-endpoint'),
      controller: _endpoint,
      autocorrect: false,
      decoration: const InputDecoration(
        labelText: '完整请求地址',
        hintText: 'https://服务地址/v1/chat/completions',
      ),
    ),
    const SizedBox(height: AppLayout.spaceMd),
    TextField(
      key: const Key('assistant-custom-model'),
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
      onChanged: _saving || _testing
          ? null
          : (value) => setState(() => _protocol = value ?? _protocol),
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
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('此模型支持图片'),
      subtitle: const Text('仅在供应商明确支持图片输入时开启。'),
      value: _images,
      onChanged: _saving || _testing
          ? null
          : (value) => setState(() => _images = value),
    ),
    const Text('地址需与协议一致；保存不会发起模型请求。'),
  ];

  Widget _buildPermissionSection() => AppSectionCard(
    padding: const EdgeInsets.all(AppLayout.spaceLg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('操作权限', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppLayout.spaceSm),
        for (final mode in AssistantPermissionMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
            child: Material(
              color: _permission == mode
                  ? AppColors.primarySoft
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppLayout.radiusMd),
              child: ListTile(
                key: Key('assistant-permission-${mode.name}'),
                selected: _permission == mode,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceMd,
                  vertical: 0,
                ),
                leading: Icon(
                  _permission == mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _permission == mode
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                title: Text(mode.label),
                subtitle: Text(mode.description),
                onTap: _saving || _testing || widget.controller.isBusy
                    ? null
                    : () => setState(() => _permission = mode),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _buildSpeechSection() => AppSectionCard(
    padding: const EdgeInsets.all(AppLayout.spaceLg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('语音输入', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppLayout.spaceMd),
        AppDropdownFormField<bool>(
          key: const Key('assistant-speech-mode'),
          initialValue: _transcription,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '识别方式'),
          items: const [
            DropdownMenuItem(value: false, child: Text('离线语音')),
            DropdownMenuItem(value: true, child: Text('录音转写服务')),
          ],
          onChanged: _saving || _testing || widget.controller.isBusy
              ? null
              : (value) => setState(() => _transcription = value ?? false),
        ),
        const SizedBox(height: AppLayout.spaceMd),
        if (!_transcription) ...[
          const OfflineSpeechModelSection(),
        ] else ...[
          const Text('录音最长 50 秒，使用独立 API Key。'),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            controller: _speechEndpoint,
            key: const Key('assistant-speech-endpoint'),
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '完整转写地址',
              hintText: 'https://服务地址/v1/audio/transcriptions',
            ),
          ),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            controller: _speechModel,
            key: const Key('assistant-speech-model'),
            decoration: const InputDecoration(
              labelText: '转写模型名称',
              hintText: '填写服务支持的语音模型',
            ),
          ),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            controller: _speechCredential,
            key: const Key('assistant-speech-credential'),
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: '转写 API Key',
              hintText: widget.controller.hasTranscriptionCredential
                  ? '已保存，留空保留'
                  : '本机免认证服务可留空',
            ),
          ),
          if (widget.controller.hasTranscriptionCredential)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        try {
                          await widget.controller.saveSpeechSettings(
                            widget.controller.speechSettings,
                            credential: '',
                          );
                          if (mounted) setState(() => _result = '已清除转写 Key');
                        } catch (error) {
                          if (mounted) setState(() => _error = '$error');
                        }
                      },
                child: const Text('清除转写 Key'),
              ),
            ),
          const SizedBox(height: AppLayout.spaceSm),
          const Text('浏览器需服务允许 CORS；本机 HTTP 仅限 localhost。'),
        ],
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
      final validation = _validationError;
      if (validation != null) {
        setState(() => _error = validation);
        return;
      }
      // 先固定本次输入；等待保存期间即使页面退出，也不再读取已释放的控制器。
      final speech = _readSpeechSettings();
      final persona = _readPersona();
      final profile = _profile == 'custom' ? _readCustomProfile() : null;
      final credential = _credential.text.trim();
      final speechCredential = _speechCredential.text.trim();
      if (profile != null) {
        await widget.controller.saveCustomProfile(profile);
      }
      if (credential.isNotEmpty) {
        await widget.controller.saveCredential(credential, profileId: _profile);
        if (mounted) _credential.clear();
      }
      await widget.controller.selectModelProfile(_profile);
      await widget.controller.setPermissionMode(_permission);
      if (_personaChanged) await widget.controller.savePersona(persona);
      if (_speechChanged) {
        await widget.controller.saveSpeechSettings(
          speech,
          credential: speechCredential.isEmpty ? null : speechCredential,
        );
        if (mounted) _speechCredential.clear();
      }
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
