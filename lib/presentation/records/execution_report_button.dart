import '../../application/errors/user_error_message.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/entities/user_execution_report.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/rules/mission_attention_rules.dart';
import '../../core/theme/app_layout.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_expansion.dart';
import '../widgets/app_settings_row.dart';
import '../widgets/app_section_card.dart';
import '../missions/shared/mission_execution_display.dart';
import 'record_scope.dart';

/// 补记只用于未启动且已过期的任务；报告保存后只允许追加实际时间更正。
class ExecutionReportButton extends StatelessWidget {
  const ExecutionReportButton({
    super.key,
    required this.detail,
    this.onPressed,
    this.enabled = true,
  });
  final MissionDetail detail;
  final VoidCallback? onPressed;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final scope = RecordScope.maybeOf(context);
    if (scope == null || detail.phase == MissionPhase.cancelled) {
      return const SizedBox.shrink();
    }
    final ended = detail.events.any((e) => e.type == ExecutionEventType.end);
    final overdue =
        missionAttention(
          detail.phase,
          detail.schedule,
          scope.service.missions.currentTime,
        ) ==
        MissionAttention.overdue;
    if (!ended && !overdue) return const SizedBox.shrink();
    if (overdue) {
      return FilledButton.icon(
        key: const Key('execution-report-entry'),
        onPressed: !enabled
            ? null
            : onPressed ?? () => showExecutionReportSheet(context, detail),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('确认完成情况'),
      );
    }
    final report = detail.effectiveUserReport;
    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: AppSettingsRow(
        key: const Key('execution-report-entry'),
        icon: Icons.edit_calendar_outlined,
        title: '更正实际日期 / 时段',
        subtitle: report == null
            ? null
            : '${report.occurrenceDate} · ${report.duration == null ? '具体时段未知' : '${report.duration!.inMinutes} 分钟'}',
        enabled: enabled,
        onTap: onPressed ?? () => showExecutionReportSheet(context, detail),
      ),
    );
  }
}

/// 逾期后决定现在实际补做，沿用保留旧排期的业务事务。
class MakeupExecutionButton extends StatefulWidget {
  const MakeupExecutionButton({
    super.key,
    required this.detail,
    this.enabled = true,
  });
  final MissionDetail detail;
  final bool enabled;
  @override
  State<MakeupExecutionButton> createState() => _MakeupButtonState();
}

class _MakeupButtonState extends State<MakeupExecutionButton> {
  final _id = const Uuid().v4();
  bool _busy = false;
  String? _error;
  Future<void> start() async {
    if (_busy || !widget.enabled) return;
    final service = RecordScope.maybeOf(context)!.service.missions;
    DateTime? deadline;
    if (widget.detail.mission.verificationPolicy ==
            VerificationPolicy.requiredEvidence &&
        !(widget.detail.schedule.evidenceDeadlineAt?.isAfter(
              service.currentTime,
            ) ??
            false)) {
      final input = TextEditingController();
      final route = DialogRoute<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('确认补做的材料截止'),
          content: TextField(
            controller: input,
            decoration: const InputDecoration(labelText: '新的截止时间，含时区的ISO8601'),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, input.text),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      final value = await Navigator.of(context).push<String>(route);
      await route.completed;
      input.dispose();
      if (value == null) return;
      try {
        deadline = DateTime.parse(value).toUtc();
      } catch (_) {
        if (mounted) setState(() => _error = '截止时间格式无效');
        return;
      }
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await service.startMakeup(
        widget.detail,
        _id,
        evidenceDeadlineAt: deadline,
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(e, fallback: '执行报告未保存，请检查输入后重试'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: _busy || !widget.enabled ? null : start,
        icon: const Icon(Icons.play_arrow),
        key: const Key('execution-makeup'),
        label: const Text('现在补做'),
      ),
      if (_error != null) Text(_error!),
    ],
  );
}

/// 手机使用底部确认，宽屏使用同一份表单；关闭弹层不保存任何执行事实。
Future<bool?> showExecutionReportSheet(
  BuildContext context,
  MissionDetail detail,
) => showAdaptiveSheet<bool>(
  context: context,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => _ExecutionReportForm(detail: detail),
);

class _ExecutionReportForm extends StatefulWidget {
  const _ExecutionReportForm({required this.detail});
  final MissionDetail detail;
  @override
  State<_ExecutionReportForm> createState() => _ExecutionReportFormState();
}

class _ExecutionReportFormState extends State<_ExecutionReportForm> {
  final _id = const Uuid().v4();
  final _date = TextEditingController(),
      _endDate = TextEditingController(),
      _start = TextEditingController(),
      _end = TextEditingController(),
      _basis = TextEditingController();
  bool _unknown = true, _completed = true, _optional = false, _saving = false;
  String? _error;
  bool get ended =>
      widget.detail.events.any((e) => e.type == ExecutionEventType.end);
  @override
  void initState() {
    super.initState();
    final d = widget.detail;
    final r = d.effectiveUserReport;
    _date.text = r?.occurrenceDate ?? d.schedule.scheduledDate;
    _endDate.text = _date.text;
    final location = tz.getLocation(d.schedule.timeZone);
    // 已声明时段未知时继续保留未知，不能再从计划补出“实际”时间。
    final start = r != null ? r.actualStart : d.schedule.fixedStartAt;
    final end = r != null
        ? r.actualEnd
        : start?.add(Duration(minutes: d.schedule.plannedDurationMinutes));
    if (start != null && end != null) {
      _unknown = false;
      final a = tz.TZDateTime.from(start, location),
          b = tz.TZDateTime.from(end, location);
      _start.text =
          '${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')}';
      _end.text =
          '${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}';
      _endDate.text =
          '${b.year.toString().padLeft(4, '0')}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}';
    }
    if (ended) _completed = d.endReportedCompleted;
  }

  DateTime parse(String date, String time) {
    final d = DateTime.parse(date);
    final parts = time.split(':');
    if (parts.length != 2) throw ArgumentError('时刻格式为 HH:mm');
    final h = int.parse(parts[0]), m = int.parse(parts[1]);
    if (h < 0 || h > 23 || m < 0 || m > 59) throw ArgumentError('时刻无效');
    return tz.TZDateTime(
      tz.getLocation(widget.detail.schedule.timeZone),
      d.year,
      d.month,
      d.day,
      h,
      m,
    ).toUtc();
  }

  Future<void> save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final d = widget.detail;
      final report = UserExecutionReport(
        id: _id,
        missionId: d.mission.id,
        occurrenceDate: _date.text.trim(),
        timeZoneId: d.schedule.timeZone,
        // 用户点确认就是明确依据；更正仍要求说明，不能由 AI 猜测完成。
        basis: _basis.text.trim().isNotEmpty
            ? _basis.text.trim()
            : ended
            ? ''
            : _completed
            ? '用户确认已完成，并确认本次显示的实际日期及${_unknown ? '具体时段未知' : '起止时段'}'
            : '用户确认未执行 / 未完成',
        supersedesId: d.effectiveUserReport?.id,
        actualStart: _unknown ? null : parse(_date.text, _start.text),
        actualEnd: _unknown ? null : parse(_endDate.text, _end.text),
      );
      await RecordScope.maybeOf(context)!.service.report(
        report,
        d,
        result: ended
            ? null
            : _completed
            ? UserReportedResult.completed
            : UserReportedResult.notCompleted,
        submitOptionalEvidence:
            !ended &&
                _completed &&
                d.mission.verificationPolicy ==
                    VerificationPolicy.optionalEvidence
            ? _optional
            : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(e, fallback: '执行报告未保存，请检查输入后重试'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_date, _endDate, _start, _end, _basis]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = widget.detail;
    final summary = _unknown
        ? '${_date.text} · 具体时段未知'
        : '${_date.text} ${_start.text} — ${_endDate.text == _date.text ? '' : '${_endDate.text} '}${_end.text}';
    return PopScope<bool>(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppLayout.spaceXxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ended ? '更正实际时间' : '这项任务完成了吗？',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppLayout.spaceSm),
                  Text(detail.mission.title, style: theme.textTheme.bodyLarge),
                  if (!ended) ...[
                    const SizedBox(height: AppLayout.spaceSm),
                    const Text('计划时段已过，请确认实际完成情况。'),
                    const SizedBox(height: AppLayout.spaceLg),
                    Wrap(
                      spacing: AppLayout.spaceMd,
                      runSpacing: AppLayout.spaceSm,
                      children: [
                        ChoiceChip(
                          key: const Key('retrospective-completed'),
                          label: const Text('已完成'),
                          selected: _completed,
                          onSelected: _saving
                              ? null
                              : (_) => setState(() => _completed = true),
                        ),
                        ChoiceChip(
                          key: const Key('retrospective-not-completed'),
                          label: const Text('未执行 / 未完成'),
                          selected: !_completed,
                          onSelected: _saving
                              ? null
                              : (_) => setState(() {
                                  _completed = false;
                                  // 未执行不能因为预填计划而声明一段实际工作时长。
                                  _unknown = true;
                                }),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppLayout.spaceLg),
                  Text(
                    '实际记录：$summary',
                    key: const Key('execution-report-time-summary'),
                  ),
                  Text(
                    '时区：${detail.schedule.timeZone}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (!ended && !_unknown)
                    const Text('时段按原计划预填，点击确认表示你认可；有出入可修改。'),
                  AppExpansionTile(
                    initiallyExpanded: ended,
                    title: const Text('修改日期、时段或补充说明'),
                    children: [
                      TextField(
                        controller: _date,
                        enabled: !_saving,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: '实际发生日期 YYYY-MM-DD',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('具体时段未知'),
                        value: _unknown,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _unknown = v),
                      ),
                      if (!_unknown) ...[
                        TextField(
                          controller: _start,
                          enabled: !_saving,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: '实际开始 HH:mm',
                          ),
                        ),
                        TextField(
                          controller: _endDate,
                          enabled: !_saving,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: '结束日期 YYYY-MM-DD，可跨日',
                          ),
                        ),
                        TextField(
                          controller: _end,
                          enabled: !_saving,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: '实际结束 HH:mm',
                          ),
                        ),
                      ],
                      const SizedBox(height: AppLayout.spaceMd),
                      TextField(
                        controller: _basis,
                        enabled: !_saving,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: ended ? '依据 / 更正说明（必填）' : '补充说明（可不填）',
                        ),
                      ),
                    ],
                  ),
                  if (!ended &&
                      _completed &&
                      detail.mission.verificationPolicy ==
                          VerificationPolicy.optionalEvidence)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('接下来提交材料'),
                      value: _optional,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _optional = v),
                    ),
                  if (!ended &&
                      _completed &&
                      detail.mission.verificationPolicy ==
                          VerificationPolicy.requiredEvidence)
                    Text(
                      '确认后需补充材料${detail.schedule.evidenceDeadlineAt == null ? '' : '，截止 ${missionLocalTime(detail.schedule.evidenceDeadlineAt!, detail.schedule.timeZone)}'}。',
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppLayout.spaceMd),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: AppLayout.spaceXl),
                  FilledButton(
                    key: const Key('execution-report-confirm'),
                    onPressed: _saving ? null : save,
                    child: Text(
                      _saving
                          ? '正在保存…'
                          : ended
                          ? '保存更正'
                          : '确认',
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceSm),
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(ended ? '取消' : '稍后处理'),
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
