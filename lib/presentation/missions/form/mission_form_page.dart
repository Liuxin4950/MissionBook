// material.dart 提供页面、输入框、按钮、对话框等 Material 风格组件。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../domain/entities/mission_schedule_revision.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/detail_pane.dart';
import '../../widgets/page_footer_bar.dart';
import 'mission_schedule_fields.dart';
import 'mission_evidence_fields.dart';
import 'mission_ownership_field.dart';
import '../../../domain/entities/goal.dart';
import '../../../domain/entities/goal_node.dart';
import '../../../domain/entities/mission_ownership.dart';
import '../../../domain/entities/mission_creation.dart';

/// 创建、编辑或再次尝试任务，共用排期、材料要求及未保存输入保护。
// Widget 描述页面配置；可变化的输入与资源交给下面的 State 管理。
class MissionFormPage extends StatefulWidget {
  // required 要求打开本页的调用者提供业务对象；this 将参数存到同名属性。
  // super.key 将组件身份标识交给父类；本页目前无需手动指定 key。
  const MissionFormPage({
    super.key,
    required this.missionService,
    this.initialScheduledDate,
  }) : original = null,
       retrySource = null,
       initialGoal = null,
       initialNode = null;

  const MissionFormPage.forGoal({
    super.key,
    required this.missionService,
    required Goal goal,
    GoalNode? node,
  }) : initialGoal = goal,
       initialNode = node,
       original = null,
       retrySource = null,
       initialScheduledDate = null;

  /// 详情页传入读到的完整快照，既用于带入原值，也用于保存时检查冲突。
  const MissionFormPage.edit({
    super.key,
    required this.missionService,
    required MissionDetail detail,
  }) : original = detail,
       initialGoal = null,
       initialNode = null,
       retrySource = null,
       initialScheduledDate = null;

  /// 来源仅用于预填新草稿；保存前不建任务，不复制旧执行事实。
  const MissionFormPage.retry({
    super.key,
    required this.missionService,
    required MissionDetail source,
  }) : retrySource = source,
       initialGoal = null,
       initialNode = null,
       original = null,
       initialScheduledDate = null;

  final MissionDetail? original;
  final MissionDetail? retrySource;
  final Goal? initialGoal; // 从目标/节点“建任务”传入，只预填草稿，不会自动创建。
  final GoalNode? initialNode;

  // 从 TodayPage 传来的同一个业务对象；后续保存时调用，不在本页重新创建。
  final MissionService missionService;
  // 今天页选择了其他日期时，将该日期作为表单默认值；仍允许手动修改。
  final String? initialScheduledDate;

  @override
  State<MissionFormPage> createState() {
    // Flutter 将此 State 与当前页面配置关联，再调用它的 build。
    return _MissionFormPageState();
  }
}

class _MissionFormPageState extends State<MissionFormPage> {
  // 当前约定的排期时区，默认日期和保存参数都使用它。
  String get _timeZone =>
      widget.original?.schedule.timeZone ??
      widget.retrySource?.schedule.timeZone ??
      'Asia/Shanghai';
  bool get _isEditing => widget.original != null;
  bool get _isRetry => widget.retrySource != null;

  // 两个状态分别表示“正在等待保存”和“已经成功保存”。
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
  final _objectiveController = TextEditingController();
  bool _objectiveEdited = false; // 用户亲自改过具体目标后，不再用任务名称覆盖它。
  final _descriptionController = TextEditingController();
  final _whyController = TextEditingController();
  late MissionOwnership _ownership;
  late final MissionOwnership _initialOwnership;
  late final String _initialDescription, _initialWhy;
  MissionCreation? _pendingCreation; // 保存结果未知时保留原请求，重试沿用原任务编号。
  final _durationController = TextEditingController();
  // 只保存用户填写的钟面时间；切回自选可保留草稿，但保存时不会传出。
  final _hourController = TextEditingController();
  final _minuteController = TextEditingController();
  TimePolicy _timePolicy = TimePolicy.flexible;
  // 普通新任务允许自愿留材料；旧任务和再次尝试会在 initState 带入原策略。
  VerificationPolicy _verificationPolicy = VerificationPolicy.optionalEvidence;
  final _criteriaController = TextEditingController();
  final _deadlineHourController = TextEditingController();
  final _deadlineMinuteController = TextEditingController();
  DateTime? _deadlineDate; // 只装年月日；保存时再按任务时区转为绝对时刻。

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

  bool get _canEdit =>
      !_isSaving && !_isCreated && !_isClosing && _pendingCreation == null;

  @override
  void initState() {
    super.initState();
    // 业务对象已初始化时区资料；按排期时区取得今天，不随设备时区改变。
    final today = tz.TZDateTime.now(tz.getLocation(_timeZone));
    // padLeft 向左补零，例如 3 → '03'，使日期符合 YYYY-MM-DD 格式。
    final year = today.year.toString().padLeft(4, '0');
    final month = today.month.toString().padLeft(2, '0');
    final day = today.day.toString().padLeft(2, '0');
    final original = widget.original;
    _initialDateText =
        original?.schedule.scheduledDate ??
        widget.initialScheduledDate ??
        '$year-$month-$day';
    validateScheduledDate(_initialDateText);
    final parts = _initialDateText.split('-');
    _scheduledDate = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final seed = original ?? widget.retrySource;
    _ownership =
        seed?.mission.ownership ??
        MissionOwnership(
          goalId: widget.initialGoal?.id,
          goalNodeId: widget.initialNode?.id,
        );
    _initialOwnership = _ownership;
    _descriptionController.text =
        seed?.mission.description ?? widget.initialNode?.description ?? '';
    _whyController.text = seed?.mission.why ?? widget.initialGoal?.why ?? '';
    if (seed == null && widget.initialGoal != null) {
      _titleController.text =
          widget.initialNode?.title ?? widget.initialGoal!.title;
      _objectiveController.text = _titleController.text;
    }
    if (seed != null) {
      _verificationPolicy = seed.mission.verificationPolicy;
      _criteriaController.text = seed.executionPlan.verificationCriteria ?? '';
      _titleController.text = seed.mission.title;
      _objectiveController.text = seed.executionPlan.objective;
      _durationController.text = seed.schedule.plannedDurationMinutes
          .toString();
      // 重试重新安排日期，自选时间起步，不沿用已经过去的固定开始时刻。
      _timePolicy = original?.schedule.timePolicy ?? TimePolicy.flexible;
      final start = original?.schedule.fixedStartAt;
      if (start != null) {
        final local = tz.TZDateTime.from(start, tz.getLocation(_timeZone));
        _hourController.text = local.hour.toString().padLeft(2, '0');
        _minuteController.text = local.minute.toString().padLeft(2, '0');
      }
    }
    // 编辑保留原截止；再次尝试必须重新选截止，不复制已过去的日期。
    final deadline = original?.schedule.evidenceDeadlineAt;
    if (deadline != null) {
      final local = tz.TZDateTime.from(deadline, tz.getLocation(_timeZone));
      _deadlineDate = DateTime.utc(local.year, local.month, local.day);
      _deadlineHourController.text = local.hour.toString().padLeft(2, '0');
      _deadlineMinuteController.text = local.minute.toString().padLeft(2, '0');
    } else if (_verificationPolicy == VerificationPolicy.requiredEvidence) {
      // 再次尝试沿用材料要求，但截止随本次新排期计算，不复制旧任务的期限。
      _setDefaultEvidenceDeadline();
    }
    _initialTitle = _titleController.text;
    _initialDescription = _descriptionController.text;
    _initialWhy = _whyController.text;
    _initialObjective = _objectiveController.text;
    _initialDuration = _durationController.text;
    _initialPolicy = _timePolicy;
    _initialHour = _hourController.text;
    _initialMinute = _minuteController.text;
    _initialVerificationPolicy = _verificationPolicy;
    _initialCriteria = _criteriaController.text;
    _initialDeadlineDate = _deadlineDate;
    _initialDeadlineHour = _deadlineHourController.text;
    _initialDeadlineMinute = _deadlineMinuteController.text;
    _titleController.addListener(() {
      if (!_isEditing && !_isRetry && !_objectiveEdited) {
        _objectiveController.text = _titleController.text;
      }
    }); // 新任务的默认具体目标跟随名称；监听只整理草稿，不会保存任务。
  }

  late final String _initialTitle, _initialObjective, _initialDuration;
  late final String _initialHour, _initialMinute;
  late final TimePolicy _initialPolicy;
  late final VerificationPolicy _initialVerificationPolicy;
  late final String _initialCriteria,
      _initialDeadlineHour,
      _initialDeadlineMinute;
  late final DateTime? _initialDeadlineDate;

  bool get _hasChanges =>
      _ownership != _initialOwnership ||
      _pendingCreation != null ||
      _descriptionController.text != _initialDescription ||
      _whyController.text != _initialWhy ||
      _titleController.text != _initialTitle ||
      _objectiveController.text != _initialObjective ||
      _durationController.text != _initialDuration ||
      _dateText != _initialDateText ||
      _timePolicy != _initialPolicy ||
      _hourController.text != _initialHour ||
      _minuteController.text != _initialMinute ||
      _verificationPolicy != _initialVerificationPolicy ||
      _criteriaController.text != _initialCriteria ||
      _deadlineDate != _initialDeadlineDate ||
      _deadlineHourController.text != _initialDeadlineHour ||
      _deadlineMinuteController.text != _initialDeadlineMinute;

  /// 默认给到排期日结束；这里只填写可见草稿，用户仍可改日期和钟面时间。
  void _setDefaultEvidenceDeadline() {
    _deadlineDate = DateTime.utc(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day + 1,
    );
    _deadlineHourController.text = '00';
    _deadlineMinuteController.text = '00';
  }

  @override
  void dispose() {
    // Flutter 永久移除此 State 时调用；释放控制器的监听等资源。
    // 关闭确认框不会销毁创建页，也不会执行这里。
    _titleController.dispose();
    _objectiveController.dispose();
    _descriptionController.dispose();
    _whyController.dispose();
    _durationController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _criteriaController.dispose();
    _deadlineHourController.dispose();
    _deadlineMinuteController.dispose();
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
        // 表单只开放时、分。钟面值与日期未变时，保留原绝对时刻的秒/毫秒，
        // 避免单纯改名称也意外制造一个排期版本。
        final oldStart = widget.original?.schedule.fixedStartAt;
        if (oldStart != null && _dateText == _initialDateText) {
          final oldLocal = tz.TZDateTime.from(
            oldStart,
            tz.getLocation(_timeZone),
          );
          if (oldLocal.hour == hour && oldLocal.minute == minute) {
            fixedStartAt = oldStart;
          }
        }
      }
      // widget 保存页面配置，其中的业务对象由今天页传入。
      // 按本页模式选择创建或编辑；await 成功返回才代表事务已完成。
      final evidenceDeadlineAt = _readEvidenceDeadline();
      final criteria = _criteriaController.text.trim();
      if (_verificationPolicy == VerificationPolicy.requiredEvidence &&
          criteria.isEmpty) {
        throw ArgumentError('请填写需要提交什么材料，便于之后核对');
      }
      // 切换策略保留页面草稿，但不把当前策略不适用的值写入任务。
      final verificationCriteria =
          _verificationPolicy == VerificationPolicy.selfReport ||
              criteria.isEmpty
          ? null
          : criteria;
      final original = widget.original;
      if (original == null) {
        _pendingCreation ??= widget.missionService.prepareCreation(
          title: title,
          scheduledDate: date,
          timeZone: _timeZone,
          plannedDurationMinutes: minutes,
          timePolicy: _timePolicy,
          fixedStartAt: fixedStartAt,
          retrySource: widget.retrySource,
          objective: _objectiveController.text.trim().isEmpty
              ? null
              : _objectiveController.text,
          ownership: _ownership,
          description: _descriptionController.text,
          why: _whyController.text,
          verificationPolicy: _verificationPolicy,
          verificationCriteria: verificationCriteria,
          evidenceDeadlineAt: evidenceDeadlineAt,
        );
        await widget.missionService.createPrepared(_pendingCreation!);
      } else {
        await widget.missionService.edit(
          original: original,
          title: title,
          objective: _objectiveController.text,
          scheduledDate: date,
          plannedDurationMinutes: minutes,
          timePolicy: _timePolicy,
          fixedStartAt: fixedStartAt,
          verificationPolicy: _verificationPolicy,
          verificationCriteria: verificationCriteria,
          evidenceDeadlineAt: evidenceDeadlineAt,
          ownership: _ownership,
          description: _descriptionController.text,
          why: _whyController.text,
          updateContext: true,
        );
      }
      if (!mounted) return;
      setState(() {
        _isCreated = true;
      });
      if (_isEditing || _isRetry || widget.initialGoal != null) {
        // 编辑成功直接返回原详情，true 让详情重新读库，不额外堆一个结果页。
        Navigator.of(context).pop(true);
      }
    } on MissionEditConflict catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.message;
      });
    } on ArgumentError catch (error) {
      // 业务校验失败：显示原因，不清空控制器中的任何输入。
      if (!mounted) return;
      setState(() {
        _pendingCreation = null; // 明确的业务拒绝没有写入，可以修改归属或其他输入后重新保存。
        _errorText = error.message.toString();
      });
    } catch (error, stackTrace) {
      // 技术细节留在开发日志中，用户只看到可恢复的失败提示。
      debugPrint('保存任务失败：$error\n$stackTrace');
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

  Future<void> _checkCreation() async {
    final request = _pendingCreation;
    if (request == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final saved = await widget.missionService.findDetail(
        missionId: request.mission.id,
      );
      if (!mounted) return;
      if (saved != null) {
        setState(() => _isCreated = true);
        if (_isRetry || widget.initialGoal != null) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _pendingCreation = null;
          _errorText = '尚未保存，可继续修改后创建';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _errorText = '暂时无法确认，请保留当前请求，稍后重试或检查保存结果');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 将用户选中的截止日期、时分按排期时区解释；非强制策略不带出旧草稿。
  DateTime? _readEvidenceDeadline() {
    if (_verificationPolicy != VerificationPolicy.requiredEvidence) return null;
    final date = _deadlineDate;
    final hour = int.tryParse(_deadlineHourController.text);
    final minute = int.tryParse(_deadlineMinuteController.text);
    if (date == null) throw ArgumentError('请选择材料提交截止日期');
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw ArgumentError('请填写有效的截止时间：小时 00–23，分钟 00–59');
    }
    final local = tz.TZDateTime(
      tz.getLocation(_timeZone),
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    // 夏令时不存在的钟面时间不能被静默顺延。
    if (local.year != date.year ||
        local.month != date.month ||
        local.day != date.day ||
        local.hour != hour ||
        local.minute != minute) {
      throw ArgumentError('所选截止时间在任务时区不存在，请重新填写');
    }
    final oldDeadline = widget.original?.schedule.evidenceDeadlineAt;
    if (oldDeadline != null &&
        _deadlineDate == _initialDeadlineDate &&
        _deadlineHourController.text == _initialDeadlineHour &&
        _deadlineMinuteController.text == _initialDeadlineMinute) {
      return oldDeadline; // 未改截止时保留原秒/毫秒，避免无意新增排期版本。
    }
    return local.toUtc();
  }

  // 表单放进右栏后，切换/清空前由右栏导航先问这里；
  // 与顶部返回、系统返回共用同一套未保存确认，不允许绕过。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    DetailPaneScope.maybeOf(
      context,
    )?.registerTopGuard(_mayLeave, route: ModalRoute.of(context));
  }

  // 只回答“现在能不能离开”：不负责关闭，由调用方决定怎么离开。
  Future<bool> _mayLeave() async {
    if (_isSaving || _isClosing) return false;
    if (_isCreated || !_hasChanges) return true;
    FocusScope.of(context).unfocus();
    return _confirmDiscard();
  }

  // 未保存输入的丢弃确认；await 等待用户选择：明确放弃返回 true，其余 false。
  Future<bool> _confirmDiscard() async {
    _isClosing = true;
    try {
      return await AppConfirmDialog.show(
        context: context,
        title: _isEditing ? '放弃本次修改？' : '放弃本次填写？',
        message: _pendingCreation != null
            ? '这次保存结果尚未确认，任务可能已经保存。建议先检查保存结果；现在离开会丢弃当前页面输入。'
            : _isEditing
            ? '返回后，本次修改不会保存，原任务保持不变。'
            : '返回后，已填写的内容不会保存。',
        cancelText: '继续填写',
        confirmText: _isEditing ? '放弃修改' : '放弃填写',
      );
    } finally {
      // 无论用户怎样关闭确认框，都允许后续再次处理返回。
      _isClosing = false;
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
    if (_hasChanges) {
      // 公共框只返回选择；是否关闭表单仍由本页判断。
      final discard = await _confirmDiscard();
      // await 期间页面可能被移除；mounted 表示 State 是否仍挂在组件树上。
      // 仅在页面仍存在且明确选择 true 时继续，false 保留输入。
      if (!mounted || discard != true) return;
    }

    // 没有输入会跳过上面的判断，因此在最终使用 context 前再检查一次。
    if (!mounted) return;

    // pop 移除导航栈顶部的创建页，显示原来的今天页；此处不写数据库。
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    String createButtonLabel = _isEditing ? '保存修改' : '创建任务';
    if (_isCreated) {
      createButtonLabel = _isEditing ? '已保存' : '已创建';
    } else if (_isSaving) {
      createButtonLabel = _isEditing ? '正在保存…' : '正在创建…';
    }
    final colors = Theme.of(context).colorScheme;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _requestClose();
      },
      child: CallbackShortcuts(
        // 桌面键盘（Phase 4）：Esc 与顶部返回同一关闭守卫；Ctrl+Enter 保存。
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _requestClose,
          const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
        },
        child: Scaffold(
          appBar: AppTopBar(
            title: _isEditing ? '编辑任务' : (_isRetry ? '再次尝试' : '新建任务'),
            // 公共组件只负责点击分发，丢弃确认仍使用本页原来的方法。
            onBack: _requestClose,
            canGoBack: !_isSaving,
          ),
          body: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.maxPageWidth,
                ),
                // 本页只有少量固定输入区，整体滚动保留所有输入组件。
                // 展开日历或滚到材料设置后，标题等离屏字段仍保持同一编辑状态。
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: AppLayout.pagePadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MissionOwnershipField(
                        service: widget.missionService,
                        value: _ownership,
                        enabled: _canEdit,
                        onChanged: (value) => setState(() {
                          _ownership = value;
                          _errorText = null;
                        }),
                      ),
                      _MissionFormFields(
                        titleController: _titleController,
                        enabled: _canEdit,
                      ),
                      MissionScheduleFields(
                        selectedDate: _scheduledDate,
                        dateText: _dateText,
                        timePolicy: _timePolicy,
                        timeZone: _timeZone,
                        durationController: _durationController,
                        hourController: _hourController,
                        minuteController: _minuteController,
                        enabled: _canEdit,
                        onDateChanged: (date) => setState(() {
                          final changed = date != _scheduledDate;
                          _scheduledDate = date;
                          if (changed &&
                              _verificationPolicy ==
                                  VerificationPolicy.requiredEvidence) {
                            // 改排期日时，按新日期重设并展示截止；保存后才形成新排期版本。
                            _setDefaultEvidenceDeadline();
                          }
                          _errorText = null;
                        }),
                        onTimePolicyChanged: (policy) => setState(() {
                          _timePolicy = policy;
                          _errorText = null;
                        }),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Divider(height: 1),
                      ),
                      MissionEvidenceFields(
                        policy: _verificationPolicy,
                        criteriaController: _criteriaController,
                        deadlineDate: _deadlineDate,
                        suggestedDate: _scheduledDate,
                        hourController: _deadlineHourController,
                        minuteController: _deadlineMinuteController,
                        timeZone: _timeZone,
                        enabled: _canEdit,
                        onPolicyChanged: (policy) => setState(() {
                          _verificationPolicy = policy;
                          if (policy == VerificationPolicy.requiredEvidence &&
                              _deadlineDate == null) {
                            _setDefaultEvidenceDeadline();
                          }
                          _errorText = null;
                        }),
                        onDateChanged: (date) => setState(() {
                          _deadlineDate = DateTime.utc(
                            date.year,
                            date.month,
                            date.day,
                          );
                          _errorText = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      ExpansionTile(
                        key: const Key('mission-plan-toggle'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          '详细方案（选填）',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        initiallyExpanded: _isEditing || _isRetry,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.retrySource != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                '来自任务：${widget.retrySource!.mission.title}\n保存后创建新的尝试，原记录保持不变。',
                              ),
                            ),
                          MissionInputLabel(
                            label: '具体目标',
                            child: TextField(
                              key: const Key('mission-objective'),
                              controller: _objectiveController,
                              enabled: _canEdit,
                              minLines: 2,
                              maxLines: 4,
                              onChanged: (_) => _objectiveEdited = true,
                              style: Theme.of(context).textTheme.bodyLarge,
                              decoration: missionInputDecoration(
                                context,
                                hint: '默认使用任务名称，可以单独修改',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          MissionInputLabel(
                            label: '任务说明',
                            child: TextField(
                              key: const Key('mission-description'),
                              controller: _descriptionController,
                              enabled: _canEdit,
                              minLines: 2,
                              maxLines: 5,
                              style: Theme.of(context).textTheme.bodyLarge,
                              decoration: missionInputDecoration(
                                context,
                                hint: '补充本次行动的范围',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          MissionInputLabel(
                            label: '为什么做',
                            child: TextField(
                              key: const Key('mission-why'),
                              controller: _whyController,
                              enabled: _canEdit,
                              minLines: 2,
                              maxLines: 5,
                              style: Theme.of(context).textTheme.bodyLarge,
                              decoration: missionInputDecoration(
                                context,
                                hint: '这次行动对你有什么意义',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 主操作独立于滚动内容；键盘出现时跟随 Scaffold 上移，内容仍可滚动。
          bottomNavigationBar: SafeArea(
            top: false,
            child: PageFooterBar(
              topPadding: 12,
              bottomPadding: 16 + MediaQuery.viewInsetsOf(context).bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorText != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _errorText!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: colors.error),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isCreated) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '任务已创建，可返回今天页',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_pendingCreation != null && !_isCreated)
                    TextButton(
                      onPressed: _isSaving ? null : _checkCreation,
                      child: const Text('检查保存结果'),
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                    onPressed: (!_isSaving && !_isCreated && !_isClosing)
                        ? _save
                        : null,
                    child: Text(createButtonLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 任务名称输入；草稿控制器由表单持有，其余方案字段在表单的折叠区组装。
class _MissionFormFields extends StatelessWidget {
  const _MissionFormFields({
    required this.titleController,
    required this.enabled,
  });
  final TextEditingController titleController;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppLayout.sectionGap),
    child: _titleField(context),
  );
  Widget _titleField(BuildContext context) {
    return MissionInputLabel(
      label: '任务名称',
      child: SizedBox(
        height: missionInputHeight(context),
        child: TextField(
          key: const ValueKey('mission-title'),
          expands: true,
          minLines: null,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.text,
          inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
          controller: titleController,
          enabled: enabled,
          style: Theme.of(context).textTheme.bodyLarge,
          textInputAction: TextInputAction.next,
          decoration: missionInputDecoration(context, hint: '例如：阅读 Flutter'),
        ),
      ),
    );
  }
}
