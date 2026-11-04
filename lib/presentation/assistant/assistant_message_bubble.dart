part of 'assistant_page.dart';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.visibleContent,
  });
  final AgentMessage message;
  final bool isUser;
  final List<ContentBlock>? visibleContent;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = visibleContent ?? message.content;
    final text = content
        .whereType<TextBlock>()
        .where((block) => AssistantAttachment.textFile(block) == null)
        .map((block) => block.text)
        .join('\n');
    return Padding(
      padding: EdgeInsets.only(top: isUser ? AppLayout.spaceSm : 0),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // AI 回答按阅读区铺开；只设上限会让短段落把整块回复收窄。
              minWidth: isUser ? 0 : constraints.maxWidth.clamp(0, 860),
              maxWidth: isUser
                  ? (constraints.maxWidth * .88).clamp(0, 620)
                  : constraints.maxWidth.clamp(0, 860),
            ),
            child: Material(
              color: isUser
                  ? colors.primaryContainer
                  : colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusLg),
                side: isUser
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.hairline),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppLayout.spaceLg,
                      AppLayout.spaceMd,
                      AppLayout.spaceLg,
                      !isUser && text.isNotEmpty ? 68 : AppLayout.spaceMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (text.isNotEmpty)
                          if (!isUser)
                            AssistantMarkdown(text: text)
                          else
                            SelectableText(
                              text,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: colors.onPrimaryContainer,
                                    height: 1.5,
                                  ),
                            ),
                        for (final block in content)
                          if (AssistantAttachment.textFile(block)
                              case final file?)
                            AppExpansionTile(
                              insetHeader: false,
                              headerPadding: const EdgeInsets.symmetric(
                                vertical: AppLayout.spaceXs,
                              ),
                              childrenPadding: EdgeInsets.zero,
                              iconColor: isUser
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface,
                              title: Text(
                                file.name,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: isUser
                                          ? colors.onPrimaryContainer
                                          : colors.onSurface,
                                    ),
                              ),
                              leading: Icon(
                                Icons.description_outlined,
                                color: isUser
                                    ? colors.onPrimaryContainer
                                    : colors.primary,
                              ),
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 240,
                                  ),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      file.text,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: isUser
                                                ? colors.onPrimaryContainer
                                                : colors.onSurface,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        for (final block in content.whereType<ImageBlock>())
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppLayout.spaceSm,
                            ),
                            child: _MessageImage(block: block),
                          ),
                      ],
                    ),
                  ),
                  if (!isUser && text.isNotEmpty)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: _CopyReplyButton(text: text),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyReplyButton extends StatelessWidget {
  const _CopyReplyButton({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: '复制回复',
    style: IconButton.styleFrom(
      shape: const CircleBorder(),
      fixedSize: const Size.square(48),
    ),
    icon: const Icon(Icons.copy_rounded, size: 20),
    onPressed: () async {
      var feedback = '已复制回复';
      try {
        await Clipboard.setData(ClipboardData(text: text));
      } catch (_) {
        feedback = '复制失败，请重试';
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(feedback)));
    },
  );
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        // 生成中和生成后的回答使用同一阅读宽度，避免结束时横向跳变。
        width: constraints.maxWidth.clamp(0, 860),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppLayout.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.spaceMd,
              vertical: AppLayout.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 逐 token 变化时只排版纯文本；Markdown 解析留给完成后的正式消息。
                if (text.isNotEmpty)
                  RepaintBoundary(
                    child: Text(
                      text,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.5),
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

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.block});
  final ImageBlock block;
  @override
  Widget build(BuildContext context) {
    if (block.url.startsWith('data:image')) {
      final bytes = base64Decode(block.url.split(',').last);
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppLayout.spaceLg),
                    child: InteractiveViewer(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton(
                      tooltip: '关闭图片',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: Image.memory(
            bytes,
            width: 240,
            cacheWidth: 480,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => const Text('图片无法解码'),
          ),
        ),
      );
    }
    if (block.url.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        child: Image.network(block.url, width: 240, fit: BoxFit.contain),
      );
    }
    return Text(
      block.label ?? '云端图片引用',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
