import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/entities/user_execution_report.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/rules/mission_attention_rules.dart';
import 'record_scope.dart';

class ExecutionReportButton extends StatelessWidget {
  const ExecutionReportButton({super.key, required this.detail});
  final MissionDetail detail;
  @override
  Widget build(BuildContext context) {
    if (RecordScope.maybeOf(context) == null ||
        detail.phase == MissionPhase.cancelled) {
      return const SizedBox.shrink();
    }
    final ended = detail.events.any((e) => e.type == ExecutionEventType.end);
    final overdue =
        missionAttention(detail.phase, detail.schedule, DateTime.now()) ==
        MissionAttention.overdue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overdue) const Text('待处理 · 计划时段已过，请确认实际情况、改期或现在补做。'),
        if (overdue) _MakeupButton(detail: detail),
        if (detail.effectiveUserReport != null)
          Text(
            '用户声明：${detail.effectiveUserReport!.occurrenceDate} · ${detail.effectiveUserReport!.duration == null ? '具体时段未知' : '${detail.effectiveUserReport!.duration!.inMinutes} 分钟'}',
          ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => _ExecutionReportPage(detail: detail),
            ),
          ),
          icon: const Icon(Icons.edit_calendar_outlined),
          label: Text(ended ? '更正实际日期 / 时段' : '补记完成 / 记录未执行'),
        ),
      ],
    );
  }
}

class _MakeupButton extends StatefulWidget {
  const _MakeupButton({required this.detail});
  final MissionDetail detail;
  @override
  State<_MakeupButton> createState() => _MakeupButtonState();
}

class _MakeupButtonState extends State<_MakeupButton> {
  final _id = const Uuid().v4();
  bool _busy = false;
  String? _error;
  Future<void> start() async {
    final service = RecordScope.maybeOf(context)!.service.missions;
    DateTime? deadline;
    if (widget.detail.mission.verificationPolicy ==
            VerificationPolicy.requiredEvidence &&
        !(widget.detail.schedule.evidenceDeadlineAt?.isAfter(DateTime.now()) ??
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
            TextButton(
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
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: _busy ? null : start,
        icon: const Icon(Icons.play_arrow),
        label: const Text('现在补做（保留原排期）'),
      ),
      if (_error != null) Text(_error!),
    ],
  );
}

class _ExecutionReportPage extends StatefulWidget {
  const _ExecutionReportPage({required this.detail});
  final MissionDetail detail;
  @override
  State<_ExecutionReportPage> createState() => _ExecutionReportPageState();
}

class _ExecutionReportPageState extends State<_ExecutionReportPage> {
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
    final start = r?.actualStart ?? d.schedule.fixedStartAt;
    final end =
        r?.actualEnd ??
        start?.add(Duration(minutes: d.schedule.plannedDurationMinutes));
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
        basis: _basis.text.trim(),
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(ended ? '更正实际时间' : '补记执行情况')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.detail.mission.title),
        const SizedBox(height: 12),
        Text('时区：${widget.detail.schedule.timeZone}。预填的计划时段只有在你确认保存后才成为自报时间。'),
        if (!ended)
          SwitchListTile(
            title: Text(_completed ? '已完成' : '未执行 / 未完成'),
            value: _completed,
            onChanged: _saving ? null : (v) => setState(() => _completed = v),
          ),
        TextField(
          controller: _date,
          enabled: !_saving,
          decoration: const InputDecoration(labelText: '实际发生日期 YYYY-MM-DD'),
        ),
        SwitchListTile(
          title: const Text('具体时段未知'),
          value: _unknown,
          onChanged: _saving ? null : (v) => setState(() => _unknown = v),
        ),
        if (!_unknown) ...[
          TextField(
            controller: _start,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: '实际开始 HH:mm'),
          ),
          TextField(
            controller: _endDate,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: '结束日期 YYYY-MM-DD，可跨日'),
          ),
          TextField(
            controller: _end,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: '实际结束 HH:mm'),
          ),
        ],
        TextField(
          controller: _basis,
          enabled: !_saving,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: '依据 / 更正说明（必填）'),
        ),
        if (!ended &&
            _completed &&
            widget.detail.mission.verificationPolicy ==
                VerificationPolicy.optionalEvidence)
          SwitchListTile(
            title: const Text('稍后提交材料'),
            value: _optional,
            onChanged: _saving ? null : (v) => setState(() => _optional = v),
          ),
        const SizedBox(height: 12),
        const Text('保留原计划、计时和完成报告；保存不会补造开始事件。'),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(
          onPressed: _saving ? null : save,
          child: Text(_saving ? '正在保存…' : '确认实际情况并保存'),
        ),
      ],
    ),
  );
}
