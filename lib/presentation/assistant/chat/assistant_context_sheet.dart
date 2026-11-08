part of 'assistant_page.dart';

/// 图表只使用控制器已有估算和供应商用量，不推测未记录的成本。
class _AssistantContextSheet extends StatelessWidget {
  const _AssistantContextSheet({required this.controller});
  final AssistantController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final used = controller.estimatedContextTokens;
      final limit = controller.contextInputLimit;
      final ratio = limit <= 0 ? 1.0 : used / limit;
      final usage = controller.sessionUsage;
      final cache = usage.cacheHitRate;
      final colors = Theme.of(context).colorScheme;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.spaceLg,
                  AppLayout.spaceSm,
                  AppLayout.spaceSm,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '上下文与用量',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭用量面板',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.spaceLg,
                    AppLayout.spaceSm,
                    AppLayout.spaceLg,
                    AppLayout.spaceLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SizedBox.square(
                          dimension: 96,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: ratio.clamp(0.0, 1.0),
                                  strokeWidth: 6,
                                  backgroundColor:
                                      colors.surfaceContainerHighest,
                                  color: ratio >= .9
                                      ? colors.error
                                      : ratio >= .75
                                      ? AppColors.warning
                                      : colors.primary,
                                  semanticsLabel: '当前输入预算占用',
                                  semanticsValue:
                                      '${(ratio * 100).toStringAsFixed(1)}%',
                                ),
                              ),
                              Text(
                                '${(ratio * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppLayout.spaceMd),
                      _metric(context, '当前输入估算', '$used / $limit tokens'),
                      _metric(
                        context,
                        '本次输出预留',
                        '${controller.reservedOutputTokens} tokens',
                      ),
                      _metric(
                        context,
                        '模型总窗口',
                        '${controller.contextWindowTokens} tokens',
                      ),
                      const SizedBox(height: AppLayout.spaceSm),
                      OutlinedButton.icon(
                        onPressed:
                            controller.isBusy ||
                                controller.initializing ||
                                controller.needsOutcomeResolution
                            ? null
                            : () async {
                                try {
                                  final result = await controller
                                      .compactConversation();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result == null
                                              ? '当前没有需要压缩的早期对话'
                                              : '已压缩早期对话',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          userErrorMessage(
                                            error,
                                            fallback: '压缩未完成，请重试',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, AppLayout.touchTargetMin),
                        ),
                        icon: const Icon(
                          Icons.compress_rounded,
                          size: AppLayout.iconSm,
                        ),
                        label: Text(controller.compacting ? '正在压缩' : '压缩早期对话'),
                      ),
                      if (usage.hasUsage) ...[
                        const Divider(height: AppLayout.sectionGap),
                        Text(
                          '本会话实际用量',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        _metric(
                          context,
                          '累计输入',
                          '${usage.usage.inputTokens} tokens',
                        ),
                        _metric(
                          context,
                          '累计输出',
                          '${usage.usage.outputTokens} tokens',
                        ),
                        if (cache != null) ...[
                          const SizedBox(height: 8),
                          _metric(
                            context,
                            '正文缓存命中',
                            '${(cache * 100).toStringAsFixed(1)}%',
                          ),
                          LinearProgressIndicator(
                            value: cache.clamp(0.0, 1.0),
                            minHeight: AppLayout.spaceXs,
                            semanticsLabel: '正文缓存命中率',
                          ),
                          if (!usage.cacheComplete)
                            Text(
                              '仅统计已报告缓存的请求。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                        if (usage.hasIncompleteUsage)
                          Text(
                            '${usage.incompleteReports} 次请求未完整报告，用量可能偏低。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _metric(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceXs),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );
}
