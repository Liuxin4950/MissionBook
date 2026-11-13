import '../../../application/errors/user_error_message.dart';
import 'dart:async';
import 'dart:convert';

import '../../../application/assistant/assistant_attachment.dart';
import '../../../application/assistant/assistant_image.dart';
import '../../../data/assistant/assistant_attachment_picker.dart';

import '../../records/settings/memory_page.dart';
import '../../records/settings/web_settings_page.dart';
import '../../records/analysis/analysis_settings_page.dart';
import '../../records/shared/record_scope.dart';
import 'assistant_persona_text_page.dart';
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
import '../../widgets/app_selection_option.dart';
import '../../widgets/app_top_bar.dart';

class AssistantSettingsPage extends StatefulWidget {
  const AssistantSettingsPage({
    super.key,
    required this.controller,
    this.pickAvatar,
  });

  final AssistantController controller;
  final Future<AssistantAttachment?> Function()? pickAvatar;

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
  late String? _customRole = widget.controller.persona.customRole;
  late String? _customReplyStyle = widget.controller.persona.customReplyStyle;
  late AssistantAvatar _avatar = widget.controller.persona.avatar;
  late String? _customAvatarBase64 =
      widget.controller.persona.customAvatarBase64;
  bool _pickingAvatar = false;
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
    _customRole = controller.persona.customRole;
    _customReplyStyle = controller.persona.customReplyStyle;
    _avatar = controller.persona.avatar;
    _customAvatarBase64 = controller.persona.customAvatarBase64;
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
      _customRole != widget.controller.persona.customRole ||
      _customReplyStyle != widget.controller.persona.customReplyStyle ||
      _avatar != widget.controller.persona.avatar ||
      _customAvatarBase64 != widget.controller.persona.customAvatarBase64;
  AssistantPersona _readPersona() => AssistantPersona(
    name: _personaName.text.trim(),
    userAddress: _userAddress.text.trim(),
    role: _role,
    replyStyle: _replyStyle,
    customRole: _customRole,
    customReplyStyle: _customReplyStyle,
    avatar: _avatar,
    customAvatarBase64: _customAvatarBase64,
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
                  AppLayout.spaceSm,
                  AppLayout.horizontalPadding(context),
                  AppLayout.spaceMd,
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
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
                  _buildPersonaSection(),
                  const SizedBox(height: AppLayout.spaceLg),
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

  Future<void> _editPersonaText(AssistantPersonaTextKind kind) async {
    final persona = _readPersona();
    final isRole = kind == AssistantPersonaTextKind.role;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AssistantPersonaTextPage(
          kind: kind,
          initialText: isRole
              ? persona.roleInstruction
              : persona.replyStyleInstruction,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (isRole) {
        final preset = AssistantRole.values
            .where((value) => value.instruction == result)
            .firstOrNull;
        _role = preset ?? _role;
        _customRole = preset == null ? result : null;
      } else {
        final preset = AssistantReplyStyle.values
            .where((value) => value.instruction == result)
            .firstOrNull;
        _replyStyle = preset ?? _replyStyle;
        _customReplyStyle = preset == null ? result : null;
      }
    });
  }

  Widget _buildPersonaSection() => AppSectionCard(
    padding: EdgeInsets.zero,
    child: AppExpansionTile(
      key: const Key('assistant-persona-section'),
      insetHeader: false,
      headerPadding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceLg,
        vertical: AppLayout.spaceMd,
      ),
      leading: AssistantPersonaAvatar(
        avatar: _avatar,
        customAvatarBase64: _customAvatarBase64,
        size: 48,
        color: AppColors.primary,
      ),
      title: Text('角色与风格', style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        '${_personaName.text.trim().isEmpty ? '书祺' : _personaName.text.trim()}\n${_readPersona().roleLabel} · ${_readPersona().replyStyleLabel}',
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
        AdaptiveColumns(
          minColumnWidth: 240,
          maxColumns: 2,
          children: [
            TextField(
              key: const Key('assistant-persona-name'),
              controller: _personaName,
              style: Theme.of(context).textTheme.bodyLarge,
              enabled: !_saving && !widget.controller.isBusy,
              maxLength: 24,
              decoration: const InputDecoration(
                labelText: '角色名称',
                hintText: '例如：小书、阿青',
              ),
            ),
            TextField(
              key: const Key('assistant-user-address'),
              controller: _userAddress,
              style: Theme.of(context).textTheme.bodyLarge,
              enabled: !_saving && !widget.controller.isBusy,
              maxLength: 24,
              decoration: const InputDecoration(
                labelText: '对我的称呼',
                hintText: '例如：小刘；留空使用自然称呼',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppLayout.spaceLg),
        AppSettingsRow(
          key: const Key('assistant-persona-role'),
          icon: Icons.badge_outlined,
          title: '角色定位',
          subtitle: _readPersona().roleLabel,
          onTap: _saving || widget.controller.isBusy
              ? null
              : () => _editPersonaText(AssistantPersonaTextKind.role),
        ),
        const Divider(height: 1),
        AppSettingsRow(
          key: const Key('assistant-reply-style'),
          icon: Icons.chat_bubble_outline_rounded,
          title: '回答风格',
          subtitle: _readPersona().replyStyleLabel,
          onTap: _saving || widget.controller.isBusy
              ? null
              : () => _editPersonaText(AssistantPersonaTextKind.replyStyle),
        ),
        const SizedBox(height: AppLayout.spaceLg),
        Text('角色头像', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppLayout.spaceSm),
        AdaptiveColumns(
          minColumnWidth: 104,
          maxColumns: AppLayout.windowClassOf(context) == WindowClass.compact
              ? 2
              : 4,
          spacing: AppLayout.spaceSm,
          children: [
            for (final choice in [
              (AssistantAvatar.spark, '书祺'),
              (AssistantAvatar.book, '书页'),
              (AssistantAvatar.compass, '指南针'),
            ])
              _buildAvatarChoice(choice.$1, choice.$2),
            _buildCustomAvatarChoice(),
          ],
        ),
        if (_customAvatarBase64 != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('assistant-avatar-reset'),
              onPressed: _saving || _pickingAvatar || widget.controller.isBusy
                  ? null
                  : () => setState(() {
                      _customAvatarBase64 = null;
                      _avatar = AssistantAvatar.spark;
                    }),
              child: const Text('恢复默认头像'),
            ),
          ),
        const SizedBox(height: AppLayout.spaceMd),
        Text(
          '保存后应用到助手入口与已有会话。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _buildAvatarChoice(AssistantAvatar avatar, String label) {
    final enabled = !_saving && !_pickingAvatar && !widget.controller.isBusy;
    return TextButton(
      key: Key('assistant-avatar-${avatar.name}'),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      onPressed: enabled
          ? () => setState(() {
              _avatar = avatar;
              _customAvatarBase64 = null;
            })
          : null,
      child: AppSelectionOption(
        selected: _customAvatarBase64 == null && _avatar == avatar,
        enabled: enabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssistantPersonaAvatar(
              avatar: avatar,
              size: 40,
              color: enabled ? AppColors.primary : AppColors.onDisabled,
            ),
            const SizedBox(height: AppLayout.spaceSm),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAvatarChoice() {
    final enabled = !_saving && !_pickingAvatar && !widget.controller.isBusy;
    return TextButton(
      key: const Key('assistant-avatar-custom'),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      onPressed: enabled ? _pickCustomAvatar : null,
      child: AppSelectionOption(
        selected: _customAvatarBase64 != null,
        enabled: enabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pickingAvatar)
              const SizedBox.square(
                dimension: 40,
                child: Padding(
                  padding: EdgeInsets.all(AppLayout.spaceSm),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_customAvatarBase64 != null)
              AssistantPersonaAvatar(
                avatar: AssistantAvatar.spark,
                customAvatarBase64: _customAvatarBase64,
                size: 40,
              )
            else
              const Icon(Icons.add_photo_alternate_outlined, size: 40),
            const SizedBox(height: AppLayout.spaceSm),
            Text(_pickingAvatar ? '处理中' : '自定义', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomAvatar() async {
    if (_pickingAvatar || _saving || widget.controller.isBusy) return;
    setState(() => _pickingAvatar = true);
    try {
      final image = widget.pickAvatar != null
          ? await widget.pickAvatar!()
          : await pickAssistantAttachment(
              image: true,
              confirmButtonText: '选择头像',
              onOversizedImage: (name, bytes) async =>
                  AssistantAttachment.fromBytes(
                    'avatar.png',
                    base64Decode(await prepareAssistantAvatar(bytes)),
                  ),
            );
      if (image == null || !mounted) return;
      final avatar = await prepareAssistantAvatar(image.bytes);
      if (!mounted || widget.controller.isBusy) return;
      setState(() {
        _avatar = AssistantAvatar.spark;
        _customAvatarBase64 = avatar;
        _error = null;
        _result = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(error, fallback: '头像读取失败，请重新选择'),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingAvatar = false);
    }
  }

  Widget _buildSaveActions() => Align(
    alignment: Alignment.centerRight,
    child: FilledButton(
      key: const Key('assistant-save-settings'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(160, AppLayout.actionMinHeight),
      ),
      onPressed:
          _saving ||
              _pickingAvatar ||
              widget.controller.isBusy ||
              !_changed ||
              !_valid
          ? null
          : _save,
      child: Text(_saving ? '正在保存…' : '保存设置'),
    ),
  );

  Widget _buildPermissionSection() => AppSectionCard(
    padding: EdgeInsets.zero,
    child: AppExpansionTile(
      key: const Key('assistant-permission-section'),
      insetHeader: false,
      headerPadding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceLg,
        vertical: AppLayout.spaceSm,
      ),
      leading: const Icon(
        Icons.shield_outlined,
        size: AppLayout.iconMd,
        color: AppColors.textSecondary,
      ),
      title: Text('操作权限', style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(
        _permission.label,
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
