import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_layout.dart';

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

class _AssistantMarkdownState extends State<AssistantMarkdown> {
  Widget? _cached;
  String? _cachedText;
  bool? _cachedCompact;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 主题、字号或方向变化时样式需要重新生成。
    _cached = null;
  }

  @override
  Widget build(BuildContext context) {
    // 已完成的回复不会变化；复用同一棵子树，整页重建时跳过重复的 Markdown 解析。
    if (_cached == null ||
        _cachedText != widget.text ||
        _cachedCompact != widget.compact) {
      _cached = _buildMarkdown(context);
      _cachedText = widget.text;
      _cachedCompact = widget.compact;
    }
    return _cached!;
  }

  Widget _buildMarkdown(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bodyStyle = widget.compact
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyLarge;
    final headingStyle = widget.compact
        ? theme.textTheme.titleSmall
        : theme.textTheme.titleMedium;
    return RepaintBoundary(
      child: SelectionArea(
        child: MarkdownBody(
          data: widget.text,
          fitContent: true,
          softLineBreak: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: bodyStyle?.copyWith(height: 1.5),
            h1: widget.compact ? headingStyle : theme.textTheme.titleLarge,
            h2: headingStyle,
            h3: headingStyle,
            h4: headingStyle,
            h5: headingStyle,
            h6: headingStyle,
            listBullet: bodyStyle,
            blockSpacing: widget.compact
                ? AppLayout.spaceXs
                : AppLayout.spaceSm,
            code: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            codeblockDecoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppLayout.radiusMd),
            ),
            tableColumnWidth: const FlexColumnWidth(),
          ),
          onTapLink: (_, href, _) {
            if (href != null) _openLink(context, href);
          },
          imageBuilder: (uri, title, alt) => TextButton.icon(
            onPressed: () => _openLink(context, uri.toString()),
            icon: const Icon(Icons.image_outlined, size: AppLayout.iconSm),
            label: Text(alt?.isNotEmpty == true ? alt! : title ?? '查看图片链接'),
          ),
        ),
      ),
    );
  }

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
