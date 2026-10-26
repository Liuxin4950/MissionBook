import '../../widgets/adaptive_columns.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/goals/goal_service.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal_node.dart';
import '../../widgets/app_confirm_dialog.dart';
import 'goal_node_editor.dart';
import '../../../application/missions/mission_service.dart';
import '../../../domain/entities/goal.dart';
import '../../../domain/entities/mission_detail.dart';
import 'goal_missions_section.dart';

/// 目标卡和详情共用的节点工作区，独立管理查询、展开与节点编辑交互。
class GoalOutlineSection extends StatefulWidget {
  const GoalOutlineSection({
    super.key,
    required this.service,
    required this.goalId,
    required this.goalTitle,
    this.embedded = false,
    this.missionService,
    this.goal,
  });

  final GoalService service;
  final String goalId;
  final String goalTitle;
  final bool embedded; // 放进列表白卡时为 true，不再叠加一层外卡片。
  final MissionService? missionService;
  final Goal? goal;

  @override
  State<GoalOutlineSection> createState() => GoalOutlineSectionState();
}

class GoalOutlineSectionState extends State<GoalOutlineSection>
    with WidgetsBindingObserver {
  late Future<List<GoalNode>> _nodes;
  List<GoalNode>? _lastNodes;
  StreamSubscription<void>? _subscription; // 保存 listen 返回的订阅，以便页面关闭时停止监听。
  StreamSubscription<void>? _missionSubscription;
  Future<List<MissionDetail>>? _missions;
  final _taskSections = <String, GlobalKey<GoalMissionsSectionState>>{};

  Future<bool> prepareToCollapse({
    String? subtreeId,
    bool includeRoot = true,
  }) => Future.value(true); // 执行草稿位于独立页面，折叠目录只影响这里的排版。

  final _collapsed = <String>{}; // 只保存界面折叠选择，不写入节点表。
  bool _showArchived = false;
  bool _busy = false;
  String? _operationError;
  Future<void> addRootNode() => _edit(); // 卡片目录工具栏复用此入口，不再重复画一行“目标路径”。

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  void _listen() {
    _nodes = _load();
    _subscription = widget.service.changes.listen((_) => _refresh());
    _missionSubscription = widget.missionService?.changes.listen(
      (_) => _refresh(),
    );
    _loadMissions();
  }

  void _loadMissions() {
    _missions = widget.missionService?.findForGoal(widget.goalId);
    _missions?.ignore();
  }

  Future<List<GoalNode>> _load() {
    final result = widget.service.findNodes(widget.goalId);
    result.ignore(); // 错误留给 FutureBuilder 展示，隐藏期间也不产生未处理异常。
    return result;
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _nodes = _load(); // 换成最新查询，但保留 _collapsed 中的展开选择。
      _loadMissions();
    });
  }

  @override
  void didUpdateWidget(covariant GoalOutlineSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.goalId != widget.goalId ||
        oldWidget.missionService != widget.missionService) {
      unawaited(_subscription?.cancel());
      unawaited(_missionSubscription?.cancel());
      _collapsed.clear();
      _lastNodes = null;
      _taskSections.clear();
      _listen();
    } else {
      _nodes = _load(); // 父页面返回列表并重新构建时也重读，补足响应丢失时可能缺少的成功通知。
      _loadMissions();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _edit({GoalNode? node, GoalNode? parent}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _operationError = null;
    });
    try {
      final saved = await GoalNodeEditor.show(
        context: context,
        service: widget.service,
        goalId: widget.goalId,
        contextTitle: parent?.title ?? widget.goalTitle,
        parentNodeId: parent?.id,
        node: node,
      );
      if (mounted && saved) {
        _showArchived = false; // 从已归档区添加节点后，切回当前路径，让新节点立即可见。
        if (parent != null) _collapsed.remove(parent.id);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh(); // 即使用户离开了结果未确认的编辑框，也重新查询是否已经保存。
      }
    }
  }

  /// 等待业务操作，出错后保留提示并重读数据库，不在页面猜测操作是否成功。
  Future<void> _run(
    Future<void> Function() operation, {
    GoalNode? archive,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _operationError = null;
    });
    try {
      if (!mounted) return;
      if (archive != null) {
        final confirmed = await AppConfirmDialog.show(
          context: context,
          title: '归档这个节点？',
          message: '“${archive.title}”及其全部子节点将一起归档，已有任务和执行历史会保留。可在已归档节点中恢复。',
          cancelText: '保留节点',
          confirmText: '归档',
        );
        if (!confirmed || !mounted) return;
        if (!await prepareToCollapse(subtreeId: archive.id) || !mounted) return;
      }
      await operation(); // 回调由节点菜单提供，实际保存仍交给 GoalService 和仓储。
    } catch (error) {
      if (mounted) {
        setState(() {
          _operationError = error is StateError
              ? '${error.message}。已重新读取路径，请确认后再操作。'
              : '暂未确认操作结果，已重新读取路径，请以最新位置为准。';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_missionSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.zero,
    decoration: BoxDecoration(
      color: widget.embedded ? AppColors.card : AppColors.background,
      borderRadius: BorderRadius.circular(24),
    ),
    child: FutureBuilder<List<GoalNode>>(
      key: ValueKey(widget.goalId),
      future: _nodes,
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        if (_lastNodes == null &&
            !snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError && _lastNodes == null) {
          return Column(
            children: [
              const Text('暂时无法读取目标路径，已有内容会保留'),
              TextButton(onPressed: _refresh, child: const Text('重试读取路径')),
            ],
          );
        }
        if (snapshot.hasData) _lastNodes = snapshot.data;
        final nodes = _lastNodes!;
        final byId = {
          for (final node in nodes) node.id: node,
        }; // 把编号作为 key，节点对象作为值，方便查找父节点。
        final active = nodes
            .where((node) => node.archivedAt == null)
            .toList(); // where 筛选未归档节点，toList 收集为列表。
        final archived = nodes
            .where((node) => node.archivedAt != null)
            .toList();
        final showingArchive = _showArchived && archived.isNotEmpty;
        final shown = showingArchive ? archived : active;
        final roots = shown
            .where(
              (node) =>
                  node.parentNodeId == null ||
                  (showingArchive &&
                      byId[node.parentNodeId]?.archivedAt == null),
            )
            .toList();
        final children = <String?, List<GoalNode>>{};
        for (final node in shown) {
          (children[node.parentNodeId] ??= []).add(
            node,
          ); // 这个父节点还没有孩子列表时先创建，再把当前节点加入。
        }
        final entries = _visibleEntries(roots, children);
        final sizes = _subtreeSizes(shown, byId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot.hasError)
              TextButton(
                onPressed: _refresh,
                child: const Text('路径刷新失败，保留当前工作区，点击重试'),
              ),
            if (!widget.embedded)
              Row(
                children: [
                  if (!widget.embedded)
                    const Icon(
                      Icons.account_tree_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: widget.embedded
                        ? const SizedBox.shrink()
                        : Text('目标路径', style: theme.textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    key: Key('node-add-root-${widget.goalId}'),
                    onPressed: _busy ? null : () => _edit(),
                    icon: const Icon(Icons.add, size: 18),
                    style: TextButton.styleFrom(
                      textStyle: theme.textTheme.labelMedium,
                    ),
                    label: Text(widget.embedded ? '添加节点' : '新增节点'),
                  ),
                ],
              ),
            if (_operationError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _operationError!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.route_outlined,
                      size: 32,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '把目标分成容易着手的几部分',
                      style: theme.textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '先添加一个节点，需要时再细分。',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            // 每个根节点保留其完整子树；宽屏并排呈现行动分支，窄屏自然堆叠。
            AnimatedSize(
              alignment: Alignment.topLeft,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AdaptiveColumns(
                maxColumns: widget.embedded ? 3 : 1,
                minColumnWidth: 320,
                children: [
                  for (final root in roots)
                    Column(
                      key: ValueKey(root.id),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in entries.where(
                          (entry) => _belongsToRoot(entry.node, root.id, byId),
                        ))
                          _nodeRow(
                            entry,
                            nodes,
                            byId,
                            children,
                            sizes,
                            entry.node.archivedAt != null,
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (widget.missionService != null && widget.goal != null)
              _missionsFor(null),
            if (archived.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('node-show-archived-${widget.goalId}'),
                  onPressed: _busy
                      ? null
                      : () => _switchArchive(!showingArchive),
                  icon: Icon(
                    showingArchive
                        ? Icons.arrow_back
                        : Icons.inventory_2_outlined,
                    size: 18,
                  ),
                  label: Text(
                    showingArchive ? '返回当前路径' : '已归档节点 · ${archived.length}',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: theme.textTheme.labelMedium,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  bool _belongsToRoot(
    GoalNode node,
    String rootId,
    Map<String, GoalNode> byId,
  ) {
    GoalNode? current = node;
    while (current != null) {
      if (current.id == rootId) return true;
      current = byId[current.parentNodeId];
    }
    return false;
  }

  Widget _nodeRow(
    _OutlineEntry entry,
    List<GoalNode> all,
    Map<String, GoalNode> byId,
    Map<String?, List<GoalNode>> children,
    Map<String, int> sizes,
    bool archived,
  ) {
    final node = entry.node;
    final hasChildren = (children[node.id] ?? []).isNotEmpty;
    final collapsed = _collapsed.contains(node.id);
    final siblings = all
        .where((item) => item.parentNodeId == node.parentNodeId)
        .toList();
    final visibleSiblings = siblings
        .where((item) => item.archivedAt == null)
        .toList();
    final position = visibleSiblings.indexWhere((item) => item.id == node.id);
    // 深层节点限制视觉缩进，给窄屏文字留空间；完整层级编号仍显示真实关系。
    final indent = (entry.depth > 3 ? 3 : entry.depth) * 12.0;
    final menu = PopupMenuButton<_NodeAction>(
      key: Key('node-menu-${node.id}'),
      tooltip: '节点操作：${node.title}',
      enabled: !_busy,
      icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
      itemBuilder: (_) => archived
          ? [
              PopupMenuItem(
                value: _NodeAction.restore,
                enabled:
                    node.parentNodeId == null ||
                    byId[node.parentNodeId]?.archivedAt == null,
                child: Text(
                  node.parentNodeId != null &&
                          byId[node.parentNodeId]?.archivedAt != null
                      ? '请先恢复父节点'
                      : '恢复节点及子节点',
                ),
              ),
            ]
          : [
              if (widget.missionService != null &&
                  widget.goal?.status == GoalStatus.active)
                PopupMenuItem(
                  key: Key('node-create-mission-menu-${node.id}'),
                  value: _NodeAction.createMission,
                  child: const Text('建任务'),
                ),
              const PopupMenuItem(value: _NodeAction.add, child: Text('添加子节点')),
              const PopupMenuItem(
                value: _NodeAction.edit,
                child: Text('编辑名称与说明'),
              ),
              PopupMenuItem(
                value: _NodeAction.up,
                enabled: position > 0,
                child: const Text('上移'),
              ),
              PopupMenuItem(
                value: _NodeAction.down,
                enabled: position >= 0 && position < visibleSiblings.length - 1,
                child: const Text('下移'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _NodeAction.archive,
                child: Text('归档节点及子节点'),
              ),
            ],
      onSelected: (action) {
        switch (action) {
          case _NodeAction.createMission:
            final section = _taskSections[node.id]?.currentState;
            if (section != null) unawaited(section.createMission());
          case _NodeAction.add:
            unawaited(_edit(parent: node));
          case _NodeAction.edit:
            unawaited(_edit(node: node, parent: byId[node.parentNodeId]));
          case _NodeAction.up:
            unawaited(
              _run(
                () => widget.service.moveNode(
                  node,
                  siblings: siblings,
                  upward: true,
                ),
              ),
            );
          case _NodeAction.down:
            unawaited(
              _run(
                () => widget.service.moveNode(
                  node,
                  siblings: siblings,
                  upward: false,
                ),
              ),
            );
          case _NodeAction.archive:
            unawaited(
              _run(() => widget.service.archiveNode(node.id), archive: node),
            );
          case _NodeAction.restore:
            unawaited(_run(() => widget.service.restoreNode(node.id)));
        }
      },
    );
    final treeToggle = hasChildren
        ? IconButton(
            key: Key('node-expand-${node.id}'),
            tooltip: '${collapsed ? '展开' : '收起'} ${node.title}',
            onPressed: () async {
              if (!collapsed &&
                  !await prepareToCollapse(
                    subtreeId: node.id,
                    includeRoot: false,
                  )) {
                return;
              }
              if (!mounted) return;
              setState(() {
                if (collapsed) {
                  _collapsed.remove(node.id);
                } else {
                  _collapsed.add(node.id);
                }
              });
            },
            icon: AnimatedRotation(
              turns: collapsed ? 0 : .25,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          )
        : null;
    final annotation = [
      if (hasChildren) '含本项 ${sizes[node.id]} 项',
      if (entry.depth > 3) '第 ${entry.depth + 1} 层',
      if (archived && node.parentNodeId != null)
        '原位置 · ${byId[node.parentNodeId]?.title ?? widget.goalTitle}',
    ].join(' · ');
    return Padding(
      key: Key('node-row-${node.id}'),
      padding: EdgeInsets.only(left: indent, top: 4, bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: entry.depth == 0
              ? null
              : const Border(left: BorderSide(color: AppColors.hairline)),
        ),
        child: Padding(
          padding: EdgeInsets.only(left: entry.depth == 0 ? 0 : 8),
          // 任务区放在整行下方，不再塞进标题旁的 Expanded 列，展开后能使用整块可用宽度。
          child: widget.missionService != null && widget.goal != null
              ? _missionsFor(
                  node,
                  leading: treeToggle,
                  trailing: menu,
                  annotation: annotation,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        treeToggle ??
                            const SizedBox(
                              width: 40,
                              height: 48,
                              child: Icon(
                                Icons.radio_button_unchecked,
                                size: 18,
                                color: AppColors.outline,
                              ),
                            ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              node.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        menu,
                      ],
                    ),
                    if (annotation.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Text(
                          annotation,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _missionsFor(
    GoalNode? node, {
    Widget? leading,
    Widget? trailing,
    String? annotation,
  }) => GoalMissionsSection(
    leading: leading,
    trailing: trailing,
    annotation: annotation,
    key: _taskSections.putIfAbsent(
      node?.id ?? 'goal-only',
      () => GlobalKey<GoalMissionsSectionState>(),
    ),
    goal: widget.goal!,
    node: node,
    service: widget.missionService!,
    missions: _missions!,
    onRefresh: _refresh,
  );

  Future<void> _switchArchive(bool show) async {
    if (!await prepareToCollapse() || !mounted) return;
    setState(() => _showArchived = show);
  }

  /// 按父子关系生成一维展示列表，折叠只影响后代是否进入列表。
  List<_OutlineEntry> _visibleEntries(
    List<GoalNode> roots,
    Map<String?, List<GoalNode>> children,
  ) {
    final pending = <_OutlineEntry>[];
    for (var index = roots.length - 1; index >= 0; index--) {
      pending.add(_OutlineEntry(roots[index], 0, '${index + 1}'));
    }
    final result = <_OutlineEntry>[];
    while (pending.isNotEmpty) {
      final entry = pending.removeLast();
      result.add(entry);
      if (_collapsed.contains(entry.node.id)) continue;
      final group = children[entry.node.id] ?? const <GoalNode>[];
      for (var index = group.length - 1; index >= 0; index--) {
        pending.add(
          _OutlineEntry(
            group[index],
            entry.depth + 1,
            '${entry.path}.${index + 1}',
          ),
        );
      }
    }
    return result; // 例如父节点 1 的第二个子节点显示 1.2；这个编号不写回 orderIndex。
  }

  Map<String, int> _subtreeSizes(
    List<GoalNode> shown,
    Map<String, GoalNode> byId,
  ) {
    final shownIds = shown.map((node) => node.id).toSet();
    final sizes = <String, int>{};
    for (final node in shown) {
      String? id = node.id;
      while (id != null && shownIds.contains(id)) {
        sizes[id] = (sizes[id] ?? 0) + 1;
        id = byId[id]?.parentNodeId;
      }
    }
    return sizes;
  }
}

enum _NodeAction { createMission, add, edit, up, down, archive, restore }

/// 页面临时使用的节点位置：保存节点、显示深度及显示编号，不进入数据库。
class _OutlineEntry {
  const _OutlineEntry(this.node, this.depth, this.path);
  final GoalNode node;
  final int depth;
  final String path;
}
