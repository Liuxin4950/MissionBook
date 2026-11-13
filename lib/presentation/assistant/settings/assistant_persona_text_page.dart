import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/assistant/assistant_settings.dart';
import '../../../core/theme/app_layout.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/page_footer_bar.dart';

enum AssistantPersonaTextKind { role, replyStyle }

/// 编辑定位或回答风格，完成后交回设置草稿，由助手设置统一保存。
class AssistantPersonaTextPage extends StatefulWidget {
  const AssistantPersonaTextPage({
    super.key,
    required this.kind,
    required this.initialText,
  });

  final AssistantPersonaTextKind kind;
  final String initialText;

  @override
  State<AssistantPersonaTextPage> createState() =>
      _AssistantPersonaTextPageState();
}

class _AssistantPersonaTextPageState extends State<AssistantPersonaTextPage> {
  late final _text = TextEditingController(text: widget.initialText);
  bool _allowPop = false;
  bool _asking = false;
  bool get _isRole => widget.kind == AssistantPersonaTextKind.role;
  String get _title => _isRole ? '角色定位' : '回答风格';
  String get _example => _isRole
      ? '你是我的学习教练，帮助我理解知识并完成练习。先了解我的基础，再用小例子解释难点，每次给出一个可执行的练习。'
      : '先用一句话给结论，再列出最多三条要点。语言直接、具体，遇到复杂问题用一个简短例子说明。';
  String get _generationPrompt => _isRole
      ? '请帮我编写可直接粘贴到 MissionBook 的角色定位。\n'
            '我的使用场景是【填写学习、工作或生活场景】。\n'
            '我希望助手重点帮助【填写具体事项】，采用【填写协作方式】。\n'
            '用三至五句话写清职责、关注重点和信息不全时如何处理。只输出定位正文，保留实际工具权限与事实约束。'
      : '请帮我编写可直接粘贴到 MissionBook 的回答风格。\n'
            '我希望语气【填写偏好】，回答长度【填写偏好】，优先使用【段落、清单、表格或例子】。\n'
            '我不喜欢【填写需要避免的表达】。\n'
            '用三至五句话说明语气、结构、详细程度和解释方式。只输出风格正文。';
  List<({String label, String text})> get _presets => _isRole
      ? [
          for (final value in AssistantRole.values)
            (label: value.label, text: value.instruction),
        ]
      : [
          for (final value in AssistantReplyStyle.values)
            (label: value.label, text: value.instruction),
        ];

  String? get _error {
    try {
      AssistantPersona.validateInstruction(_text.text, _title);
      return null;
    } on ArgumentError catch (error) {
      return error.message.toString();
    }
  }

  void _finish([String? result]) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _back() async {
    if (_asking) return;
    _asking = true;
    final leave =
        _text.text.trim() == widget.initialText.trim() ||
        await AppConfirmDialog.show(
          context: context,
          title: '放弃$_title修改？',
          message: '本次编辑尚未应用。',
          cancelText: '继续编辑',
          confirmText: '放弃修改',
        );
    _asking = false;
    if (mounted && leave) _finish();
  }

  Future<void> _copy(String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制')));
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('复制失败，请重试')));
    }
  }

  Future<void> _showHelp() {
    FocusScope.of(context).unfocus();
    return showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppLayout.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('$_title怎么写', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppLayout.spaceLg),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('参考示例', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: () => _copy(_example),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('复制示例'),
                  ),
                ],
              ),
              SelectableText(_example),
              const SizedBox(height: AppLayout.spaceLg),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '让 AI 帮你写',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: () => _copy(_generationPrompt),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('复制提示词'),
                  ),
                ],
              ),
              SelectableText(_generationPrompt),
              const SizedBox(height: AppLayout.spaceLg),
              OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('知道了'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<String>(
    canPop: _allowPop || _text.text.trim() == widget.initialText.trim(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: AppTopBar(
        title: _title,
        maxContentWidth: AppLayout.formMaxWidth,
        onBack: _back,
        actions: [
          IconButton(
            key: const Key('persona-text-help'),
            tooltip: '写法参考',
            onPressed: _showHelp,
            icon: const Icon(Icons.error_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
            child: ListView(
              padding: AppLayout.pagePadding(context),
              children: [
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '预设参考',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppLayout.spaceSm),
                      Wrap(
                        spacing: AppLayout.spaceSm,
                        runSpacing: AppLayout.spaceSm,
                        children: [
                          for (final preset in _presets)
                            ChoiceChip(
                              label: Text(preset.label),
                              selected: _text.text.trim() == preset.text,
                              onSelected: (_) =>
                                  setState(() => _text.text = preset.text),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppLayout.spaceLg),
                      TextField(
                        key: const Key('persona-text-input'),
                        controller: _text,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: AssistantPersona.maxInstructionLength,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: _title,
                          alignLabelWithHint: true,
                          hintText: _isRole
                              ? '写清希望助手扮演谁、重点帮什么、怎样协作。'
                              : '写清语气、篇幅、回答结构，以及是否需要例子。',
                          errorText: _error,
                          errorMaxLines: 3,
                          counterText:
                              '${_text.text.trim().runes.length}/${AssistantPersona.maxInstructionLength}',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: PageFooterBar(
            maxContentWidth: AppLayout.formMaxWidth,
            child: FilledButton(
              key: const Key('persona-text-done'),
              onPressed: _error == null
                  ? () => _finish(_text.text.trim())
                  : null,
              child: const Text('完成'),
            ),
          ),
        ),
      ),
    ),
  );
}
