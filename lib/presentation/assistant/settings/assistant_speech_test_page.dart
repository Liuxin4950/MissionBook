import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/assistant/assistant_speech.dart';
import '../../../core/theme/app_layout.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_top_bar.dart';
import '../shared/assistant_voice_status.dart';

/// 独立录音试用，只展示识别结果；不修改聊天草稿，不创建会话。
class AssistantSpeechTestPage extends StatefulWidget {
  const AssistantSpeechTestPage({super.key, required this.createVoice});
  final AssistantVoiceController Function() createVoice;
  @override
  State<AssistantSpeechTestPage> createState() =>
      _AssistantSpeechTestPageState();
}

class _AssistantSpeechTestPageState extends State<AssistantSpeechTestPage>
    with WidgetsBindingObserver {
  late final _voice = widget.createVoice();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_voice.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: '试用语音'),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: AnimatedBuilder(
            animation: _voice,
            builder: (context, _) => ListView(
              padding: AppLayout.pagePadding(context),
              children: [
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '使用已保存的识别方式与服务。转写服务会接收本次录音，并可能计费。识别文字仅在这里展示。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppLayout.spaceLg),
                      AssistantVoiceStatus(
                        voice: _voice,
                        onCancel: _voice.listening || _voice.busy
                            ? _voice.cancel
                            : null,
                      ),
                      const SizedBox(height: AppLayout.spaceLg),
                      if (_voice.text.isNotEmpty) ...[
                        SelectableText(
                          _voice.text,
                          key: const Key('speech-test-result'),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppLayout.spaceLg),
                      ],
                      FilledButton.icon(
                        key: const Key('speech-test-record'),
                        onPressed: _voice.busy
                            ? null
                            : _voice.listening
                            ? _voice.stop
                            : _voice.start,
                        icon: Icon(
                          _voice.listening
                              ? Icons.stop_rounded
                              : Icons.mic_outlined,
                        ),
                        label: Text(_voice.listening ? '停止并识别' : '开始录音'),
                      ),
                    ],
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
