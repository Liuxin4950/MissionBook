import 'package:flutter/material.dart';

import '../../application/create_mission.dart';
import '../../application/get_scheduled_missions.dart';
import '../missions/create_mission_page.dart';
import 'today_display.dart' as display;

// 今天页 UI 集中在本文件：页面状态与交互 → 页头 → 两个任务区域 → 任务行与时间轴。
// 日期、分组和显示文字交给 today_display.dart，本文件负责布局及界面交互。
// App 创建两个业务入口，AppShell 将同一份引用传到这里。
// createMission 给表单保存使用；getMissions 给本页读取列表使用。
/// 展示所选计划日期的任务，并处理刷新、日期选择和打开创建表单。
class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.createMission,
    required this.getMissions,
  });

  final CreateMission createMission;
  final GetScheduledMissions getMissions;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  // 页面只保存四类信息：选了哪天、查到了什么、是否在等、有没有错误。
  late DateTime _selectedDate;
  display.TodayMissionGroups _missions =
      const display.TodayMissionGroups.empty();
  bool _isLoading = false;
  String? _errorText;

  // 快速切换日期时，请求可能乱序返回；只接收最后一次请求的结果。
  int _loadRequest = 0;

  // 入口一：Flutter 创建 State 后调用一次，默认选择上海日历的今天并读取。
  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(display.todayInScheduleTimeZone());
    _loadMissions();
  }

  // 统一加载过程。调用者：initState、下拉刷新、切日期、错误重试、新建页返回。
  // 本方法只通过业务入口拿结果，不接触表对象、SQL 或数据库行类型。
  Future<void> _loadMissions() async {
    final request = ++_loadRequest;
    final date = display.scheduleDateKey(_selectedDate);
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // date 来自本页选择；await 等待 GetScheduledMissions → 仓储 → SQLite。
      final result = await widget.getMissions.execute(scheduledDate: date);
      if (!mounted || request != _loadRequest) return;
      // 一次查询只整理一次：分组、换算时区、准备显示文字，再交给三个区域。
      final missions = display.groupMissionsForDisplay(result);
      setState(() {
        _missions = missions;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || request != _loadRequest) return;
      debugPrint('读取任务失败：$error\n$stackTrace');
      setState(() {
        _errorText = '任务加载失败，请重试';
        _isLoading = false;
      });
    }
  }

  // 入口二：日期按钮打开选择器。用户选择日期后交给 _changeDate。
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      currentDate: display.todayInScheduleTimeZone(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: '选择计划日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted || date == null) return;
    await _changeDate(date);
  }

  // 日期选择器和“回到今天”共用：先换日期、清掉旧列表，再走同一次加载过程。
  Future<void> _changeDate(DateTime date) async {
    _selectedDate = DateUtils.dateOnly(date);
    _missions = const display.TodayMissionGroups.empty();
    await _loadMissions();
  }

  // 入口三：加号/空状态按钮打开表单。这里的 await 等待页面关闭，不是等待查库。
  // 关闭表单后再读取一次，所以新增任务可以出现在列表中。
  Future<void> _openCreate() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CreateMissionPage(
          createMission: widget.createMission,
          initialScheduledDate: display.scheduleDateKey(_selectedDate),
        ),
      ),
    );
    if (!mounted) return;
    await _loadMissions();
  }

  // build 只描述布局：可下拉的列表 = 页头 + 日期返回入口 + 当前列表内容。
  // build 不查询数据库；它只读取上面的状态，由 _buildContent 决定显示哪一种状态。
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: RefreshIndicator(
            onRefresh: _loadMissions,
            child: ListView(
              key: const Key('today-list'),
              // 即使列表为空或很短，也允许向下拖动，触发上面的 onRefresh。
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 360 ? 16 : 24,
                24,
                MediaQuery.sizeOf(context).width < 360 ? 16 : 24,
                24,
              ),
              children: [
                // 页面顶部：日期文字已经准备好，区域内部只绑定回调、排版。
                _TodayHeader(
                  dateLabel: display.scheduleDateLabel(_selectedDate),
                  isToday: DateUtils.isSameDay(
                    _selectedDate,
                    display.todayInScheduleTimeZone(),
                  ),
                  onPickDate: _pickDate,
                  onCreate: _openCreate,
                  onReturnToday: () =>
                      _changeDate(display.todayInScheduleTimeZone()),
                ),
                const SizedBox(height: 24),
                // 构建元素
                _buildContent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // build 调用此方法，按状态选择加载/失败/空/列表；这里不发起任何异步工作。
  Widget _buildContent(BuildContext context) {
    if (_isLoading && _missions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorText != null) {
      return Column(
        children: [
          Text(_errorText!),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _loadMissions, child: const Text('重新加载')),
        ],
      );
    }
    if (_missions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text('这一天还没有任务'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('创建任务'),
            ),
          ],
        ),
      );
    }
    // 正常内容沿页面视觉顺序排列。分组由加载过程完成，这里只交付对应列表。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_missions.fixed.isEmpty && _missions.flexible.isEmpty)
          const Text('这一天没有未取消的任务'),
        if (_missions.fixed.isNotEmpty)
          _FixedMissionSection(items: _missions.fixed),
        if (_missions.flexible.isNotEmpty)
          _FlexibleMissionSection(items: _missions.flexible),
        if (_missions.cancelled.isNotEmpty)
          ExpansionTile(
            key: const Key('cancelled-missions'),
            tilePadding: EdgeInsets.zero,
            title: Text('已取消（${_missions.cancelled.length}）'),
            children: [
              for (final item in _missions.cancelled)
                if (item.isFixed)
                  _FixedMissionRow(item: item, showTimeline: false)
                else
                  _FlexibleMissionRow(item: item),
            ],
          ),
      ],
    );
  }
}

// 页面顶部。TodayPage 提供已准备好的日期文字和回调；这里只负责排版。
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.dateLabel,
    required this.isToday,
    required this.onPickDate,
    required this.onCreate,
    required this.onReturnToday,
  });

  final String dateLabel;
  final bool isToday;
  final VoidCallback onPickDate;
  final VoidCallback onCreate;
  final VoidCallback onReturnToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今天', style: theme.textTheme.headlineSmall),
                  TextButton.icon(
                    key: const Key('today-date-picker'),
                    onPressed: onPickDate,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      alignment: Alignment.centerLeft,
                      textStyle: theme.textTheme.bodyMedium,
                    ),
                    label: Text(dateLabel),
                    icon: const Icon(Icons.expand_more, size: 20),
                    iconAlignment: IconAlignment.end,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton.filled(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                tooltip: '创建任务',
                style: IconButton.styleFrom(
                  fixedSize: const Size(48, 48),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
        if (!isToday)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onReturnToday,
              child: const Text('回到今天'),
            ),
          ),
      ],
    );
  }
}

// 固定任务区域。列表已经分组、排好序；这里只安排时间、连线和任务文字。
class _FixedMissionSection extends StatelessWidget {
  const _FixedMissionSection({required this.items});

  final List<display.TodayMissionItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '计划日程',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              // 全部任务的范围尚未确定：保留禁用入口，暂不绑定跳转。
              TextButton.icon(
                key: const Key('today-all-missions'),
                onPressed: null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                label: const Text('全部任务'),
                icon: const Icon(Icons.north_east, size: 16),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < items.length; index++)
            _FixedMissionRow(
              item: items[index],
              connectPrevious: index > 0,
              connectNext: index < items.length - 1,
            ),
        ],
      ),
    );
  }
}

// 取消折叠区也使用固定行，但关闭时间轴；不再混入自选任务的另一套布局。
class _FixedMissionRow extends StatelessWidget {
  const _FixedMissionRow({
    required this.item,
    this.showTimeline = true,
    this.connectPrevious = false,
    this.connectNext = false,
  });

  final display.TodayMissionItem item;
  final bool showTimeline;
  final bool connectPrevious;
  final bool connectNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 这些计算属于布局：让节点对齐标题首行，随主题字号及系统文字缩放移动。
    final titleStyle = theme.textTheme.titleMedium!;
    final timeStyle = theme.textTheme.bodyMedium!;
    final scaler = MediaQuery.textScalerOf(context);
    final titleLineHeight =
        scaler.scale(titleStyle.fontSize!) * titleStyle.height!;
    final timeLineHeight =
        scaler.scale(timeStyle.fontSize!) * timeStyle.height!;
    final timeTop = (titleLineHeight - timeLineHeight) / 2;
    return Stack(
      key: ValueKey('mission-${item.id}'),
      children: [
        if (showTimeline)
          Positioned(
            left: 56,
            width: 16,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: CustomPaint(
                key: ValueKey('timeline-rail-${item.id}'),
                painter: _TimelinePainter(
                  connectPrevious: connectPrevious,
                  connectNext: connectNext,
                  nodeY: titleLineHeight / 2,
                  lineColor: theme.colorScheme.outlineVariant,
                  nodeColor: theme.colorScheme.onSurfaceVariant,
                  background: theme.scaffoldBackgroundColor,
                ),
              ),
            ),
          ),
        // 文字撑开 Stack，竖线包含行间距；长标题换行也不会截断相邻行连线。
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: EdgeInsets.only(top: timeTop > 0 ? timeTop : 0),
                  child: Text(
                    item.startTime,
                    style: timeStyle.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 36),
              Expanded(child: _MissionDetails(item: item)),
            ],
          ),
        ),
      ],
    );
  }
}

// 时间轴是区域内部的绘制细节，不表示任务已开始或已完成。
class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.connectPrevious,
    required this.connectNext,
    required this.nodeY,
    required this.lineColor,
    required this.nodeColor,
    required this.background,
  });

  final bool connectPrevious;
  final bool connectNext;
  final double nodeY;
  final Color lineColor;
  final Color nodeColor;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, nodeY);
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, connectPrevious ? 0 : nodeY),
      Offset(center.dx, connectNext ? size.height : nodeY),
      line,
    );
    canvas.drawCircle(center, 4.5, Paint()..color = background);
    canvas.drawCircle(
      center,
      4.5,
      Paint()
        ..color = nodeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      connectPrevious != oldDelegate.connectPrevious ||
      connectNext != oldDelegate.connectNext ||
      nodeY != oldDelegate.nodeY ||
      lineColor != oldDelegate.lineColor ||
      nodeColor != oldDelegate.nodeColor ||
      background != oldDelegate.background;
}

// 自选时间区域。只接收自选任务列表，不判断时间策略或重新分组。
class _FlexibleMissionSection extends StatefulWidget {
  const _FlexibleMissionSection({required this.items});

  final List<display.TodayMissionItem> items;

  @override
  State<_FlexibleMissionSection> createState() =>
      _FlexibleMissionSectionState();
}

class _FlexibleMissionSectionState extends State<_FlexibleMissionSection> {
  static const _previewCount = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 折叠只影响排版，完整数据仍由 widget.items 提供，不再查询或转换。
    final hasMore = widget.items.length > _previewCount;
    final visibleItems = _expanded
        ? widget.items
        : widget.items.take(_previewCount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '自选时间',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final item in visibleItems) _FlexibleMissionRow(item: item),
          if (hasMore)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('flexible-missions-toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? '收起' : '展开全部（${widget.items.length}）'),
              ),
            ),
        ],
      ),
    );
  }
}

// 同一套行布局也用于取消折叠区，避免复制图标和文字排版。
class _FlexibleMissionRow extends StatelessWidget {
  const _FlexibleMissionRow({required this.item});

  final display.TodayMissionItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey('mission-${item.id}'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 24,
                  color: colors.primary,
                ),
              ),
            ),
          ),
          Expanded(child: _MissionDetails(item: item)),
        ],
      ),
    );
  }
}

// 固定、自选和取消行共用的文字排版。文字已经由显示转换函数准备好。
// 这是布局复用，不做类型转换、分组或查询。
class _MissionDetails extends StatelessWidget {
  const _MissionDetails({required this.item});

  final display.TodayMissionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: theme.textTheme.titleMedium?.copyWith(
            decoration: item.isCancelled ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(item.durationLabel, style: theme.textTheme.bodyMedium),
        if (item.timeZoneLabel != null)
          Text(item.timeZoneLabel!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
