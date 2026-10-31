import 'package:flutter/material.dart';
import '../../../application/missions/mission_service.dart';
import '../../../domain/entities/mission_ownership.dart';
import '../../../core/theme/colors.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../../core/theme/app_layout.dart';

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
      final selected = await showAdaptiveSheet<MissionOwnership>(
        context: context,
        builder: (context) =>
            _OwnershipPicker(service: widget.service, value: widget.value),
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
        padding: const EdgeInsets.only(bottom: AppLayout.spaceXxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('任务归属（可选）', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppLayout.spaceSm),
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('mission-ownership'),
                borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                onTap: widget.enabled && !_opening ? _choose : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppLayout.spaceSm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppLayout.spaceSm,
                          runSpacing: AppLayout.spaceSm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (var i = 0; i < names.length; i++) ...[
                              if (i > 0)
                                const Icon(
                                  Icons.chevron_right,
                                  size: AppLayout.iconSm,
                                  color: AppColors.textSecondary,
                                ),
                              if (info != null && i == names.length - 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppLayout.spaceMd,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(
                                      AppLayout.radiusXl,
                                    ),
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
                      const SizedBox(width: AppLayout.spaceSm),
                      const Icon(
                        Icons.expand_more,
                        size: AppLayout.iconMd,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (info?.available == false)
              Padding(
                padding: const EdgeInsets.only(top: AppLayout.spaceSm),
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

/// 搜索状态只在弹层内保留，关闭后不会改动表单已有归属。
class _OwnershipPicker extends StatefulWidget {
  const _OwnershipPicker({required this.service, required this.value});
  final MissionService service;
  final MissionOwnership value;
  @override
  State<_OwnershipPicker> createState() => _OwnershipPickerState();
}

class _OwnershipPickerState extends State<_OwnershipPicker> {
  final _search = TextEditingController();
  late Future<List<MissionGoalChoices>> _choices;

  @override
  void initState() {
    super.initState();
    _read();
  }

  void _read() => _choices = widget.service.findGoalChoices()..ignore();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      final height = (MediaQuery.sizeOf(context).height * .82).clamp(
        0.0,
        (box.maxHeight - keyboard).clamp(0.0, double.infinity),
      );
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SizedBox(
          height: height,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.spaceXl,
                    AppLayout.spaceMd,
                    AppLayout.spaceSm,
                    0,
                  ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.spaceXl,
                    AppLayout.spaceSm,
                    AppLayout.spaceXl,
                    AppLayout.spaceMd,
                  ),
                  child: TextField(
                    key: const Key('ownership-search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: '搜索目标或节点',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: AppLayout.iconMd,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空搜索',
                              onPressed: () => setState(_search.clear),
                              icon: const Icon(
                                Icons.close,
                                size: AppLayout.iconSm,
                              ),
                            ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<MissionGoalChoices>>(
                    future: _choices,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return ListView(
                          children: [
                            _independent(context),
                            const ListTile(title: Text('暂时无法读取目标，仍可选择独立任务')),
                            TextButton(
                              onPressed: () => setState(_read),
                              child: const Text('重新读取目标'),
                            ),
                          ],
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final tokens = _search.text
                          .trim()
                          .toLowerCase()
                          .split(RegExp(r'\s+'))
                          .where((token) => token.isNotEmpty)
                          .toList();
                      bool matches(String label) =>
                          tokens.every(label.toLowerCase().contains);
                      final showIndependent = tokens.isEmpty || matches('独立任务');
                      final options =
                          <
                            ({
                              MissionOwnership value,
                              String title,
                              String path,
                              bool goal,
                            })
                          >[];
                      for (final choice in snapshot.data!) {
                        if (matches(choice.goal.title)) {
                          options.add((
                            value: MissionOwnership(goalId: choice.goal.id),
                            title: choice.goal.title,
                            path: '只关联此目标',
                            goal: true,
                          ));
                        }
                        for (final node in choice.nodes) {
                          final value = MissionOwnership(
                            goalId: choice.goal.id,
                            goalNodeId: node.id,
                          );
                          final info = choice.resolve(value);
                          if (info.available && matches(info.label)) {
                            options.add((
                              value: value,
                              title: node.title,
                              path: info.label,
                              goal: false,
                            ));
                          }
                        }
                      }
                      return ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(
                          bottom: AppLayout.spaceMd,
                        ),
                        children: [
                          if (showIndependent) _independent(context),
                          if (tokens.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppLayout.spaceXl,
                                AppLayout.spaceMd,
                                AppLayout.spaceXl,
                                AppLayout.spaceXs,
                              ),
                              child: Text(
                                '找到 ${options.length + (showIndependent ? 1 : 0)} 项',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if (options.isEmpty &&
                              (tokens.isEmpty || !showIndependent))
                            Padding(
                              padding: const EdgeInsets.all(AppLayout.spaceXl),
                              child: Text(
                                tokens.isEmpty
                                    ? '暂无正在推进的目标，可以创建独立任务'
                                    : '没有匹配的目标或节点，试试其他关键词',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          for (final option in options)
                            ListTile(
                              key: Key(
                                option.goal
                                    ? 'ownership-goal-${option.value.goalId}'
                                    : 'ownership-node-${option.value.goalNodeId}',
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppLayout.spaceXl,
                                vertical: AppLayout.spaceXs,
                              ),
                              leading: Icon(
                                option.goal
                                    ? Icons.flag_outlined
                                    : Icons.subdirectory_arrow_right,
                                color: AppColors.primary,
                              ),
                              title: Text(option.title),
                              subtitle: Text(option.path),
                              trailing: option.value == widget.value
                                  ? const Icon(
                                      Icons.check,
                                      color: AppColors.primary,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context, option.value),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _independent(BuildContext context) => ListTile(
    key: const Key('ownership-independent'),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppLayout.spaceXl,
      vertical: AppLayout.spaceXs,
    ),
    leading: const Icon(Icons.task_alt, color: AppColors.primary),
    title: const Text('独立任务'),
    subtitle: const Text('不关联目标或节点'),
    trailing: widget.value.goalId == null
        ? const Icon(Icons.check, color: AppColors.primary)
        : null,
    onTap: () => Navigator.pop(context, const MissionOwnership()),
  );
}
