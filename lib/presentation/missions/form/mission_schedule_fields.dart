import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/entities/mission_schedule_revision.dart';

/// 日期、时长和时间安排；只管理日历展开，排期草稿仍由页面保存。
class MissionScheduleFields extends StatefulWidget {
  const MissionScheduleFields({
    super.key,
    required this.selectedDate, // 页面当前选择的日历日期。
    required this.dateText, // 日期的 YYYY-MM-DD 表达，供读屏使用。
    required this.timePolicy, // 当前选择自选或固定时间。
    required this.timeZone, // 当前排期时区，用于说明。
    required this.durationController, // 页面持有的时长输入。
    required this.hourController, // 页面持有的小时输入。
    required this.minuteController, // 页面持有的分钟输入。
    required this.enabled, // 页面保存或关闭期间禁用输入。
    required this.onDateChanged, // 把选中的日期交回页面。
    required this.onTimePolicyChanged, // 把时间策略交回页面。
  });

  final DateTime selectedDate;
  final String dateText;
  final TimePolicy timePolicy;
  final String timeZone;
  final TextEditingController durationController;
  final TextEditingController hourController;
  final TextEditingController minuteController;
  final bool enabled;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimePolicy> onTimePolicyChanged;

  @override
  State<MissionScheduleFields> createState() => _MissionScheduleFieldsState();
}

class _MissionScheduleFieldsState extends State<MissionScheduleFields> {
  bool _calendarExpanded = false; // 只影响本区域显示，不参与保存和丢弃判断。

  Widget _dateField() {
    final colors = Theme.of(context).colorScheme;
    // Semantics 将外置标签、日期值与按钮动作合成一个节点，避免图标重复朗读。
    return MissionInputLabel(
      label: '计划日期',
      fieldSemantics: false,
      child: Semantics(
        label: '计划日期',
        value: widget.dateText,
        button: true,
        expanded: _calendarExpanded,
        enabled: widget.enabled,
        child: Material(
          color: colors.primaryContainer.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('mission-date'),
            onTap: widget.enabled
                ? () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _calendarExpanded = !_calendarExpanded;
                    });
                  }
                : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: missionInputHeight(context),
              ),
              child: ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(18) / 18;
                    // 大字体优先给完整日期留空间，必要时省去装饰性日历图标。
                    final showCalendarIcon =
                        constraints.maxWidth >= 240 * scale;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          if (showCalendarIcon) ...[
                            Icon(
                              Icons.calendar_today_outlined,
                              color: colors.onSurface,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              '${widget.selectedDate.year}年${widget.selectedDate.month}月${widget.selectedDate.day}日',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          Icon(
                            _calendarExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _durationField() {
    return MissionInputLabel(
      label: '计划时长',
      child: SizedBox(
        height: missionInputHeight(context),
        child: TextField(
          key: const ValueKey('mission-duration'),
          expands: true,
          minLines: null,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          controller: widget.durationController,
          enabled: widget.enabled,
          style: Theme.of(context).textTheme.bodyLarge,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: missionInputDecoration(context, hint: '30', suffix: '分钟'),
        ),
      ),
    );
  }

  Widget _scheduleFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 日期和时长在正常宽度并排；窄屏/大字体改为纵排，保留完整日期和单位。
        final scale = MediaQuery.textScalerOf(context).scale(18) / 18;
        if (constraints.maxWidth < 340 * scale) {
          return Column(
            children: [
              _dateField(),
              const SizedBox(height: 20),
              _durationField(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _dateField()),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _durationField()),
          ],
        );
      },
    );
  }

  Widget _timeFields() {
    final colors = Theme.of(context).colorScheme;
    // 两个原生文字按钮共用柔和胶囊底；选中项自身也保留完整圆角和48像素触控高度。
    final selection = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _timeOption(TimePolicy.flexible, '自选'),
          _timeOption(TimePolicy.fixed, '固定'),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final label = Text(
              '时间安排',
              style: Theme.of(context).textTheme.titleMedium,
            );
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            if (constraints.maxWidth < 340 * scale) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [label, const SizedBox(height: 12), selection],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [label, selection],
            );
          },
        ),
        const SizedBox(height: 16),
        // 条件字段原位出现，不打开新路由；自选时明确说明没有固定开始时刻。
        if (widget.timePolicy == TimePolicy.fixed) ...[
          Text('开始时间 · 24小时制', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _clockField(
                  widget.hourController,
                  '开始小时',
                  '时',
                  '00',
                  'mission-hour',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(':'),
              ),
              Expanded(
                child: _clockField(
                  widget.minuteController,
                  '开始分钟',
                  '分',
                  '00',
                  'mission-minute',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '到点自动开始，开始前可修改排期；提前提醒可在“我的”中设置。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ] else
          Text(
            '当天自行安排，无固定开始时刻。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        const SizedBox(height: 8),
        Text(
          widget.timeZone == 'Asia/Shanghai'
              ? '排期时区：上海（Asia/Shanghai）'
              : '排期时区：$widget.timeZone',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _timeOption(TimePolicy policy, String label) {
    final colors = Theme.of(context).colorScheme;
    final selected = widget.timePolicy == policy;
    return Semantics(
      selected: selected,
      child: TextButton(
        key: ValueKey(policy),
        onPressed: widget.enabled
            ? () {
                FocusScope.of(context).unfocus();
                widget.onTimePolicyChanged(policy);
              }
            : null,
        style: TextButton.styleFrom(
          backgroundColor: selected
              ? colors.secondaryContainer
              : colors.primaryContainer,
          foregroundColor: colors.onSurface,
          disabledForegroundColor: colors.onSurfaceVariant,
          minimumSize: const Size(72, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.labelMedium,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _clockField(
    TextEditingController controller,
    String label,
    String unit,
    String hint,
    String key,
  ) {
    return Semantics(
      label: label,
      child: SizedBox(
        height: missionInputHeight(context),
        child: TextField(
          key: ValueKey(key),
          expands: true,
          minLines: null,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          controller: controller,
          enabled: widget.enabled,
          style: Theme.of(context).textTheme.bodyLarge,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: missionInputDecoration(context, hint: hint, suffix: unit),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _scheduleFields(),
      if (_calendarExpanded) ...[
        const SizedBox(height: 12),
        // 日历留在当前表单，选择后只更新日期；不会写库或额外增加页面往返。
        IgnorePointer(
          ignoring: !widget.enabled,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 部分手机的逻辑宽度带小数；跨1至9999年的月份页累计宽度
              // 会触发 Flutter 滚动精度断言。取整并居中，最多收窄不到1，
              // 不缩小可选日期范围，也不修改 Flutter SDK。
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: constraints.maxWidth.floorToDouble(),
                  child: CalendarDatePicker(
                    initialDate: widget.selectedDate,
                    firstDate: DateTime.utc(1),
                    lastDate: DateTime.utc(9999, 12, 31),
                    onDateChanged: (date) {
                      if (!widget.enabled) return;
                      setState(() {
                        _calendarExpanded = false;
                      });
                      widget.onDateChanged(
                        DateTime.utc(date.year, date.month, date.day),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Divider(height: 1),
      ),
      _timeFields(),
    ],
  );
}

// 本表单共用的输入样式与标签放在这里，避免再增加样式辅助文件。
// 普通输入最小52像素；日期在大字体下允许换行并自然增高。
// 随系统字号一起增长，确保真正绘制的边框等高，而不只扩大组件外部占位。
double missionInputHeight(BuildContext context) =>
    22 * (MediaQuery.textScalerOf(context).scale(15) / 15) + 30;

// 输入边界由本页组织，文字使用全站主题中的输入角色。
InputDecoration missionInputDecoration(
  BuildContext context, {
  String? hint,
  String? suffix,
}) {
  final colors = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: colors.outlineVariant),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
    // suffixText 在空输入且未聚焦时会隐藏；单位需要一直可见，因此用 suffixIcon 槽位。
    suffixIcon: suffix == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                suffix,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
    suffixIconConstraints: const BoxConstraints(minWidth: 40),
    filled: true,
    fillColor: colors.primaryContainer.withValues(alpha: 0.45),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
  );
}

/// 外置标签只作视觉展示；由同一个语义节点为编辑框提供用途名称。
/// 日期是按钮而非编辑框，因此由调用者自行提供日期值和按钮语义。
class MissionInputLabel extends StatelessWidget {
  const MissionInputLabel({
    super.key,
    required this.label,
    required this.child,
    this.fieldSemantics = true,
    this.isRequired = true,
  });
  final String label;
  final Widget child;
  final bool fieldSemantics;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    Widget field = child;
    if (fieldSemantics) field = Semantics(label: label, child: child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            isRequired ? '$label *' : label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}
