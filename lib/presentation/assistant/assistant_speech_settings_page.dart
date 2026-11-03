import 'package:flutter/material.dart';
import '../../application/assistant/assistant_controller.dart';
import '../../application/assistant/assistant_speech.dart';
import '../../application/errors/user_error_message.dart';
import '../../core/theme/app_layout.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_settings_row.dart';
import '../widgets/app_dropdown_form_field.dart';
import '../widgets/app_confirm_dialog.dart';
import 'assistant_settings_form.dart';
import 'offline_speech_model_section.dart';
import 'assistant_speech_test_page.dart';

/// 语音方式、离线模型与转写凭据的独立设置页。
class AssistantSpeechSettingsPage extends StatelessWidget {
  const AssistantSpeechSettingsPage({
    super.key,
    required this.controller,
    this.createVoiceTest,
  });
  final AssistantController controller;
  final AssistantVoiceController Function()? createVoiceTest;
  @override
  Widget build(BuildContext context) => AssistantSettingsLoader(
    controller: controller,
    title: '语音输入',
    builder: (_) =>
        _SpeechForm(controller: controller, createVoiceTest: createVoiceTest),
  );
}

class _SpeechForm extends StatefulWidget {
  const _SpeechForm({required this.controller, this.createVoiceTest});
  final AssistantController controller;
  final AssistantVoiceController Function()? createVoiceTest;
  @override
  State<_SpeechForm> createState() => _SpeechFormState();
}

class _SpeechFormState extends State<_SpeechForm> {
  late final _speechEndpoint = TextEditingController(
    text: widget.controller.speechSettings.endpoint,
  );
  late final _speechModel = TextEditingController(
    text: widget.controller.speechSettings.model,
  );
  final _speechCredential = TextEditingController();
  late bool _transcription = widget.controller.speechSettings.useTranscription;
  bool _saving = false, _showKey = false;
  String? _result, _error;
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
  String? get _validationError {
    try {
      _readSpeechSettings().validate();
      return null;
    } on ArgumentError catch (error) {
      return userErrorMessage(error, fallback: '请检查转写设置');
    }
  }

  void _changedListener() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    for (final field in [_speechEndpoint, _speechModel, _speechCredential]) {
      field.addListener(_changedListener);
    }
    widget.controller.addListener(_changedListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changedListener);
    for (final field in [_speechEndpoint, _speechModel, _speechCredential]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AssistantSettingsForm(
    title: '语音输入',
    changed: _speechChanged,
    busy: _saving || widget.controller.isBusy,
    error: _error ?? (_speechChanged ? _validationError : null),
    message: _result,
    onSave: _speechChanged && _validationError == null ? _save : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSpeechSection(),
        if (widget.createVoiceTest != null) ...[
          const SizedBox(height: AppLayout.spaceLg),
          AppSectionCard(
            padding: EdgeInsets.zero,
            child: AppSettingsRow(
              key: const Key('assistant-speech-test'),
              icon: Icons.mic_outlined,
              title: '试用语音',
              subtitle: _speechChanged ? '请先保存当前修改' : '录音并检查识别文字',
              enabled: !_saving && !widget.controller.isBusy && !_speechChanged,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => AssistantSpeechTestPage(
                    createVoice: widget.createVoiceTest!,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
  Future<void> _save() async {
    if (_saving || widget.controller.isBusy) return;
    FocusScope.of(context).unfocus();
    final settings = _readSpeechSettings();
    final credential = _speechCredential.text.trim();
    setState(() {
      _saving = true;
      _error = null;
      _result = null;
    });
    try {
      await widget.controller.saveSpeechSettings(
        settings,
        credential: credential.isEmpty ? null : credential,
      );
      if (mounted) {
        _speechCredential.clear();
        setState(() => _result = '设置已保存');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = userErrorMessage(error, fallback: '设置未保存，请重试'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearSpeechKey() async {
    final accepted = await AppConfirmDialog.show(
      context: context,
      title: '清除转写 Key？',
      message: '清除后，需认证的转写服务将无法使用。',
      cancelText: '保留 Key',
      confirmText: '清除 Key',
    );
    if (!accepted || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
      _result = null;
    });
    try {
      await widget.controller.saveSpeechSettings(
        widget.controller.speechSettings,
        credential: '',
      );
      if (mounted) {
        _speechCredential.clear();
        setState(() => _result = '已清除转写 Key');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = userErrorMessage(error, fallback: '清除失败，请重试'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
          onChanged: _saving || widget.controller.isBusy
              ? null
              : (value) => setState(() => _transcription = value ?? false),
        ),
        const SizedBox(height: AppLayout.spaceMd),
        if (!_transcription) ...[
          const OfflineSpeechModelSection(),
        ] else ...[
          Text(
            '录音最长 50 秒；录音会发送到你配置的转写服务，使用独立 API Key。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            controller: _speechEndpoint,
            enabled: !_saving && !widget.controller.isBusy,
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
            enabled: !_saving && !widget.controller.isBusy,
            key: const Key('assistant-speech-model'),
            decoration: const InputDecoration(
              labelText: '转写模型名称',
              hintText: '填写服务支持的语音模型',
            ),
          ),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            controller: _speechCredential,
            enabled: !_saving && !widget.controller.isBusy,
            key: const Key('assistant-speech-credential'),
            obscureText: !_showKey,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: '转写 API Key',
              suffixIcon: IconButton(
                tooltip: _showKey ? '隐藏 Key' : '显示 Key',
                onPressed: () => setState(() => _showKey = !_showKey),
                icon: Icon(
                  _showKey
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              hintText: widget.controller.hasTranscriptionCredential
                  ? '已保存，留空保留'
                  : '本机免认证服务可留空',
            ),
          ),
          if (widget.controller.hasTranscriptionCredential)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _saving || widget.controller.isBusy
                    ? null
                    : _clearSpeechKey,
                child: const Text('清除转写 Key'),
              ),
            ),
          const SizedBox(height: AppLayout.spaceSm),
          const Text('浏览器需服务允许 CORS；本机 HTTP 仅限 localhost。'),
        ],
      ],
    ),
  );
}
