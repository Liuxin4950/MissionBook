part of 'assistant_page.dart';

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onLocalSchedule, required this.onPrompt});
  final Future<void> Function() onLocalSchedule;
  final ValueChanged<String> onPrompt;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final prompts = [
      (
        const Key('assistant-local-today'),
        Icons.today_outlined,
        '查看今天安排',
        () {
          onLocalSchedule();
        },
      ),
      (
        null,
        Icons.event_available_outlined,
        '帮我安排今天',
        () => onPrompt(
          '先看看今天已有的安排，结合相关目标和偏好，帮我提出一份今天的任务计划。自主拆解、估算并说明假设；新任务优先自选时间，改期保留原时间策略，只问影响决策的关键问题。先用计划卡展示提案，确认后再保存。',
        ),
      ),
      (null, Icons.add_task, '创建一个任务', () => onPrompt('创建一个任务：')),
      (
        const Key('assistant-outline-prompt'),
        Icons.account_tree_outlined,
        '拆解学习目标',
        () => onPrompt('我想创建一个学习目标，并拆成分层大纲：\n目标：\n目前基础：\n希望达到的结果：'),
      ),
      (
        const Key('assistant-retry-prompt'),
        Icons.replay_outlined,
        '复盘并重新安排',
        () => onPrompt(
          '请先查找我想复盘的已结束或已取消任务，读取真实执行和失败记录，帮我分析改进点；确认任务和新日期后，创建关联的新尝试，保留原记录。\n任务名称：\n新安排：',
        ),
      ),
      (
        const Key('assistant-adjust-prompt'),
        Icons.edit_calendar_outlined,
        '调整一组安排',
        () => onPrompt(
          '请先核对相关任务与日期安排，帮我用一份可编辑计划卡集中调整，保留未调整任务。\n需要调整的任务：\n可用日期和时间：',
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          paperBackground: true,
          child: Row(
            children: [
              const AppIllustration(
                asset: 'assets/illustrations/assistant-notebook.png',
                width: 64,
                height: 64,
              ),
              const SizedBox(width: AppLayout.spaceMd),
              Expanded(child: Text('今天想做什么？', style: text.titleLarge)),
            ],
          ),
        ),
        const SizedBox(height: AppLayout.sectionGap),
        AdaptiveColumns(
          minColumnWidth: 156,
          maxColumns: 3,
          spacing: AppLayout.spaceMd,
          children: [
            for (final item in prompts)
              Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppLayout.radiusXl),
                child: InkWell(
                  key: item.$1,
                  onTap: item.$4,
                  borderRadius: BorderRadius.circular(AppLayout.radiusXl),
                  child: Padding(
                    padding: const EdgeInsets.all(AppLayout.spaceMd),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppLayout.touchTargetMin,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.$2,
                            color: AppColors.primary,
                            size: AppLayout.iconMd,
                          ),
                          const SizedBox(width: AppLayout.spaceSm),
                          Expanded(
                            child: Text(item.$3, style: text.titleSmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
