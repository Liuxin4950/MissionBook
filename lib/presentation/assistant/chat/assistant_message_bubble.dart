part of 'assistant_page.dart';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.visibleContent,
    this.streaming = false,
    this.markdownSlice,
    this.firstSlice = true,
    this.lastSlice = true,
  });
  final AgentMessage message;
  final bool isUser;
  final List<ContentBlock>? visibleContent;
  final bool streaming;
  final AssistantMarkdownSlice? markdownSlice;
  final bool firstSlice;
  final bool lastSlice;
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
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(firstSlice ? AppLayout.radiusLg : 0),
                  bottom: Radius.circular(lastSlice ? AppLayout.radiusLg : 0),
                ),
                side: isUser || markdownSlice != null
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.hairline),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppLayout.spaceLg,
                      firstSlice ? AppLayout.spaceMd : 0,
                      AppLayout.spaceLg,
                      lastSlice
                          ? (!isUser && text.isNotEmpty
                                ? 68
                                : AppLayout.spaceMd)
                          : AppLayout.spaceSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (text.isNotEmpty)
                          if (!isUser)
                            AssistantMarkdown(
                              text: text,
                              streaming: streaming,
                              slice: markdownSlice,
                            )
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
                                SelectableText(
                                  file.text,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: isUser
                                            ? colors.onPrimaryContainer
                                            : colors.onSurface,
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
                  if (!isUser && text.isNotEmpty && lastSlice)
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

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.block});
  final ImageBlock block;
  @override
  Widget build(BuildContext context) {
    if (block.url.startsWith('data:image')) {
      final image = _assistantImageProvider(block.url);
      if (image == null) return const Text('图片无法解码');
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            animationStyle: AppMotion.overlayStyle(context),
            builder: (context) => Dialog(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppLayout.spaceLg),
                    child: InteractiveViewer(
                      child: Image(image: image, fit: BoxFit.contain),
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
          child: Image(
            image: ResizeImage(image, width: 480),
            width: 240,
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

// 会话列表滚动卸载消息卡片后仍复用已解码图片；按条目数与总字节数限制缓存。
final _assistantImages = <String, MemoryImage>{};
var _assistantImageBytes = 0;
const _assistantImageCacheEntries = 24;
const _assistantImageCacheLimit = 12 * 1024 * 1024;

MemoryImage? _assistantImageProvider(String dataUrl) {
  final cached = _assistantImages.remove(dataUrl);
  if (cached != null) {
    _assistantImages[dataUrl] = cached;
    return cached;
  }

  late final Uint8List bytes;
  try {
    bytes = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
  } on FormatException {
    return null;
  }
  final image = MemoryImage(bytes);
  if (bytes.lengthInBytes > _assistantImageCacheLimit) return image;
  while (_assistantImages.isNotEmpty &&
      (_assistantImages.length >= _assistantImageCacheEntries ||
          _assistantImageBytes + bytes.lengthInBytes >
              _assistantImageCacheLimit)) {
    final oldestKey = _assistantImages.keys.first;
    final oldest = _assistantImages.remove(oldestKey)!;
    _assistantImageBytes -= oldest.bytes.lengthInBytes;
  }
  _assistantImages[dataUrl] = image;
  _assistantImageBytes += bytes.lengthInBytes;
  return image;
}
