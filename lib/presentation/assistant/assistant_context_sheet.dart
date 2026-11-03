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
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
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
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SizedBox.square(
                          dimension: 112,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: ratio.clamp(0.0, 1.0),
                                  strokeWidth: 8,
                                  backgroundColor:
                                      colors.surfaceContainerHighest,
                                  color: ratio >= .9
                                      ? colors.error
                                      : colors.primary,
                                  semanticsLabel: '当前输入预算占用',
                                  semanticsValue:
                                      '${(ratio * 100).toStringAsFixed(1)}%',
                                ),
                              ),
                              Text(
                                '${(ratio * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
                      const SizedBox(height: 8),
                      const Text(
                        '输入达到可用预算的 80% 时自动压缩早期对话，原始聊天记录仍保留。输入估算不是实际账单。',
                      ),
                      const SizedBox(height: 12),
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
                        icon: const Icon(Icons.compress),
                        label: Text(controller.compacting ? '正在压缩' : '压缩早期对话'),
                      ),
                      const Divider(height: 32),
                      Text(
                        '本会话实际用量',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (usage.hasUsage) ...[
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
                            minHeight: 8,
                            semanticsLabel: '正文缓存命中率',
                          ),
                          if (!usage.cacheComplete)
                            const Text('仅统计供应商报告过缓存的请求。'),
                        ] else
                          const Text('供应商尚未报告可用的缓存命中率。'),
                        if (usage.hasIncompleteUsage)
                          Text('${usage.incompleteReports} 次请求未完整报告，用量可能偏低。'),
                      ] else
                        const Text('尚无供应商报告的用量。'),
                      const SizedBox(height: 12),
                      const Text('包含本会话压缩与重试；后台总结、记忆提取和工具内图片分析尚未计入。'),
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
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(label),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}
