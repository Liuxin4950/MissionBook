import 'package:flutter/material.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/colors.dart';
import '../../widgets/app_interactive_surface.dart';
import 'assistant_markdown.dart';

/// 用户正在主动阅读，外层聊天应暂停跟随新增内容。
class AssistantExpansionNotification extends Notification {
  const AssistantExpansionNotification(this.expanded);
  final bool expanded;
}

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.key != null) {
      _expanded =
          PageStorage.maybeOf(
                context,
              )?.readState(context, identifier: widget.key)
              as bool? ??
          _expanded;
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (widget.key != null) {
      PageStorage.maybeOf(
        context,
      )?.writeState(context, _expanded, identifier: widget.key);
    }
    AssistantExpansionNotification(_expanded).dispatch(context);
  }

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
          child: AppInteractiveSurface(
            onTap: _toggle,
            selected: _expanded,
            child: Row(
              children: [
                const Icon(Icons.psychology_outlined, size: AppMetrics.iconSm),
                const SizedBox(width: AppMetrics.spaceSm),
                Text(
                  widget.streaming ? '正在思考' : '思考',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppMetrics.spaceSm),
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
                  size: AppMetrics.iconSm,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(
              left: AppMetrics.iconSm + AppMetrics.spaceSm,
              bottom: AppMetrics.spaceSm,
            ),
            child: AssistantMarkdown(
              text: widget.text,
              compact: true,
              streaming: widget.streaming,
            ),
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
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final saved =
        PageStorage.maybeOf(context)?.readState(context, identifier: widget.key)
            as bool?;
    if (saved != null) {
      _expanded = saved;
      _manuallyToggled = true;
    }
  }

  @override
  void didUpdateWidget(covariant AssistantProcess oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded && !oldWidget.initiallyExpanded) {
      _expanded = true;
    } else if (widget.needsAttention && !oldWidget.needsAttention) {
      _expanded = true;
    } else if (oldWidget.running &&
        !widget.running &&
        !_manuallyToggled &&
        !widget.needsAttention) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).textTheme;
    final body = NotificationListener<AssistantExpansionNotification>(
      onNotification: (notification) {
        if (notification.expanded) {
          _manuallyToggled = true;
          if (widget.key != null) {
            PageStorage.maybeOf(
              context,
            )?.writeState(context, true, identifier: widget.key);
          }
        }
        return false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.children,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _expanded,
          child: AppInteractiveSurface(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
                _manuallyToggled = true;
              });
              if (widget.key != null) {
                PageStorage.maybeOf(
                  context,
                )?.writeState(context, _expanded, identifier: widget.key);
              }
              AssistantExpansionNotification(_expanded).dispatch(context);
            },
            selected: _expanded,
            child: Row(
              children: [
                if (widget.running)
                  const SizedBox.square(
                    dimension: AppMetrics.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.toc_rounded, size: AppMetrics.iconSm),
                const SizedBox(width: AppMetrics.spaceSm),
                Expanded(
                  child: Text(
                    '${widget.label}${widget.operationCount == 0 ? '' : ' · ${widget.operationCount} 项操作'}',
                    style: styles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: AppMetrics.iconSm,
                ),
              ],
            ),
          ),
        ),
        if (_expanded && widget.children.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppMetrics.spaceSm),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.hairline)),
            ),
            padding: const EdgeInsets.only(left: AppMetrics.spaceSm),
            child: body,
          ),
      ],
    );
  }
}
