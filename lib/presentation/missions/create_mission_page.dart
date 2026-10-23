// material.dart 提供页面、输入框、按钮、对话框等 Material 风格组件。
import 'package:flutter/material.dart';
// services.dart 提供输入格式器，本页用它限制分钟输入框只接受数字。
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../application/missions/mission_service.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_top_bar.dart';

/// 收集默认独立任务的输入，等待保存，并保护尚未提交的表单内容。
// Widget 描述页面配置；可变化的输入与资源交给下面的 State 管理。
class CreateMissionPage extends StatefulWidget {
  // required 要求打开本页的调用者提供业务对象；this 将参数存到同名属性。
  // super.key 将组件身份标识交给父类；本页目前无需手动指定 key。
  const CreateMissionPage({
    super.key,
    required this.missionService,
    this.initialScheduledDate,
  });

  // 从 TodayPage 传来的同一个业务对象；后续保存时调用，不在本页重新创建。
  final MissionService missionService;
  // 今天页选择了其他日期时，将该日期作为表单默认值；仍允许手动修改。
  final String? initialScheduledDate;

  @override
  State<CreateMissionPage> createState() {
    // Flutter 将此 State 与当前页面配置关联，再调用它的 build。
    return _CreateMissionPageState();
  }
}

class _CreateMissionPageState extends State<CreateMissionPage> {
  // 当前约定的排期时区，默认日期和保存参数都使用它。
  static const String _timeZone = 'Asia/Shanghai';

  // 两个状态分别表示“正在等待保存”和“已经成功创建”。
  bool _isSaving = false;
  bool _isCreated = false;
  // 防止快速返回时重复打开丢弃确认框。
  bool _isClosing = false;

  // null 表示没有错误；有错误时保存要显示给用户的文字。
  String? _errorText;
  // 控制器连接输入框，保存文字、光标等编辑状态；.text 可读取当前文字。
  // 在 State 创建时初始化，避免 build 重复执行时丢失输入。
  // final 固定控制器引用，不妨碍控制器内部的文字变化；下划线表示库内私有。
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  // 只保存用户填写的钟面时间；切回自选可保留草稿，但保存时不会传出。
  final _hourController = TextEditingController();
  final _minuteController = TextEditingController();
  TimePolicy _timePolicy = TimePolicy.flexible;
  bool _calendarExpanded = false;

  // late 表示在 initState 中初始化；final 保留打开表单时的日期，供返回时比较。
  late final String _initialDateText;
  // 日期保存在 State 中，不随 build 重建而重置；用 UTC 日历容器避开设备时区跳日。
  late DateTime _scheduledDate;

  // 这是日历日期键，不是 UTC 开始时刻；年月日不经过设备时区换算。
  String get _dateText {
    final year = _scheduledDate.year.toString().padLeft(4, '0');
    final month = _scheduledDate.month.toString().padLeft(2, '0');
    final day = _scheduledDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool get _canEdit => !_isSaving && !_isCreated && !_isClosing;

  @override
  void initState() {
    super.initState();
    // 业务对象已初始化时区资料；按上海日历取得今天，不随设备时区改变。
    final today = tz.TZDateTime.now(tz.getLocation(_timeZone));
    // padLeft 向左补零，例如 3 → '03'，使日期符合 YYYY-MM-DD 格式。
    final year = today.year.toString().padLeft(4, '0');
    final month = today.month.toString().padLeft(2, '0');
    final day = today.day.toString().padLeft(2, '0');
    _initialDateText = widget.initialScheduledDate ?? '$year-$month-$day';
    validateScheduledDate(_initialDateText);
    final parts = _initialDateText.split('-');
    _scheduledDate = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  void dispose() {
    // Flutter 永久移除此 State 时调用；释放控制器的监听等资源。
    // 关闭确认框不会销毁创建页，也不会执行这里。
    _titleController.dispose();
    _durationController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  // 点击按钮后读取输入，再等待业务层的三表事务；不在 build 中发起保存。
  Future<void> _save() async {
    if (_isSaving || _isCreated || _isClosing) return;
    FocusScope.of(context).unfocus();
    final title = _titleController.text.trim();
    final date = _dateText;
    // 输入框给出字符串；转换失败（包括空值、超出整数范围）返回 null。
    final minutes = int.tryParse(_durationController.text.trim());
    if (minutes == null || minutes <= 0) {
      setState(() {
        _errorText = '计划时长必须是大于 0 的整数分钟';
      });
      return;
    }
    // 立即锁定表单，再进入异步等待，重复点击不会重复提交。
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      DateTime? fixedStartAt;
      if (_timePolicy == TimePolicy.fixed) {
        final hour = int.tryParse(_hourController.text);
        final minute = int.tryParse(_minuteController.text);
        if (hour == null ||
            minute == null ||
            hour < 0 ||
            hour > 23 ||
            minute < 0 ||
            minute > 59) {
          throw ArgumentError('请填写有效的开始时间：小时 00–23，分钟 00–59');
        }
        // 用户提供日期、时和分；TZDateTime 按排期时区解释，不能用设备本地 DateTime。
        final localStart = tz.TZDateTime(
          tz.getLocation(_timeZone),
          _scheduledDate.year,
          _scheduledDate.month,
          _scheduledDate.day,
          hour,
          minute,
        );
        // 夏令时跳过的钟面时间可能被库顺延；不让用户输入被静默改写。
        if (localStart.year != _scheduledDate.year ||
            localStart.month != _scheduledDate.month ||
            localStart.day != _scheduledDate.day ||
            localStart.hour != hour ||
            localStart.minute != minute) {
          throw ArgumentError('所选开始时间在排期时区不存在，请重新填写');
        }
        fixedStartAt = localStart.toUtc();
      }
      // widget 保存页面配置，其中的业务对象由今天页传入。
      // create 校验输入并调用真实仓储；await 成功返回才代表事务已完成。
      await widget.missionService.create(
        title: title,
        scheduledDate: date,
        timeZone: _timeZone,
        plannedDurationMinutes: minutes,
        timePolicy: _timePolicy,
        fixedStartAt: fixedStartAt,
      );
      if (!mounted) return;
      setState(() {
        _isCreated = true;
      });
    } on ArgumentError catch (error) {
      // 业务校验失败：显示原因，不清空控制器中的任何输入。
      if (!mounted) return;
      setState(() {
        _errorText = error.message.toString();
      });
    } catch (error, stackTrace) {
      // 技术细节留在开发日志中，用户只看到可恢复的失败提示。
      debugPrint('创建任务失败：$error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _errorText = '保存失败，输入已保留，请重试';
      });
    } finally {
      // 成功或失败都解除等待状态；页面已销毁时不能再调用 setState。
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // 顶部返回与系统返回共用此方法。Future<void> 表示异步结束后不提供结果值。
  Future<void> _requestClose() async {
    // 保存期间不离开，确认框已打开时也不重复弹框。
    if (_isSaving || _isClosing) return;
    if (_isCreated) {
      Navigator.of(context).pop();
      return;
    }
    // context 表示当前组件在树中的位置；查找所在焦点区域并取消焦点以收起键盘。
    FocusScope.of(context).unfocus();
    // 只读取文字判断是否有输入，不保存任务。|| 表示任一条件成立即可。
    // 日期默认就有内容，因此与初始值比较；只修改或清空日期也需要确认丢弃。
    final hasInput =
        _titleController.text.isNotEmpty ||
        _durationController.text.isNotEmpty ||
        _dateText != _initialDateText ||
        _timePolicy != TimePolicy.flexible ||
        _hourController.text.isNotEmpty ||
        _minuteController.text.isNotEmpty;

    if (hasInput) {
      // 公共框只返回选择；是否关闭表单仍由本页判断。
      // await 等待用户选择：明确放弃返回 true，其余关闭方式返回 false。
      _isClosing = true;
      bool discard;
      try {
        discard = await AppConfirmDialog.show(
          context: context,
          title: '放弃本次填写？',
          message: '返回后，已填写的内容不会保存。',
          cancelText: '继续填写',
          confirmText: '放弃填写',
        );
      } finally {
        // 无论用户怎样关闭确认框，都允许后续再次处理返回。
        _isClosing = false;
      }
      // await 期间页面可能被移除；mounted 表示 State 是否仍挂在组件树上。
      // ! 表示取反；仅在页面仍存在且明确选择 true 时继续，false 保留输入。
      // discard 在 if (hasInput) 内声明，所以这个判断也必须放在同一作用域中。
      if (!mounted || discard != true) {
        return;
      }
    }

    // 没有输入会跳过上面的判断，因此在最终使用 context 前再检查一次。
    if (!mounted) return;

    // pop 移除导航栈顶部的创建页，显示原来的今天页；此处不写数据库。
    Navigator.of(context).pop();
  }

  // 日期含年份和月日两行，统一按这两行所需空间安排输入框高度。
  // 随系统字号一起增长，确保真正绘制的边框等高，而不只扩大组件外部占位。
  double get _fieldHeight =>
      44 * (MediaQuery.textScalerOf(context).scale(18) / 18) + 24;

  // 局部统一输入边界；不修改全局主题，也不为本页新增样式目录。
  InputDecoration _inputDecoration({String? hint, String? suffix}) {
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
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

  Widget _titleField() {
    return _FormField(
      label: '任务名称',
      child: SizedBox(
        height: _fieldHeight,
        child: TextField(
          key: const ValueKey('mission-title'),
          expands: true,
          minLines: null,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.text,
          inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
          controller: _titleController,
          enabled: _canEdit,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(hint: '例如：阅读 Flutter'),
        ),
      ),
    );
  }

  Widget _dateField() {
    final colors = Theme.of(context).colorScheme;
    // Semantics 将外置标签、日期值与按钮动作合成一个节点，避免图标重复朗读。
    return _FormField(
      label: '计划日期',
      fieldSemantics: false,
      child: Semantics(
        label: '计划日期',
        value: _dateText,
        button: true,
        expanded: _calendarExpanded,
        enabled: _canEdit,
        child: Material(
          color: colors.primaryContainer.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('mission-date'),
            onTap: _canEdit
                ? () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _calendarExpanded = !_calendarExpanded;
                    });
                  }
                : null,
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(height: _fieldHeight),
              child: ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(18) / 18;
                    // 大字体优先给完整日期留空间，必要时省去装饰性日历图标。
                    final showCalendarIcon =
                        constraints.maxWidth >= 190 * scale;
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_scheduledDate.year}年',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  '${_scheduledDate.month}月${_scheduledDate.day}日',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ],
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
    return _FormField(
      label: '计划时长',
      child: SizedBox(
        height: _fieldHeight,
        child: TextField(
          key: const ValueKey('mission-duration'),
          expands: true,
          minLines: null,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          controller: _durationController,
          enabled: _canEdit,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration(hint: '30', suffix: '分钟'),
        ),
      ),
    );
  }

  Widget _scheduleFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 日期和时长在正常宽度并排；窄屏/大字体改为纵排，保留完整日期和单位。
        final scale = MediaQuery.textScalerOf(context).scale(18) / 18;
        if (constraints.maxWidth < 300 * scale) {
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
              style: Theme.of(context).textTheme.titleLarge,
            );
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            if (constraints.maxWidth < 300 * scale) {
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
        if (_timePolicy == TimePolicy.fixed) ...[
          const Text('开始时间 · 24小时制'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _clockField(
                  _hourController,
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
                  _minuteController,
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
            '按所选日期的上海时间安排，创建后仍需手动开始。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ] else
          const Text('当天自行安排，无固定开始时刻。'),
        const SizedBox(height: 8),
        Text(
          '排期时区：上海（Asia/Shanghai）',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _timeOption(TimePolicy policy, String label) {
    final colors = Theme.of(context).colorScheme;
    final selected = _timePolicy == policy;
    return Semantics(
      selected: selected,
      child: TextButton(
        key: ValueKey(policy),
        onPressed: _canEdit
            ? () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _timePolicy = policy;
                  _errorText = null;
                });
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
          textStyle: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
          ),
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
        height: _fieldHeight,
        child: TextField(
          key: ValueKey(key),
          expands: true,
          minLines: null,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          controller: controller,
          enabled: _canEdit,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: _inputDecoration(hint: hint, suffix: unit),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String createButtonLabel = '创建任务';
    if (_isCreated) {
      createButtonLabel = '已创建';
    } else if (_isSaving) {
      createButtonLabel = '正在创建…';
    }
    final colors = Theme.of(context).colorScheme;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _requestClose();
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: '新建任务',
          // 公共组件只负责点击分发，丢弃确认仍使用本页原来的方法。
          onBack: _requestClose,
          canGoBack: !_isSaving,
        ),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              // 当前入口只创建临时任务，因此不展示节点路径；目标树关联须接通真实保存后再显示。
              _titleField(), const SizedBox(height: 24),
              _scheduleFields(),
              if (_calendarExpanded) ...[
                const SizedBox(height: 12),
                // 日历留在当前表单，选择后只更新日期；不会写库或额外增加页面往返。
                IgnorePointer(
                  ignoring: !_canEdit,
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
                            initialDate: _scheduledDate,
                            firstDate: DateTime.utc(1),
                            lastDate: DateTime.utc(9999, 12, 31),
                            onDateChanged: (date) {
                              if (!_canEdit) return;
                              setState(() {
                                _scheduledDate = DateTime.utc(
                                  date.year,
                                  date.month,
                                  date.day,
                                );
                                _calendarExpanded = false;
                                _errorText = null;
                              });
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(height: 1),
              ),
              // 当前只接通自报；这里是静态信息，不画尚未实现的材料策略下拉按钮。
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '完成方式',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Expanded(child: Text('自报完成', textAlign: TextAlign.end)),
                ],
              ),
            ],
          ),
        ),
        // 主操作独立于滚动内容；键盘出现时跟随 Scaffold 上移，内容仍可滚动。
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorText != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _errorText!,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isCreated) ...[
                  Semantics(
                    liveRegion: true,
                    child: const Text('任务已创建，可返回今天页'),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      height: 24 / 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _canEdit ? _save : null,
                  child: Text(createButtonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 外置标签只作视觉展示；由同一个语义节点为编辑框提供用途名称。
/// 日期是按钮而非编辑框，因此由调用者自行提供日期值和按钮语义。
class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.child,
    this.fieldSemantics = true,
  });
  final String label;
  final Widget child;
  final bool fieldSemantics;

  @override
  Widget build(BuildContext context) {
    Widget field = child;
    if (fieldSemantics) field = Semantics(label: label, child: child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            '$label *',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}
