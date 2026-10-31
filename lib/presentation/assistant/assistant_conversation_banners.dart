part of 'assistant_page.dart';

class _ReferenceBanner extends StatelessWidget {
  const _ReferenceBanner({required this.controller});
  final AssistantController controller;
  @override
  Widget build(BuildContext context) {
    final reference = controller.reference!;
    return Container(
      width: double.infinity,
      color: AppColors.primarySoft,
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceLg,
        vertical: AppLayout.spaceSm,
      ),
      child: Text(
        '当前${reference.label} · ${reference.title}${reference.path == null ? '' : '\n${reference.path}'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.controller, required this.onSettings});
  final AssistantController controller;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.errorSoft,
    borderRadius: BorderRadius.circular(AppLayout.radiusLg),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceLg,
        vertical: AppLayout.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                controller.errorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ),
          ),
          if (!controller.hasCredential)
            TextButton(onPressed: onSettings, child: const Text('去设置')),
          if (controller.canContinueInterrupted)
            TextButton(
              onPressed: controller.continueInterrupted,
              child: const Text('继续本轮'),
            ),
          IconButton(
            tooltip: '关闭错误提示',
            onPressed: controller.clearError,
            icon: const Icon(Icons.close, size: AppLayout.iconSm),
          ),
        ],
      ),
    ),
  );
}

class _CredentialBanner extends StatelessWidget {
  const _CredentialBanner({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.accentSoft,
    borderRadius: BorderRadius.circular(AppLayout.radiusLg),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceLg,
        vertical: AppLayout.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '配置模型后可创建、修改和安排任务；本地快捷查询仍可使用',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onPressed, child: const Text('配置模型')),
        ],
      ),
    ),
  );
}

class _LocalScheduleCard extends StatelessWidget {
  const _LocalScheduleCard({required this.controller, required this.onOpen});
  final AssistantController controller;
  final void Function(String, String) onOpen;
  @override
  Widget build(BuildContext context) {
    final missions = controller.localSchedule!;
    return Padding(
      padding: EdgeInsets.zero,
      child: AppSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${controller.localScheduleDate} · 本地快照',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '收起本地日程',
                  onPressed: controller.clearLocalSchedule,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (missions.isEmpty)
              Text('这一天还没有任务', style: Theme.of(context).textTheme.bodyMedium)
            else
              for (final item in missions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.mission.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    '${item.schedule.plannedDurationMinutes} 分钟 · ${phaseLabel(item.phase)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpen('mission', item.mission.id),
                ),
          ],
        ),
      ),
    );
  }
}
