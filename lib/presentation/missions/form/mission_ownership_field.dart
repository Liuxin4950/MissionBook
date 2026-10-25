import 'package:flutter/material.dart';
import '../../../application/missions/mission_service.dart';
import '../../../domain/entities/mission_ownership.dart';
import '../../../core/theme/colors.dart';

/// 任务表单的可选归属；默认独立创建，用户点击后才读取目标和节点供选择。
class MissionOwnershipField extends StatefulWidget {
  const MissionOwnershipField({
    super.key,
    required this.service,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final MissionService service;
  final MissionOwnership value;
  final bool enabled;
  final ValueChanged<MissionOwnership> onChanged; // 把选择结果交回表单，真正保存仍由表单统一发起。
  @override
  State<MissionOwnershipField> createState() => _MissionOwnershipFieldState();
}

class _MissionOwnershipFieldState extends State<MissionOwnershipField> {
  Future<MissionOwnershipInfo?>? _info;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _info = widget.value.goalId == null
        ? null
        : widget.service.findOwnershipInfo(widget.value);
    _info?.ignore();
  }

  @override
  void didUpdateWidget(covariant MissionOwnershipField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.service != widget.service) {
      _load();
    }
  }

  Future<void> _choose() async {
    if (_opening || !widget.enabled) return;
    setState(() => _opening = true);
    try {
      final choices = widget.service
          .findGoalChoices(); // 这次打开重新读取，避免使用之前缓存的归档状态。
      choices.ignore();
      final selected = await showModalBottomSheet<MissionOwnership>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: .85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '任务归属',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: '关闭归属选择',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              ListTile(
                key: const Key('ownership-independent'),
                leading: const Icon(Icons.task_alt),
                title: const Text('独立任务'),
                subtitle: const Text('不关联目标或节点，直接创建'),
                onTap: () => Navigator.pop(context, const MissionOwnership()),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<MissionGoalChoices>>(
                  future: choices,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          '暂时无法读取目标，请关闭后重试\n仍可选择独立任务',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          '暂无正在推进的目标\n可以直接创建独立任务',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView(
                      children: [
                        for (final choice in snapshot.data!) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                            child: Text(
                              choice.goal.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          ListTile(
                            key: Key('ownership-goal-${choice.goal.id}'),
                            leading: const Icon(Icons.flag_outlined),
                            title: const Text('只关联此目标'),
                            onTap: () => Navigator.pop(
                              context,
                              MissionOwnership(goalId: choice.goal.id),
                            ),
                          ),
                          for (final node in choice.nodes.where(
                            (node) => node.archivedAt == null,
                          ))
                            ListTile(
                              key: Key('ownership-node-${node.id}'),
                              leading: const Icon(Icons.account_tree_outlined),
                              title: Text(node.title),
                              subtitle: Text(
                                choice
                                    .resolve(
                                      MissionOwnership(
                                        goalId: choice.goal.id,
                                        goalNodeId: node.id,
                                      ),
                                    )
                                    .label,
                              ),
                              onTap: () => Navigator.pop(
                                context,
                                MissionOwnership(
                                  goalId: choice.goal.id,
                                  goalNodeId: node.id,
                                ),
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
      if (selected != null && mounted) widget.onChanged(selected);
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          _load();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MissionOwnershipInfo?>(
    key: ValueKey(widget.value), // 换归属时重新建立查询状态，独立任务不会残留上个节点的失效提示。
    future: _info,
    builder: (context, snapshot) {
      var label = '独立任务';
      if (widget.value.goalId != null) {
        label =
            snapshot.data?.label ??
            (snapshot.hasError ? '归属读取失败，点击重新选择' : '正在读取原归属…');
      }
      final info = snapshot.data;
      final names = info == null
          ? [label]
          : [info.goal.title, ...info.path.map((node) => node.title)];
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('任务归属（可选）', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('mission-ownership'),
                borderRadius: BorderRadius.circular(12),
                onTap: widget.enabled && !_opening ? _choose : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (var i = 0; i < names.length; i++) ...[
                              if (i > 0)
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              if (info != null && i == names.length - 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    names[i],
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                )
                              else
                                Text(
                                  names[i],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.expand_more,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (info?.available == false)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '原归属目前不可用于新任务，请选择其他归属或独立任务',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                ),
              ),
          ],
        ),
      );
    },
  );
}
