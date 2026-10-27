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

const _nodeRowPadding = 4.0;

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
  Future<Map<String?, List<MissionDetail>>>? _missionsByNode;
  final _directMissions = <String?, Future<List<MissionDetail>>>{};
  final _taskSections = <String, GlobalKey<GoalMissionsSectionState>>{};

  Future<bool> prepareToCollapse({
    String? subtreeId,
    bool includeRoot = true,
  }) => Future.value(true); // 执行草稿位于独立页面，折叠目录只影响这里的排版。

  final _collapsed = <String>{}; // 只保存界面折叠选择，不写入节点表。
  final _treeScroll = ScrollController();
  double _horizontalDrag = 0;
  String? _swipedNodeId; // 一次只展开一个节点的归档快捷操作。
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
    _directMissions.clear();
    _missionsByNode = widget.missionService?.findForGoal(widget.goalId).then((
      records,
    ) {
      final groups = <String?, List<MissionDetail>>{};
      for (final detail in records) {
        (groups[detail.mission.goalNodeId] ??= []).add(detail);
      }
      return groups;
    });
    _missionsByNode?.ignore();
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
    _treeScroll.dispose();
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
                    Text(
                      '先添加一个节点，需要时再细分。',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            // 所有分支按树的顺序纵向排列，避免并排时误认父子关系。
            LayoutBuilder(
              builder: (context, box) {
                final depth = entries.fold<int>(
                  0,
                  (max, entry) => entry.depth > max ? entry.depth : max,
                );
                final step = depth == 0
                    ? 24.0
                    : ((box.maxWidth - 180) / depth).clamp(12.0, 24.0);
                final width = (depth * step + 180).clamp(
                  box.maxWidth,
                  double.infinity,
                );
                return Scrollbar(
                  controller: _treeScroll,
                  thumbVisibility: width > box.maxWidth,
                  child: SingleChildScrollView(
                    controller: _treeScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: AnimatedSize(
                        alignment: Alignment.topLeft,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final entry in entries)
                              _nodeRow(
                                entry,
                                nodes,
                                byId,
                                children,
                                entry.node.archivedAt != null,
                                step,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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

  Widget _nodeRow(
    _OutlineEntry entry,
    List<GoalNode> all,
    Map<String, GoalNode> byId,
    Map<String?, List<GoalNode>> children,
    bool archived,
    double step,
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
    // 每层缩进与连接线使用同一尺寸；深树可横向浏览，不压平真实层级。
    final indent = entry.depth * step;
    Widget menuLabel(
      IconData icon,
      String label, {
      bool destructive = false,
      bool enabled = true,
    }) => Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: !enabled
              ? AppColors.onDisabled
              : destructive
              ? AppColors.error
              : AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: !enabled
                  ? AppColors.onDisabled
                  : destructive
                  ? AppColors.error
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
    final menu = PopupMenuButton<_NodeAction>(
      color: AppColors.card,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  child: menuLabel(Icons.add_task_outlined, '建任务'),
                ),
              PopupMenuItem(
                value: _NodeAction.add,
                child: menuLabel(Icons.subdirectory_arrow_right, '添加子节点'),
              ),
              PopupMenuItem(
                value: _NodeAction.edit,
                child: menuLabel(Icons.edit_outlined, '编辑名称与说明'),
              ),
              PopupMenuItem(
                value: _NodeAction.up,
                enabled: position > 0,
                child: menuLabel(
                  Icons.arrow_upward,
                  '上移',
                  enabled: position > 0,
                ),
              ),
              PopupMenuItem(
                value: _NodeAction.down,
                enabled: position >= 0 && position < visibleSiblings.length - 1,
                child: menuLabel(
                  Icons.arrow_downward,
                  '下移',
                  enabled:
                      position >= 0 && position < visibleSiblings.length - 1,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _NodeAction.archive,
                child: menuLabel(
                  Icons.archive_outlined,
                  '归档节点及子节点',
                  destructive: true,
                ),
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
    Future<void> toggleChildren() async {
      if (!collapsed &&
          !await prepareToCollapse(subtreeId: node.id, includeRoot: false)) {
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
    }

    final treeToggle = hasChildren
        ? IconButton(
            key: Key('node-expand-${node.id}'),
            tooltip: '${collapsed ? '展开' : '收起'} ${node.title}',
            onPressed: toggleChildren,
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
      if (archived && node.parentNodeId != null)
        '原位置 · ${byId[node.parentNodeId]?.title ?? widget.goalTitle}',
    ].join(' · ');
    return Padding(
      key: Key('node-row-${node.id}'),
      padding: EdgeInsets.only(top: entry.depth == 0 ? 8 : 0),
      child: CustomPaint(
        foregroundPainter: _TreeGuidePainter(
          entry.guides,
          hasChildren && !collapsed,
          step,
        ),
        child: Padding(
          padding: EdgeInsets.only(left: indent),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: archived || _busy
                ? null
                : () => _edit(node: node, parent: byId[node.parentNodeId]),
            onHorizontalDragStart: archived || _busy
                ? null
                : (_) => _horizontalDrag = 0,
            onHorizontalDragUpdate: archived || _busy
                ? null
                : (details) => _horizontalDrag += details.delta.dx,
            onHorizontalDragEnd: archived || _busy
                ? null
                : (details) {
                    if (_horizontalDrag < -40) {
                      setState(() => _swipedNodeId = node.id);
                    } else if (_horizontalDrag > 40 &&
                        _swipedNodeId == node.id) {
                      setState(() => _swipedNodeId = null);
                    }
                  },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: entry.depth == 0
                          ? AppColors.surfaceMuted.withValues(alpha: .65)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: _nodeRowPadding,
                      ),
                      // 任务区放在整行下方，不再塞进标题旁的 Expanded 列，展开后能使用整块可用宽度。
                      child:
                          widget.missionService != null && widget.goal != null
                          ? _missionsFor(
                              node,
                              leading: treeToggle,
                              trailing: menu,
                              annotation: annotation,
                              onNodeTap: hasChildren ? toggleChildren : null,
                            )
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: hasChildren ? toggleChildren : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox.square(
                                        dimension:
                                            GoalMissionsSection.markerExtent,
                                        child:
                                            treeToggle ??
                                            const Icon(
                                              Icons.radio_button_unchecked,
                                              size: 18,
                                              color: AppColors.outline,
                                            ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Text(
                                            node.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ),
                                      menu,
                                    ],
                                  ),
                                  if (annotation.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 48),
                                      child: Text(
                                        annotation,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                if (_swipedNodeId == node.id && !archived)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton.icon(
                      key: Key('node-swipe-archive-${node.id}'),
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() => _swipedNodeId = null);
                              unawaited(
                                _run(
                                  () => widget.service.archiveNode(node.id),
                                  archive: node,
                                ),
                              );
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        backgroundColor: AppColors.errorSoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.archive_outlined, size: 18),
                      label: const Text('归档'),
                    ),
                  ),
              ],
            ),
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
    VoidCallback? onNodeTap,
  }) => GoalMissionsSection(
    onNodeTap: onNodeTap,
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
    missions: _directMissions.putIfAbsent(
      node?.id,
      () => _missionsByNode!.then((groups) => groups[node?.id] ?? []),
    ),
    directOnly: true,
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
      pending.add(_OutlineEntry(roots[index], const []));
    }
    final result = <_OutlineEntry>[];
    while (pending.isNotEmpty) {
      final entry = pending.removeLast();
      result.add(entry);
      if (_collapsed.contains(entry.node.id)) continue;
      final group = children[entry.node.id] ?? const <GoalNode>[];
      for (var index = group.length - 1; index >= 0; index--) {
        pending.add(
          _OutlineEntry(group[index], [
            ...entry.guides,
            index < group.length - 1,
          ]),
        );
      }
    }
    return result;
  }
}

enum _NodeAction { createMission, add, edit, up, down, archive, restore }

/// 页面临时位置；每条引导线记录该分支下方是否仍有同级节点。
class _OutlineEntry {
  const _OutlineEntry(this.node, this.guides);
  final GoalNode node;
  final List<bool> guides;
  int get depth => guides.length;
}

class _TreeGuidePainter extends CustomPainter {
  const _TreeGuidePainter(this.guides, this.expanded, this.step);
  final List<bool> guides;
  final bool expanded;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final markerCenterX = GoalMissionsSection.markerExtent / 2;
    final markerCenterY =
        _nodeRowPadding + GoalMissionsSection.markerExtent / 2;
    final paint = Paint()
      ..color = AppColors.outline.withValues(alpha: .55)
      ..strokeWidth = 1;
    for (var level = 0; level < guides.length; level++) {
      final x = markerCenterX + level * step;
      final current = level == guides.length - 1;
      if (current || guides[level]) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, current && !guides[level] ? markerCenterY : size.height),
          paint,
        );
      }
      if (current) {
        canvas.drawLine(
          Offset(x, markerCenterY),
          Offset(x + step - 10, markerCenterY),
          paint,
        );
      }
    }
    if (expanded) {
      final x = markerCenterX + guides.length * step;
      canvas.drawLine(
        Offset(x, markerCenterY + 10),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TreeGuidePainter oldDelegate) => true;
}
