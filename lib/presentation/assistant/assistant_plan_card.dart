import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../application/assistant/assistant_controller.dart';
import '../../application/assistant/assistant_plan.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/mission_schedule_revision.dart';

/// 一份真实计划的预览、逐项修改与保存结果；窄屏沿阅读顺序纵向排列。
class AssistantPlanCard extends StatelessWidget {
  const AssistantPlanCard({
    super.key,
    required this.controller,
    required this.operation,
    required this.onOpenReference,
  });
  final AssistantController controller;
  final AssistantOperation operation;
  final void Function(String, String) onOpenReference;

  bool get _waiting =>
      operation.status == AssistantOperationStatus.waitingConfirmation;

  Future<void> _edit(BuildContext context, Map<String, Object?> row) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (_) => _PlanItemEditor(
          row: row,
          onSave: (updated) async {
            final items = AssistantPlanService.rows(operation.input);
            final index = items.indexWhere(
              (item) => item['itemId'] == row['itemId'],
            );
            if (index < 0) return '这项安排已移除';
            items[index] = updated;
            final error = controller.updateProposal(operation.callId, {
              ...operation.input,
              'items': items,
            });
            if (error != null) return error;
            return controller.refreshPlanPreview(operation.callId);
          },
        ),
      );

  Future<void> _remove(BuildContext context, Map<String, Object?> row) async {
    final items = AssistantPlanService.rows(operation.input)
      ..removeWhere((item) => item['itemId'] == row['itemId']);
    final error = controller.updateProposal(operation.callId, {
      ...operation.input,
      'items': items,
    });
    if (error != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    await controller.refreshPlanPreview(operation.callId);
  }

  @override
  Widget build(BuildContext context) {
    final items = AssistantPlanService.rows(operation.input);
    final totalMinutes = items.fold<int>(
      0,
      (sum, item) => sum + (int.tryParse('${item['plannedMinutes']}') ?? 0),
    );
    final failed = operation.status == AssistantOperationStatus.failed;
    final success = operation.status == AssistantOperationStatus.succeeded;
    final editable = _waiting && !operation.planChecking;
    final status = switch (operation.status) {
      AssistantOperationStatus.waitingConfirmation =>
        operation.planChecking ? '检查安排中' : '待确认',
      AssistantOperationStatus.running => '正在保存',
      AssistantOperationStatus.succeeded => '已保存',
      AssistantOperationStatus.failed => '未保存',
      AssistantOperationStatus.cancelled => '已取消',
      AssistantOperationStatus.unknown => '结果待核对',
    };
    Map? result;
    try {
      result = jsonDecode(operation.output ?? '') as Map;
    } catch (_) {
      /* 结果可能尚未返回。 */
    }
    final saved = <String, Map>{};
    if (success && result?['items'] is List) {
      for (final item in result!['items'] as List) {
        if (item is Map && item['itemId'] is String) {
          saved[item['itemId'] as String] = item;
        }
      }
    }
    return Container(
      key: ValueKey('assistant-plan-${operation.callId}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: failed
              ? AppColors.error
              : AppColors.primary.withValues(alpha: .3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 10),
                child: Icon(
                  Icons.event_note_outlined,
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: Text(
                  '${operation.input['title'] ?? '任务计划'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${items.length} 项任务 · $totalMinutes 分钟',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: failed ? AppColors.errorSoft : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: failed ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            _item(context, items[index], index, editable, saved),
          ],
          if (operation.planChecking)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (operation.planPreviewError != null || failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                operation.planPreviewError ??
                    '${result?['message'] ?? operation.output ?? '计划未保存，请重新检查'}',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (operation.planPreviewError != null && _waiting)
            TextButton.icon(
              onPressed: operation.planChecking
                  ? null
                  : () => controller.refreshPlanPreview(operation.callId),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重新检查安排'),
            ),
          if (failed)
            TextButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () => controller.send(
                      '请重新查询相关任务与排期，核对并调整下面这份未保存的计划，继续使用计划卡提出，不直接重放旧操作。\n${jsonEncode(operation.input)}',
                    ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重新核对这份计划'),
            ),
          if (_waiting) ...[
            const SizedBox(height: 16),
            Text(
              '整份计划一起保存。时间冲突或任务已变化时，整份计划都不会保存。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final confirm = FilledButton.icon(
                  key: ValueKey('confirm-plan-${operation.callId}'),
                  onPressed:
                      editable &&
                          operation.planPreviewReady &&
                          operation.planConflicts.isEmpty
                      ? () {
                          final error = controller.confirmProposal(
                            operation.callId,
                          );
                          if (error != null) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(error)));
                          }
                        }
                      : null,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text('确认保存 ${items.length} 项'),
                );
                final cancel = TextButton(
                  onPressed: () => controller.cancelProposal(operation.callId),
                  child: const Text('取消计划'),
                );
                return constraints.maxWidth < 400
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [confirm, cancel],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [cancel, const SizedBox(width: 8), confirm],
                      );
              },
            ),
          ],
          if (operation.status == AssistantOperationStatus.unknown) ...[
            const SizedBox(height: 12),
            const Text('保存结果尚未确认，请先核对，避免重复创建任务。'),
            TextButton.icon(
              onPressed: () =>
                  controller.resolveUnknownOutcome(operation.callId),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('核对真实保存结果'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    Map<String, Object?> item,
    int index,
    bool editable,
    Map<String, Map> saved,
  ) {
    final id = '${item['itemId'] ?? index}';
    final isNew = item['kind'] == 'CREATE';
    final messages = operation.planConflicts.where(
      (conflict) => conflict.itemId == id,
    );
    final before = operation.planOriginals[id];
    final oldStart = before?.schedule.fixedStartAt;
    final oldLocal = oldStart == null
        ? null
        : tz.TZDateTime.from(
            oldStart,
            tz.getLocation(before!.schedule.timeZone),
          );
    final objective = item['objective'] is String
        ? item['objective'] as String
        : null;
    final time = Text(
      _timeLabel(item),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${item['title'] ?? before?.mission.title ?? '任务'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (objective != null && objective != item['title']) ...[
          const SizedBox(height: 4),
          Text(objective, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: messages.isEmpty
              ? AppColors.hairline
              : AppColors.warning.withValues(alpha: .4),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 2,
            children: [
              Text(
                '${item['scheduledDate']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isNew ? '新建' : '改期',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.primary),
                  ),
                  if (_waiting) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      key: ValueKey('edit-plan-$id'),
                      tooltip: '修改第 ${index + 1} 项安排',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: editable ? () => _edit(context, item) : null,
                    ),
                    IconButton(
                      key: ValueKey('remove-plan-$id'),
                      tooltip:
                          AssistantPlanService.rows(operation.input).length > 1
                          ? '移除这项安排'
                          : '最后一项可通过取消计划移除',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed:
                          editable &&
                              AssistantPlanService.rows(
                                    operation.input,
                                  ).length >
                                  1
                          ? () => _remove(context, item)
                          : null,
                    ),
                  ],
                ],
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= 600 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 18
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 220, child: time),
                      const SizedBox(width: 16),
                      Expanded(child: content),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [time, const SizedBox(height: 6), content],
                  ),
          ),
          if (before != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '原安排：${before.schedule.scheduledDate} · ${oldLocal == null ? '自选时间' : '${_two(oldLocal.hour)}:${_two(oldLocal.minute)}'} · ${before.schedule.plannedDurationMinutes} 分钟',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          if (item['steps'] is List && (item['steps'] as List).isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              minTileHeight: 36,
              title: Text(
                '行动步骤',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              children: [
                for (final step in item['steps'] as List)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $step'),
                    ),
                  ),
              ],
            ),
          if (item['notes'] is String && (item['notes'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${item['notes']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_waiting)
            for (final conflict in messages)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  conflict.message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                ),
              ),
          if (saved[id]?['missionId'] is String)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onOpenReference(
                  'mission',
                  saved[id]!['missionId'] as String,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('打开任务'),
              ),
            ),
        ],
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _timeLabel(Map<String, Object?> item) {
    final minutes = int.tryParse('${item['plannedMinutes']}') ?? 0;
    final time = item['fixedStartLocal'] is String
        ? item['fixedStartLocal'] as String
        : null;
    if (item['timePolicy'] != 'FIXED' || time == null) {
      return '自选时间 · $minutes 分钟';
    }
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      return '开始时间需要修正';
    }
    final parts = time.split(':').map(int.parse).toList();
    final end = parts[0] * 60 + parts[1] + minutes;
    return '$time–${_two(end ~/ 60 % 24)}:${_two(end % 60)}${end >= 1440 ? '（次日）' : ''} · $minutes 分钟';
  }
}

class _PlanItemEditor extends StatefulWidget {
  const _PlanItemEditor({required this.row, required this.onSave});
  final Map<String, Object?> row;
  final Future<String?> Function(Map<String, Object?>) onSave;
  @override
  State<_PlanItemEditor> createState() => _PlanItemEditorState();
}

class _PlanItemEditorState extends State<_PlanItemEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.row['title'] as String? ?? '',
  );
  late final _objective = TextEditingController(
    text: widget.row['objective'] as String? ?? '',
  );
  late final _date = TextEditingController(
    text: widget.row['scheduledDate'] as String,
  );
  late final _minutes = TextEditingController(
    text: '${widget.row['plannedMinutes']}',
  );
  late final _time = TextEditingController(
    text: widget.row['fixedStartLocal'] as String? ?? '09:00',
  );
  late var _fixed = widget.row['timePolicy'] == 'FIXED';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_title, _objective, _date, _minutes, _time]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = {
      ...widget.row,
      'scheduledDate': _date.text.trim(),
      'plannedMinutes': int.parse(_minutes.text),
      'timePolicy': _fixed ? 'FIXED' : 'FLEXIBLE',
    };
    if (widget.row['kind'] == 'CREATE') {
      input['title'] = _title.text.trim();
      if (_objective.text.trim().isNotEmpty) {
        input['objective'] = _objective.text.trim();
      } else {
        input.remove('objective');
      }
    }
    if (_fixed) {
      input['fixedStartLocal'] = _time.text.trim();
    } else {
      input.remove('fixedStartLocal');
    }
    final error = await widget.onSave(input);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('修改安排', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                enabled: !_saving && widget.row['kind'] == 'CREATE',
                decoration: const InputDecoration(labelText: '任务名称'),
                validator: (value) => value!.trim().isEmpty ? '请填写名称' : null,
              ),
              if (widget.row['kind'] == 'CREATE') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _objective,
                  enabled: !_saving,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '具体目标（可选）'),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _date,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: '计划日期',
                  hintText: 'YYYY-MM-DD',
                  suffixIcon: IconButton(
                    tooltip: '选择日期',
                    icon: const Icon(Icons.calendar_today_outlined, size: 20),
                    onPressed: _saving
                        ? null
                        : () async {
                            final initial =
                                DateTime.tryParse(_date.text) ?? DateTime.now();
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(9999, 12, 31),
                            );
                            if (selected != null && mounted) {
                              _date.text =
                                  '${selected.year.toString().padLeft(4, '0')}-${AssistantPlanCard._two(selected.month)}-${AssistantPlanCard._two(selected.day)}';
                            }
                          },
                  ),
                ),
                validator: (value) {
                  try {
                    validateScheduledDate(value!.trim());
                    return null;
                  } on ArgumentError {
                    return '请输入有效的 YYYY-MM-DD 日期';
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minutes,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '计划分钟数'),
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  return number == null || number < 1 || number > 1440
                      ? '请填写 1–1440 分钟'
                      : null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('固定开始时间'),
                subtitle: const Text('关闭后可在当天自行选择时间'),
                value: _fixed,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _fixed = value),
              ),
              if (_fixed)
                TextFormField(
                  controller: _time,
                  enabled: !_saving,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: '开始时间',
                    hintText: 'HH:mm',
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^(?:[01]\d|2[0-3]):[0-5]\d$',
                      ).hasMatch(value?.trim() ?? '')
                      ? null
                      : '请填写 24 小时制时间，例如 09:30',
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '检查安排中…' : '更新预览'),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('返回计划'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
