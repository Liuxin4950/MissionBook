import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_layout.dart';
import 'assistant_markdown_cache.dart';
import 'assistant_markdown_chart.dart';

/// 模型正文按 Markdown 显示；链接由用户点击后打开，图片链接不自动读取文件。
class AssistantMarkdown extends StatefulWidget {
  const AssistantMarkdown({
    super.key,
    required this.text,
    this.compact = false,
  });
  final String text;
  final bool compact;

  @override
  State<AssistantMarkdown> createState() => _AssistantMarkdownState();
}

final _assistantMarkdownAstCache = AssistantMarkdownAstCache();
const _longReplyLength = 4000;

class _AssistantMarkdownState extends State<AssistantMarkdown> {
  List<md.Node>? _nodes;
  MarkdownStyleSheet? _styleSheet;
  String? _renderedText;
  bool? _renderedCompact;
  final ScrollController _longReplyScroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resetRenderedContent();
  }

  @override
  void didUpdateWidget(covariant AssistantMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.compact != widget.compact) {
      _resetRenderedContent();
    }
  }

  void _resetRenderedContent() {
    _nodes = null;
    _styleSheet = null;
    _renderedText = null;
    _renderedCompact = null;
  }

  @override
  void dispose() {
    _longReplyScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_nodes == null ||
        _renderedText != widget.text ||
        _renderedCompact != widget.compact) {
      _nodes = _assistantMarkdownAstCache.parse(widget.text);
      _styleSheet = _createStyleSheet(context);
      _renderedText = widget.text;
      _renderedCompact = widget.compact;
    }

    final nodes = _nodes!;
    final styleSheet = _styleSheet!;
    final markdown = _isLongReply(nodes)
        ? _buildLongReply(context, nodes, styleSheet)
        : _buildBody(nodes, styleSheet);
    return RepaintBoundary(
      child: SelectionArea(
        contextMenuBuilder: (context, state) =>
            AdaptiveTextSelectionToolbar.buttonItems(
              anchors: state.contextMenuAnchors,
              buttonItems: state.contextMenuButtonItems
                  .where((item) => item.type == ContextMenuButtonType.copy)
                  .toList(),
            ),
        child: markdown,
      ),
    );
  }

  MarkdownStyleSheet _createStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bodyStyle = widget.compact
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyLarge;
    final headingStyle = widget.compact
        ? theme.textTheme.titleSmall
        : theme.textTheme.titleMedium;
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: bodyStyle?.copyWith(height: 1.5),
      h1: widget.compact ? headingStyle : theme.textTheme.titleLarge,
      h2: headingStyle,
      h3: headingStyle,
      h4: headingStyle,
      h5: headingStyle,
      h6: headingStyle,
      listBullet: bodyStyle,
      blockSpacing: widget.compact ? AppLayout.spaceXs : AppLayout.spaceSm,
      code: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
      ),
      tableColumnWidth: const FlexColumnWidth(),
    );
  }

  bool _isLongReply(List<md.Node> nodes) =>
      !widget.compact &&
      (widget.text.length >= _longReplyLength || nodes.length >= 16);

  Widget _buildBody(List<md.Node> nodes, MarkdownStyleSheet styleSheet) {
    if (nodes.length == 1) return _block(nodes.single, styleSheet, 0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < nodes.length; index++)
          _block(nodes[index], styleSheet, index),
      ],
    );
  }

  Widget _buildLongReply(
    BuildContext context,
    List<md.Node> nodes,
    MarkdownStyleSheet styleSheet,
  ) {
    final maxHeight = math.min(
      560.0,
      math.max(160.0, MediaQuery.sizeOf(context).height * .62),
    );
    return SizedBox(
      height: maxHeight,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          controller: _longReplyScroll,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _longReplyScroll,
            padding: EdgeInsets.zero,
            itemCount: nodes.length,
            itemBuilder: (_, index) => _block(nodes[index], styleSheet, index),
          ),
        ),
      ),
    );
  }

  Widget _block(md.Node node, MarkdownStyleSheet styleSheet, int index) =>
      _AssistantMarkdownBlock(
        key: ValueKey('markdown-block-$index'),
        node: node,
        styleSheet: styleSheet,
        openLink: _openLink,
      );

  Future<void> _openLink(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    var opened = false;
    if (uri != null &&
        ['https', 'http'].contains(uri.scheme) &&
        uri.host.isNotEmpty) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // 不支持的系统/未注册的浏览器仍可复制，不能静默吞掉点击。
      }
    }
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('无法打开该链接，可以复制后查看'),
        action: SnackBarAction(
          label: '复制链接',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
          },
        ),
      ),
    );
  }
}

typedef _LinkOpener = Future<void> Function(BuildContext context, String value);

class _AssistantMarkdownBlock extends StatefulWidget {
  const _AssistantMarkdownBlock({
    super.key,
    required this.node,
    required this.styleSheet,
    required this.openLink,
  });

  final md.Node node;
  final MarkdownStyleSheet styleSheet;
  final _LinkOpener openLink;

  @override
  State<_AssistantMarkdownBlock> createState() =>
      _AssistantMarkdownBlockState();
}

class _AssistantMarkdownBlockState extends State<_AssistantMarkdownBlock>
    implements MarkdownBuilderDelegate {
  List<Widget>? _children;
  final List<GestureRecognizer> _recognizers = [];

  @override
  void didUpdateWidget(covariant _AssistantMarkdownBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.node, widget.node) ||
        oldWidget.styleSheet != widget.styleSheet) {
      _resetRenderedContent();
    }
  }

  void _resetRenderedContent() {
    _disposeRecognizers();
    _children = null;
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _children ??= _buildBlock(context);
    if (_children!.length == 1) return _children!.single;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _children!,
    );
  }

  List<Widget> _buildBlock(BuildContext context) {
    final builder = MarkdownBuilder(
      delegate: this,
      selectable: false,
      styleSheet: widget.styleSheet,
      imageDirectory: null,
      imageBuilder: (uri, title, alt) => TextButton.icon(
        onPressed: () => widget.openLink(context, uri.toString()),
        icon: const Icon(Icons.image_outlined, size: AppLayout.iconSm),
        label: Text(alt?.isNotEmpty == true ? alt! : title ?? '查看图片链接'),
      ),
      checkboxBuilder: null,
      bulletBuilder: null,
      builders: {'missionbook-chart': AssistantChartMarkdownElementBuilder()},
      paddingBuilders: const {},
      fitContent: true,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
      softLineBreak: true,
    );
    return builder.build([widget.node]);
  }

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        if (href != null) widget.openLink(context, href);
      };
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) {
    code = code.replaceAll(RegExp(r'\n$'), '');
    return TextSpan(style: styleSheet.code, text: code);
  }
}
