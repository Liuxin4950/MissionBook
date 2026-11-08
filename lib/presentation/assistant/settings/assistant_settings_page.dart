import '../../../application/errors/user_error_message.dart';
import 'dart:async';

import '../../records/memory_page.dart';
import '../../records/web_settings_page.dart';
import '../../records/analysis_settings_page.dart';
import '../../records/record_scope.dart';
import '../../widgets/app_dropdown_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../shared/assistant_avatar.dart';
import '../entry/assistant_scope.dart';
import '../../me/data_backup_page.dart';
import 'assistant_model_settings_page.dart';
import 'assistant_speech_settings_page.dart';

import '../../../application/assistant/assistant_controller.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../widgets/adaptive_columns.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_expansion.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_settings_row.dart';
import '../../widgets/app_top_bar.dart';

class AssistantSettingsPage extends StatefulWidget {
  const AssistantSettingsPage({super.key, required this.controller});

  final AssistantController controller;

  @override
  State<AssistantSettingsPage> createState() => _AssistantSettingsPageState();
}

class _AssistantSettingsPageState extends State<AssistantSettingsPage>
    with WidgetsBindingObserver {
  late final _personaName = TextEditingController(
    text: widget.controller.persona.name,
  );
  late final _userAddress = TextEditingController(
    text: widget.controller.persona.userAddress,
  );
  late AssistantRole _role = widget.controller.persona.role;
  late AssistantReplyStyle _replyStyle = widget.controller.persona.replyStyle;
  late AssistantAvatar _avatar = widget.controller.persona.avatar;
  late AssistantPermissionMode _permission = widget.controller.permissionMode;
  bool _saving = false;
  bool _leaving = false;
  bool _allowPop = false;
  bool _ready = false;
  String? _loadError;
  String? _error;
  String? _result;
  bool? _overlayEnabled;
  bool _overlayBusy = false;

  Future<void> _loadOverlay() async {
    try {
      final enabled = await const MethodChannel(
        'mission_book/device',
      ).invokeMethod<bool>('assistantOverlayEnabled');
      if (mounted) setState(() => _overlayEnabled = enabled ?? false);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _error = userErrorMessage(error, fallback: '读取悬浮窗状态失败'));
      }
    } on MissingPluginException {
      if (mounted) setState(() => _error = '当前设备不支持悬浮窗');
    }
  }

  Future<void> _toggleOverlay() async {
    if (_overlayBusy) return;
    setState(() => _overlayBusy = true);
    try {
      final enabled = await const MethodChannel(
        'mission_book/device',
      ).invokeMethod<bool>('toggleAssistantOverlay');
      if (mounted) setState(() => _overlayEnabled = enabled ?? false);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(error, fallback: '悬浮窗设置失败，请重试'),
        );
      }
    } finally {
      if (mounted) setState(() => _overlayBusy = false);
    }
  }

  Future<void> _back() async {
    if (_saving || _leaving) return;
    _leaving = true;
    try {
      final leave =
          !_changed ||
          await AppConfirmDialog.show(
            context: context,
            title: '放弃助手设置修改？',
            message: '尚未保存的角色和权限设置会丢失。',
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
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_loadOverlay());
    }
    for (final field in [_personaName, _userAddress]) {
      field.addListener(_fieldChanged);
    }
    widget.controller.addListener(_fieldChanged);
    _ready = widget.controller.initialized;
    if (!_ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_prepare());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_overlayBusy &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_loadOverlay());
    }
  }

  Future<void> _prepare() async {
    _loadError = null;
    try {
      await widget.controller.initialize();
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _loadError = userErrorMessage(error, fallback: '设置未保存，请检查输入或重试'),
        );
      }
      return;
    }
    if (!mounted) return;
    if (!widget.controller.initialized) {
      setState(
        () => _loadError = widget.controller.errorMessage ?? '助手设置未能加载，请重试。',
      );
      return;
    }
    _applyLoadedSettings();
    setState(() => _ready = true);
  }

  void _retryPrepare() {
    setState(() => _loadError = null);
    unawaited(_prepare());
  }

  /// 初始化会补读本机设置；先回填再开放表单，避免用过默认值覆盖已保存配置。
  void _applyLoadedSettings() {
    final controller = widget.controller;
    _permission = controller.permissionMode;
    _personaName.text = controller.persona.name;
    _userAddress.text = controller.persona.userAddress;
    _role = controller.persona.role;
    _replyStyle = controller.persona.replyStyle;
    _avatar = controller.persona.avatar;
  }

  void _fieldChanged() {
    if (mounted) setState(() {});
  }

  Widget _buildPrepareState(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: '助手设置',
      maxContentWidth: AppLayout.dashboardMaxWidth,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: _loadError == null
            ? const CircularProgressIndicator()
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: AppLayout.pagePadding(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: AppLayout.spaceLg),
                      FilledButton(
                        key: const Key('assistant-settings-retry'),
                        onPressed: _retryPrepare,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ),
  );

  bool get _changed =>
      _permission != widget.controller.permissionMode || _personaChanged;
  bool get _personaChanged =>
      _personaName.text.trim() != widget.controller.persona.name ||
      _userAddress.text.trim() != widget.controller.persona.userAddress ||
      _role != widget.controller.persona.role ||
      _replyStyle != widget.controller.persona.replyStyle ||
      _avatar != widget.controller.persona.avatar;
  AssistantPersona _readPersona() => AssistantPersona(
    name: _personaName.text.trim(),
    userAddress: _userAddress.text.trim(),
    role: _role,
    replyStyle: _replyStyle,
    avatar: _avatar,
  );
  String? get _validationError {
    try {
      _readPersona().validate();
      return null;
    } on ArgumentError catch (error) {
      return userErrorMessage(error, fallback: '角色设置无效');
    }
  }

  bool get _valid => _validationError == null;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_fieldChanged);
    _personaName.dispose();
    _userAddress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return _buildPrepareState(context);
    return PopScope(
      canPop: _allowPop || (!_saving && !_changed),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: '助手设置',
          maxContentWidth: AppLayout.dashboardMaxWidth,
          canGoBack: !_saving,
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
                        padding: const EdgeInsets.only(
                          bottom: AppLayout.spaceSm,
                        ),
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
                        padding: const EdgeInsets.only(
                          bottom: AppLayout.spaceSm,
                        ),
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
                            title: 'AI 日记本',
                            subtitle: '查看助手记住的偏好、事实与约束',
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
                          const Divider(
                            height: 1,
                            indent: AppLayout.spaceLg,
                            endIndent: AppLayout.spaceLg,
                          ),
                          AppSettingsRow(
                            key: const Key('assistant-analysis-settings-entry'),
                            icon: Icons.auto_awesome_outlined,
                            title: '自动总结',
                            subtitle: '按记录、任务、节点和目标分别设置',
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => const AnalysisSettingsPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceLg),
                  ],
                  AppSectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        AppSettingsRow(
                          key: const Key('assistant-model-settings-entry'),
                          icon: Icons.auto_awesome_outlined,
                          title: 'AI 模型',
                          subtitle:
                              '${widget.controller.modelProfileId == "custom" ? widget.controller.customProfile?.model : widget.controller.modelProfileId} · 模型、凭据与连接测试',
                          onTap: _saving || widget.controller.isBusy
                              ? null
                              : () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => AssistantModelSettingsPage(
                                      controller: widget.controller,
                                    ),
                                  ),
                                ),
                        ),
                        const Divider(
                          height: 1,
                          indent: AppLayout.spaceLg,
                          endIndent: AppLayout.spaceLg,
                        ),
                        AppSettingsRow(
                          key: const Key('assistant-speech-settings-entry'),
                          icon: Icons.mic_outlined,
                          title: '语音输入',
                          subtitle:
                              widget.controller.speechSettings.useTranscription
                              ? '录音转写服务 · 独立凭据'
                              : '离线语音 · 模型下载与管理',
                          onTap: _saving || widget.controller.isBusy
                              ? null
                              : () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => AssistantSpeechSettingsPage(
                                      controller: widget.controller,
                                      createVoiceTest: AssistantScope.maybeOf(
                                        context,
                                      )?.createVoiceTest,
                                    ),
                                  ),
                                ),
                        ),
                        if (AssistantScope.maybeOf(context) case final scope?)
                          if (scope.backup != null && scope.device != null) ...[
                            const Divider(
                              height: 1,
                              indent: AppLayout.spaceLg,
                              endIndent: AppLayout.spaceLg,
                            ),
                            AppSettingsRow(
                              key: const Key('assistant-backup-entry'),
                              icon: Icons.archive_outlined,
                              title: '数据备份',
                              subtitle: '导出完整本地数据，与软件设置共用',
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => DataBackupPage(
                                    backup: scope.backup!,
                                    device: scope.device!,
                                  ),
                                ),
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceLg),
                  _buildPersonaSection(),
                  const SizedBox(height: AppLayout.spaceLg),
                  _buildPermissionSection(),
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android) ...[
                    const SizedBox(height: AppLayout.spaceLg),
                    AppSectionCard(
                      padding: EdgeInsets.zero,
                      child: AppSettingsRow(
                        icon: Icons.open_in_new_rounded,
                        title: '跨应用悬浮窗',
                        subtitle: _overlayEnabled == null
                            ? '正在读取悬浮窗状态…'
                            : _overlayBusy
                            ? '正在切换悬浮窗…'
                            : '离开应用后显示 AI 悬浮入口',
                        trailing: Semantics(
                          container: true,
                          label: '跨应用悬浮窗',
                          toggled: _overlayEnabled,
                          enabled: _overlayEnabled != null && !_overlayBusy,
                          excludeSemantics: true,
                          onTap: _overlayEnabled == null || _overlayBusy
                              ? null
                              : _toggleOverlay,
                          child: Switch(
                            value: _overlayEnabled ?? false,
                            onChanged: _overlayEnabled == null || _overlayBusy
                                ? null
                                : (_) => _toggleOverlay(),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppLayout.spaceLg),
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
  }

  Widget _buildPersonaSection() => AppSectionCard(
    padding: EdgeInsets.zero,
    child: AppExpansionTile(
      key: const Key('assistant-persona-section'),
      insetHeader: false,
      headerPadding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceLg,
        vertical: AppLayout.spaceSm,
      ),
      leading: Icon(
        assistantAvatarIcon(_avatar),
        size: AppLayout.iconMd,
        color: AppColors.textSecondary,
      ),
      title: Text('角色与风格', style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(
        '${_personaName.text.trim().isEmpty ? '书祺' : _personaName.text.trim()} · ${_role.label} · ${_replyStyle.label}',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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
          enabled: !_saving && !widget.controller.isBusy,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: '角色名称',
            hintText: '例如：小书、阿青',
          ),
        ),
        const SizedBox(height: AppLayout.spaceMd),
        TextField(
          key: const Key('assistant-user-address'),
          controller: _userAddress,
          enabled: !_saving && !widget.controller.isBusy,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: '对我的称呼',
            hintText: '例如：小刘；留空使用自然称呼',
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
              onChanged: _saving || widget.controller.isBusy
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
              onChanged: _saving || widget.controller.isBusy
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
            spacing: AppLayout.spaceSm,
            runSpacing: AppLayout.spaceSm,
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
                  onSelected: _saving || widget.controller.isBusy
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

  Widget _buildSaveActions() => Align(
    alignment: Alignment.centerRight,
    child: FilledButton(
      key: const Key('assistant-save-settings'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(160, AppLayout.actionMinHeight),
      ),
      onPressed: _saving || widget.controller.isBusy || !_changed || !_valid
          ? null
          : _save,
      child: Text(_saving ? '正在保存…' : '保存设置'),
    ),
  );

  Widget _buildPermissionSection() => AppSectionCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppLayout.spaceLg,
      vertical: AppLayout.spaceMd,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('操作权限', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppLayout.spaceSm),
        for (final mode in AssistantPermissionMode.values)
          Padding(
            padding: EdgeInsets.zero,
            child: Material(
              color: _permission == mode
                  ? AppColors.primarySoft
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppLayout.radiusMd),
              child: ListTile(
                key: Key('assistant-permission-${mode.name}'),
                dense: true,
                visualDensity: VisualDensity.compact,
                selected: _permission == mode,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceMd,
                  vertical: 0,
                ),
                minLeadingWidth: AppLayout.iconMd,
                horizontalTitleGap: AppLayout.spaceSm,
                minVerticalPadding: AppLayout.spaceSm,
                leading: Icon(
                  _permission == mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: AppLayout.iconMd,
                  color: _permission == mode
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                title: Text(
                  mode.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppLayout.spaceXs),
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    child: Text(mode.description),
                  ),
                ),
                onTap: _saving || widget.controller.isBusy
                    ? null
                    : () => setState(() => _permission = mode),
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final persona = _readPersona();
    final permission = _permission;
    setState(() {
      _saving = true;
      _error = null;
      _result = null;
    });
    try {
      persona.validate();
      if (_personaChanged) await widget.controller.savePersona(persona);
      await widget.controller.setPermissionMode(permission);
      if (mounted) setState(() => _result = '设置已保存');
    } catch (error) {
      if (mounted) {
        setState(() => _error = userErrorMessage(error, fallback: '设置未保存，请重试'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
