import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 模型正文按 Markdown 显示；链接由用户点击后打开，图片链接不自动读取文件。
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SelectionArea(
      child: MarkdownBody(
        data: text,
        fitContent: true,
        softLineBreak: true,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          h1: theme.textTheme.titleLarge,
          h2: theme.textTheme.titleMedium,
          h3: theme.textTheme.titleSmall,
          blockSpacing: 8,
          code: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          codeblockDecoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          tableColumnWidth: const FlexColumnWidth(),
        ),
        onTapLink: (_, href, _) {
          if (href != null) _openLink(context, href);
        },
        imageBuilder: (uri, title, alt) => TextButton.icon(
          onPressed: () => _openLink(context, uri.toString()),
          icon: const Icon(Icons.image_outlined, size: 18),
          label: Text(alt?.isNotEmpty == true ? alt! : title ?? '查看图片链接'),
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
