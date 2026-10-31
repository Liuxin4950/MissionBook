part of 'assistant_page.dart';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
  });
  final AgentMessage message;
  final bool isUser;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = message.content
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceLg,
                  vertical: AppLayout.spaceMd,
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.onPrimaryContainer,
                                height: 1.5,
                              ),
                        ),
                    for (final block in message.content)
                      if (AssistantAttachment.textFile(block) case final file?)
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
                            style: Theme.of(context).textTheme.titleMedium
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
                              constraints: const BoxConstraints(maxHeight: 240),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  file.text,
                                  style: TextStyle(
                                    color: isUser
                                        ? colors.onPrimaryContainer
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    for (final block in message.content.whereType<ImageBlock>())
                      Padding(
                        padding: const EdgeInsets.only(top: AppLayout.spaceSm),
                        child: _MessageImage(block: block),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.spaceMd,
            vertical: AppLayout.spaceMd,
          ),
          child: AssistantMarkdown(text: text),
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
                      icon: const Icon(Icons.close),
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
