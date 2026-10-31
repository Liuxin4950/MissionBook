part of 'assistant_page.dart';

class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.persona,
    required this.onLocalSchedule,
    required this.onPrompt,
  });
  final AssistantPersona persona;
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
        '读取这台设备上的真实日程',
        () {
          onLocalSchedule();
        },
      ),
      (
        null,
        Icons.event_available_outlined,
        '帮我安排今天',
        '结合已有安排，规划下一步',
        () => onPrompt(
          '先看看今天已有的安排，结合我的目标，帮我提出一份今天的任务计划。可用时间不明确时先问我，用计划卡集中展示新建或改期的任务。',
        ),
      ),
      (
        null,
        Icons.add_task,
        '创建一个任务',
        '把一件想做的事落到具体行动',
        () => onPrompt('创建一个任务：'),
      ),
      (
        const Key('assistant-outline-prompt'),
        Icons.account_tree_outlined,
        '拆解学习目标',
        '从方向到阶段，再到任务',
        () => onPrompt('我想创建一个学习目标，并拆成分层大纲：\n目标：\n目前基础：\n希望达到的结果：'),
      ),
      (
        const Key('assistant-retry-prompt'),
        Icons.replay_outlined,
        '复盘并重新安排',
        '回看真实记录，保留原结果',
        () => onPrompt(
          '请先查找我想复盘的已结束或已取消任务，读取真实执行和失败记录，帮我分析改进点；确认任务和新日期后，创建关联的新尝试，保留原记录。\n任务名称：\n新安排：',
        ),
      ),
      (
        const Key('assistant-adjust-prompt'),
        Icons.edit_calendar_outlined,
        '调整一组安排',
        '集中检查与修改多个任务',
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
          child: LayoutBuilder(
            builder: (context, box) {
              final wide =
                  box.maxWidth >=
                  620 * MediaQuery.textScalerOf(context).scale(1);
              final picture = AppIllustration(
                asset: 'assets/illustrations/assistant-notebook.png',
                width: wide ? 160 : 120,
                height: wide ? 136 : 96,
              );
              final words = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '把想法变成可检查的行动',
                    style: wide ? text.headlineSmall : text.titleLarge,
                  ),
                  const SizedBox(height: AppLayout.spaceMd),
                  Text(
                    '${persona.name} · ${persona.role.label} · ${persona.replyStyle.label}',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppLayout.spaceSm),
                  Text('告诉我想做的事，一起拆解目标、安排任务、回看行动。', style: text.bodyMedium),
                ],
              );
              return wide
                  ? Row(
                      children: [
                        Expanded(child: words),
                        const SizedBox(width: 24),
                        picture,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [picture, const SizedBox(height: 16), words],
                    );
            },
          ),
        ),
        const SizedBox(height: AppLayout.spaceXxl),
        Text('从这里开始', style: text.titleMedium),
        const SizedBox(height: AppLayout.spaceMd),
        AdaptiveColumns(
          minColumnWidth: 220,
          maxColumns: 3,
          spacing: AppLayout.spaceMd,
          children: [
            for (final item in prompts)
              Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppLayout.radiusXl),
                child: InkWell(
                  key: item.$1,
                  onTap: item.$5,
                  borderRadius: BorderRadius.circular(AppLayout.radiusXl),
                  child: Padding(
                    padding: const EdgeInsets.all(AppLayout.spaceLg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.$2,
                          color: AppColors.primary,
                          size: AppLayout.iconMd,
                        ),
                        const SizedBox(width: AppLayout.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.$3, style: text.titleSmall),
                              const SizedBox(height: AppLayout.spaceXs),
                              Text(item.$4, style: text.bodySmall),
                            ],
                          ),
                        ),
                      ],
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
