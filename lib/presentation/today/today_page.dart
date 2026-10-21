import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../application/create_mission.dart';
import '../../application/get_scheduled_missions.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../missions/create_mission_page.dart';

// App 创建两个业务入口，AppShell 将同一份引用传到这里。
// createMission 给表单保存使用；getMissions 给本页读取列表使用。
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
  static const _timeZone = 'Asia/Shanghai';
  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  // 页面只保存四类信息：选了哪天、查到了什么、是否在等、有没有错误。
  late DateTime _selectedDate;
  List<ScheduledMission> _items = [];
  bool _isLoading = false;
  String? _errorText;

  // 快速切换日期时，请求可能乱序返回；只接收最后一次请求的结果。
  int _loadRequest = 0;

  tz.TZDateTime _now() => tz.TZDateTime.now(tz.getLocation(_timeZone));

  String _dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // 入口一：Flutter 创建 State 后调用一次，默认选择上海日历的今天并读取。
  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(_now());
    _loadMissions();
  }

  // 统一加载过程。调用者：initState、下拉刷新、切日期、错误重试、新建页返回。
  // 本方法只通过业务入口拿结果，不接触表对象、SQL 或数据库行类型。
  Future<void> _loadMissions() async {
    final request = ++_loadRequest;
    final date = _dateText(_selectedDate);
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // date 来自本页选择；await 等待 GetScheduledMissions → 仓储 → SQLite。
      final result = await widget.getMissions.execute(scheduledDate: date);
      if (!mounted || request != _loadRequest) return;
      // 结果已是业务列表；保存它，setState 通知 Flutter 重新绘制。
      setState(() {
        _items = result;
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
      currentDate: _now(),
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
    _items = [];
    await _loadMissions();
  }

  // 入口三：加号/空状态按钮打开表单。这里的 await 等待页面关闭，不是等待查库。
  // 关闭表单后再读取一次，所以新增任务可以出现在列表中。
  Future<void> _openCreate() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CreateMissionPage(
          createMission: widget.createMission,
          initialScheduledDate: _dateText(_selectedDate),
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
                _buildHeader(context),
                if (!DateUtils.isSameDay(_selectedDate, _now()))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _changeDate(_now()),
                      child: const Text('回到今天'),
                    ),
                  ),
                const SizedBox(height: 24),
                _buildContent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // build 调用此方法取得页头。按钮只绑定回调，点击后才执行选择日期/新建。
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel =
        '${_selectedDate.month}月${_selectedDate.day}日 · '
        '${_weekdays[_selectedDate.weekday - 1]}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今天',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  height: 36 / 28,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextButton.icon(
                key: const Key('today-date-picker'),
                onPressed: _pickDate,
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
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
            tooltip: '创建任务',
            style: IconButton.styleFrom(
              fixedSize: const Size(48, 48),
              shape: const CircleBorder(),
            ),
          ),
        ),
      ],
    );
  }

  // build 调用此方法，按状态选择加载/失败/空/列表；这里不发起任何异步工作。
  Widget _buildContent(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
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
    if (_items.isEmpty) {
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
    // 下面三个小组件只负责展示这一份结果，不查询数据库、不保存独立任务列表。
    return _DayMissions(items: _items);
  }
}

class _DayMissions extends StatelessWidget {
  const _DayMissions({required this.items});
  final List<ScheduledMission> items;

  @override
  Widget build(BuildContext context) {
    // _buildContent 把查到的列表交到这里。按展示区域分成三份，保留仓储排序。
    // 这些是本次绘制的局部列表，不是新的数据库查询，也不保存独立页面状态。
    final fixed = <ScheduledMission>[];
    final flexible = <ScheduledMission>[];
    final cancelled = <ScheduledMission>[];
    for (final item in items) {
      if (item.mission.cancelledAt != null) {
        cancelled.add(item);
      } else if (item.schedule.timePolicy == TimePolicy.fixed) {
        fixed.add(item);
      } else {
        flexible.add(item);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fixed.isEmpty && flexible.isEmpty) const Text('这一天没有未取消的任务'),
        if (fixed.isNotEmpty) _MissionSection(title: '计划日程', items: fixed),
        if (flexible.isNotEmpty)
          _MissionSection(title: '自选时间', items: flexible),
        if (cancelled.isNotEmpty)
          ExpansionTile(
            key: const Key('cancelled-missions'),
            tilePadding: EdgeInsets.zero,
            title: Text('已取消（${cancelled.length}）'),
            children: [for (final item in cancelled) _MissionTile(item: item)],
          ),
      ],
    );
  }
}

// 只负责一个分区的排版。固定分区按相邻行传入连线关系，自选分区不画时间轴。
class _MissionSection extends StatelessWidget {
  const _MissionSection({required this.title, required this.items});
  final String title;
  final List<ScheduledMission> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeline =
        items.isNotEmpty && items.first.schedule.timePolicy == TimePolicy.fixed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: timeline
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < items.length; index++)
            _MissionTile(
              item: items[index],
              showTimeline: timeline,
              connectPrevious: index > 0,
              connectNext: index < items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.item,
    this.showTimeline = false,
    this.connectPrevious = false,
    this.connectNext = false,
  });
  final ScheduledMission item;
  final bool showTimeline;
  final bool connectPrevious;
  final bool connectNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = item.schedule;
    final cancelled = item.mission.cancelledAt != null;
    final fixed = schedule.timePolicy == TimePolicy.fixed;
    // 只把 UTC 时刻转换为排期时区的显示文字，不查询或修改数据。
    var time = '';
    final startAt = schedule.fixedStartAt;
    if (fixed && startAt != null) {
      final localStart = tz.TZDateTime.from(
        startAt,
        tz.getLocation(schedule.timeZone),
      );
      final hour = localStart.hour.toString().padLeft(2, '0');
      final minute = localStart.minute.toString().padLeft(2, '0');
      time = '$hour:$minute';
    }
    // 节点对齐标题第一行的中心；系统放大文字时一并移动。
    final textScaler = MediaQuery.textScalerOf(context);
    final titleLineHeight = textScaler.scale(18) * 24 / 18;
    final timeLineHeight = textScaler.scale(14) * 20 / 14;
    final timeTop = (titleLineHeight - timeLineHeight) / 2;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.mission.title,
          style: theme.textTheme.titleMedium?.copyWith(
            decoration: cancelled ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${cancelled ? '已取消 · ' : ''}计划 ${schedule.plannedDurationMinutes} 分钟',
          style: theme.textTheme.bodyMedium,
        ),
        if (schedule.timeZone != 'Asia/Shanghai')
          Text(schedule.timeZone, style: theme.textTheme.bodySmall),
      ],
    );

    // Stack 的高度由真实文字内容决定。竖线填满整行（含行间距），
    // 下一行从同一 x 位置接上；长标题不会把线截断，也不采用等比时间网格。
    return Stack(
      key: ValueKey('mission-${item.mission.id}'),
      children: [
        if (fixed && showTimeline)
          Positioned(
            left: 56,
            width: 16,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: CustomPaint(
                key: ValueKey('timeline-rail-${item.mission.id}'),
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
        Padding(
          padding: EdgeInsets.only(bottom: fixed ? 8 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fixed) ...[
                SizedBox(
                  width: 48,
                  child: Padding(
                    padding: EdgeInsets.only(top: timeTop > 0 ? timeTop : 0),
                    child: Text(
                      time,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 36),
              ] else
                SizedBox(
                  width: 64,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        size: 24,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              Expanded(child: details),
            ],
          ),
        ),
      ],
    );
  }
}

// 纯装饰绘制：节点只表达排序，不表示任务已经开始或完成。
// 首行不向上画尾线，末行不向下画尾线，中间行与上下相邻行连续。
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
    // 暖白填充盖住穿过节点的线，再描空心边，保证未开始节点仍为空心。
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
