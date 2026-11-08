import 'package:flutter/material.dart';

import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import 'assistant_markdown.dart';

/// 思考是处理过程中的一行；默认收起，预览与正文不共用回答卡片。
class AssistantThinking extends StatefulWidget {
  const AssistantThinking({
    super.key,
    required this.text,
    this.streaming = false,
  });
  final String text;
  final bool streaming;

  @override
  State<AssistantThinking> createState() => _AssistantThinkingState();
}

class _AssistantThinkingState extends State<AssistantThinking> {
  bool _expanded = false;

  String get _preview {
    final paragraphs = widget.text.trim().split(RegExp(r'\n\s*\n'));
    final paragraph = widget.streaming && paragraphs.length > 1
        ? paragraphs[paragraphs.length - 2]
        : paragraphs.first;
    return paragraph.split('\n').first.replaceAll('**', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _expanded,
          child: TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, AppLayout.touchTargetMin),
              foregroundColor: AppColors.textSecondary,
              textStyle: text.bodySmall,
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_outlined, size: AppLayout.iconSm),
                const SizedBox(width: AppLayout.spaceSm),
                Text(widget.streaming ? '正在思考' : '思考'),
                const SizedBox(width: AppLayout.spaceSm),
                Expanded(
                  child: Text(
                    _expanded ? '' : _preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                    textAlign: TextAlign.start,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: AppLayout.iconSm,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(
              left: AppLayout.iconSm + AppLayout.spaceSm,
              bottom: AppLayout.spaceSm,
            ),
            child: widget.streaming
                // 流式思考每几十毫秒变化一次，持续解析 Markdown 会拖垮整轮帧率。
                ? Text(
                    widget.text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.5),
                  )
                : AssistantMarkdown(text: widget.text, compact: true),
          ),
      ],
    );
  }
}

/// 一次用户输入的思考、工具和中间说明，保持原消息顺序。
class AssistantProcess extends StatefulWidget {
  const AssistantProcess({
    super.key,
    required this.running,
    required this.needsAttention,
    required this.label,
    required this.operationCount,
    required this.children,
    this.initiallyExpanded = false,
  });
  final bool running;
  final bool needsAttention;
  final String label;
  final int operationCount;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<AssistantProcess> createState() => _AssistantProcessState();
}

class _AssistantProcessState extends State<AssistantProcess> {
  late bool _expanded =
      widget.initiallyExpanded || widget.running || widget.needsAttention;
  late bool _manuallyToggled = widget.initiallyExpanded;
  final _scroll = ScrollController();
  bool _followOutput = true;

  void _followLatest() {
    if (!_expanded || !_followOutput || !widget.running) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients && _followOutput) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AssistantProcess oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.needsAttention && !oldWidget.needsAttention) {
      _expanded = true;
    } else if (oldWidget.running &&
        !widget.running &&
        !_manuallyToggled &&
        !widget.needsAttention) {
      _expanded = false;
    }
    _followLatest();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).textTheme;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.children,
    );
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _expanded,
          child: TextButton(
            onPressed: () => setState(() {
              _expanded = !_expanded;
              _manuallyToggled = true;
              _followOutput = widget.running;
              _followLatest();
            }),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, AppLayout.touchTargetMin),
              foregroundColor: AppColors.textSecondary,
              textStyle: styles.bodySmall,
            ),
            child: Row(
              children: [
                if (widget.running)
                  const SizedBox.square(
                    dimension: AppLayout.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.toc_rounded, size: AppLayout.iconSm),
                const SizedBox(width: AppLayout.spaceSm),
                Expanded(
                  child: Text(
                    '${widget.label}${widget.operationCount == 0 ? '' : ' · ${widget.operationCount} 项操作'}',
                    style: styles.bodySmall,
                    textAlign: TextAlign.start,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: AppLayout.iconSm,
                ),
              ],
            ),
          ),
        ),
        if (_expanded && widget.children.isNotEmpty)
          Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.hairline)),
            ),
            padding: const EdgeInsets.only(left: AppLayout.spaceSm),
            child: widget.needsAttention
                ? body
                : ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (availableHeight * .35).clamp(
                        AppLayout.touchTargetMin * 2,
                        AppLayout.touchTargetMin * 5,
                      ),
                    ),
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: (_) {
                        if (_scroll.hasClients) {
                          _followOutput =
                              _scroll.position.extentAfter < AppLayout.spaceXxl;
                        }
                        return true;
                      },
                      child: SingleChildScrollView(
                        controller: _scroll,
                        child: body,
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}
