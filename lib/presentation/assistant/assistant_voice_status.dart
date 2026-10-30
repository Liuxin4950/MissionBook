import 'package:flutter/material.dart';

import '../../application/assistant/assistant_speech.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/app_layout.dart';

/// 浮层与对话输入共用的真实录音状态，不以装饰波形模拟音量。
class AssistantVoiceStatus extends StatelessWidget {
  const AssistantVoiceStatus({super.key, required this.voice, this.onCancel});
  final AssistantVoiceController voice;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final pending = voice.busy;
    final recording = voice.listening;
    final title = voice.starting
        ? '正在准备麦克风'
        : voice.stopping
        ? '正在识别语音'
        : pending
        ? '正在取消'
        : recording
        ? '正在录音'
        : voice.error != null
        ? '语音未完成'
        : voice.text.trim().isNotEmpty
        ? '检查文字后发送'
        : '可以开始说话';
    final elapsed =
        '${voice.elapsedSeconds ~/ 60}:${(voice.elapsedSeconds % 60).toString().padLeft(2, '0')}';
    return Semantics(
      liveRegion: !recording,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.spaceMd,
          vertical: AppLayout.spaceSm,
        ),
        decoration: BoxDecoration(
          color: voice.error == null
              ? AppColors.primarySoft
              : Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        ),
        child: Row(
          children: [
            if (pending)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                voice.error != null
                    ? Icons.info_outline
                    : recording
                    ? Icons.mic_rounded
                    : Icons.check_circle_outline,
                size: AppLayout.iconMd,
                color: voice.error == null
                    ? AppColors.primary
                    : AppColors.error,
              ),
            const SizedBox(width: AppLayout.spaceSm),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
            ),
            if (recording)
              Text(
                elapsed,
                key: const Key('assistant-recording-time'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            if (onCancel != null)
              IconButton(
                tooltip: '取消本次语音',
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: AppLayout.iconSm),
              ),
          ],
        ),
      ),
    );
  }
}

/// 转写完成后可原位修正；识别过程不弹出键盘。
class AssistantVoiceDraft extends StatefulWidget {
  const AssistantVoiceDraft({super.key, required this.voice});
  final AssistantVoiceController voice;
  @override
  State<AssistantVoiceDraft> createState() => _AssistantVoiceDraftState();
}

class _AssistantVoiceDraftState extends State<AssistantVoiceDraft> {
  late final _text = TextEditingController(text: widget.voice.text);
  @override
  void didUpdateWidget(AssistantVoiceDraft oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.voice.text) {
      _text.value = TextEditingValue(
        text: widget.voice.text,
        selection: TextSelection.collapsed(offset: widget.voice.text.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('assistant-voice-transcript'),
    controller: _text,
    readOnly: widget.voice.listening || widget.voice.busy,
    minLines: 2,
    maxLines: 5,
    onChanged: widget.voice.editText,
    decoration: const InputDecoration(
      labelText: '识别文字',
      hintText: '可以修改后再发送',
      contentPadding: EdgeInsets.all(AppLayout.spaceMd),
    ),
  );
}
