import 'package:flutter/material.dart';

import '../../application/create_mission.dart';
import '../../application/get_scheduled_missions.dart';
import '../missions/create_mission_page.dart';
import 'fixed_mission_section.dart';
import 'flexible_mission_section.dart';
import 'today_display.dart';
import 'today_header.dart';

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
  // 页面只保存四类信息：选了哪天、查到了什么、是否在等、有没有错误。
  late DateTime _selectedDate;
  TodayMissionGroups _missions = const TodayMissionGroups.empty();
  bool _isLoading = false;
  String? _errorText;

  // 快速切换日期时，请求可能乱序返回；只接收最后一次请求的结果。
  int _loadRequest = 0;

  // 入口一：Flutter 创建 State 后调用一次，默认选择上海日历的今天并读取。
  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(TodayDisplay.now());
    _loadMissions();
  }

  // 统一加载过程。调用者：initState、下拉刷新、切日期、错误重试、新建页返回。
  // 本方法只通过业务入口拿结果，不接触表对象、SQL 或数据库行类型。
  Future<void> _loadMissions() async {
    final request = ++_loadRequest;
    final date = TodayDisplay.dateKey(_selectedDate);
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // date 来自本页选择；await 等待 GetScheduledMissions → 仓储 → SQLite。
      final result = await widget.getMissions.execute(scheduledDate: date);
      if (!mounted || request != _loadRequest) return;
      // 一次查询只整理一次：分组、换算时区、准备显示文字，再交给三个区域。
      final missions = TodayDisplay.missions(result);
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
      currentDate: TodayDisplay.now(),
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
    _missions = const TodayMissionGroups.empty();
    await _loadMissions();
  }

  // 入口三：加号/空状态按钮打开表单。这里的 await 等待页面关闭，不是等待查库。
  // 关闭表单后再读取一次，所以新增任务可以出现在列表中。
  Future<void> _openCreate() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CreateMissionPage(
          createMission: widget.createMission,
          initialScheduledDate: TodayDisplay.dateKey(_selectedDate),
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
                TodayHeader(
                  dateLabel: TodayDisplay.dateLabel(_selectedDate),
                  isToday: DateUtils.isSameDay(
                    _selectedDate,
                    TodayDisplay.now(),
                  ),
                  onPickDate: _pickDate,
                  onCreate: _openCreate,
                  onReturnToday: () => _changeDate(TodayDisplay.now()),
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
          FixedMissionSection(items: _missions.fixed),
        if (_missions.flexible.isNotEmpty)
          FlexibleMissionSection(items: _missions.flexible),
        if (_missions.cancelled.isNotEmpty)
          ExpansionTile(
            key: const Key('cancelled-missions'),
            tilePadding: EdgeInsets.zero,
            title: Text('已取消（${_missions.cancelled.length}）'),
            children: [
              for (final item in _missions.cancelled)
                if (item.isFixed)
                  buildFixedMissionRow(context, item, showTimeline: false)
                else
                  buildFlexibleMissionRow(context, item),
            ],
          ),
      ],
    );
  }
}
