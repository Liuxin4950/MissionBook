import 'dart:convert';

import 'package:flutter/material.dart';

import '../../application/assistant/assistant_controller.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/mission.dart';
import 'assistant_plan_card.dart';
import 'assistant_outline_editor.dart';
import '../../application/assistant/assistant_goal_outline.dart';
import '../../core/theme/app_layout.dart';

class AssistantOperationCard extends StatefulWidget {
  const AssistantOperationCard({
    super.key,
    required this.controller,
    required this.operation,
    required this.onOpenReference,
  });

  final AssistantController controller;
  final AssistantOperation operation;
  final void Function(String type, String id) onOpenReference;

  @override
  State<AssistantOperationCard> createState() => _AssistantOperationCardState();
}

class _AssistantOperationCardState extends State<AssistantOperationCard> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final operation = widget.operation;
    if (operation.toolName == 'mission_plan') {
      return AssistantPlanCard(
        controller: widget.controller,
        operation: operation,
        onOpenReference: widget.onOpenReference,
      );
    }
    if (!operation.isWrite) {
      if (operation.status == AssistantOperationStatus.waitingConfirmation) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppLayout.spaceLg),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppLayout.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(operation: operation),
                  const SizedBox(height: AppLayout.spaceSm),
                  const Text('默认权限下，查询应用数据也需要你确认。查询结果会提供给当前模型。'),
                  if (operation.input.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppLayout.spaceSm,
                      ),
                      child: Text(
                        jsonEncode(operation.input),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () =>
                            widget.controller.cancelProposal(operation.callId),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            widget.controller.confirmProposal(operation.callId),
                        child: const Text('允许查询'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return _ReadResultCard(
        operation: operation,
        onOpenReference: widget.onOpenReference,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.spaceLg),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusXl),
          side: BorderSide(
            color: operation.status == AssistantOperationStatus.failed
                ? AppColors.error
                : AppColors.primary.withValues(alpha: .45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppLayout.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(operation: operation),
              const SizedBox(height: AppLayout.spaceMd),
              if (_editing &&
                  operation.status ==
                      AssistantOperationStatus.waitingConfirmation)
                AssistantProposalEditor(
                  operation: operation,
                  onSave: (input) {
                    final error = widget.controller.updateProposal(
                      operation.callId,
                      input,
                    );
                    if (error == null && mounted) {
                      setState(() => _editing = false);
                    }
                    return error;
                  },
                  onCancel: () => setState(() => _editing = false),
                )
              else ...[
                if (const [
                  AssistantOperationStatus.succeeded,
                  AssistantOperationStatus.failed,
                  AssistantOperationStatus.cancelled,
                ].contains(operation.status))
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      operation.missionBefore?.mission.title ??
                          operation.targetTitle ??
                          '操作详情',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    children: _summaryRows(operation),
                  )
                else
                  ..._summaryRows(operation),
                if (operation.toolName == 'mission_complete_history') ...[
                  const SizedBox(height: AppLayout.spaceSm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(
                          Icons.task_alt,
                          size: AppLayout.iconSm,
                        ),
                        label: Text(
                          '${operation.historyMissions.isEmpty ? (_ResultDetails._decode(operation.output)?['completedCount'] ?? 0) : operation.historyMissions.length} 项补记完成',
                        ),
                      ),
                      if (operation.historySkippedCount > 0)
                        Chip(
                          label: Text(
                            '${operation.historySkippedCount} 项保留原记录',
                          ),
                        ),
                    ],
                  ),
                  if (operation.historyMissions.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('查看本批任务'),
                      children: [
                        for (final detail in operation.historyMissions.take(20))
                          ListTile(
                            dense: true,
                            title: Text(detail.mission.title),
                            subtitle: Text(detail.schedule.scheduledDate),
                          ),
                        if (operation.historyMissions.length > 20)
                          Text(
                            '共 ${operation.historyMissions.length} 项，按以上日期范围处理',
                          ),
                      ],
                    ),
                ],
                if (operation.status ==
                    AssistantOperationStatus.waitingConfirmation)
                  _WaitingActions(
                    onEdit: () => setState(() => _editing = true),
                    onCancel: () =>
                        widget.controller.cancelProposal(operation.callId),
                    onConfirm: () {
                      final error = widget.controller.confirmProposal(
                        operation.callId,
                      );
                      if (error != null && mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
                  ),
              ],
              if (operation.status == AssistantOperationStatus.unknown)
                Padding(
                  padding: const EdgeInsets.only(top: AppLayout.spaceMd),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      foregroundColor: AppColors.onPrimary,
                      iconColor: AppColors.onPrimary,
                      backgroundColor: AppColors.primary,
                      disabledForegroundColor: AppColors.onDisabled,
                      disabledBackgroundColor: AppColors.disabled,
                    ),
                    onPressed: () => widget.controller.resolveUnknownOutcome(
                      operation.callId,
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('按真实记录核对结果'),
                  ),
                ),
              if (operation.output != null &&
                  operation.status !=
                      AssistantOperationStatus.waitingConfirmation)
                _ResultDetails(
                  operation: operation,
                  onOpenReference: widget.onOpenReference,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _summaryRows(AssistantOperation operation) {
    final rows = <(String, String)>[];
    final before = operation.missionBefore;
    if (operation.targetTitle != null) {
      rows.add(('原名称', operation.targetTitle!));
    }
    if (before != null) rows.add(('任务', before.mission.title));
    if (before != null &&
        ['mission_reschedule', 'mission_update'].contains(operation.toolName)) {
      rows.add((
        '原安排',
        '${before.schedule.scheduledDate} · ${before.schedule.plannedDurationMinutes} 分钟',
      ));
    }
    final labels = {
      'title': '名称',
      'scheduledDate': '新日期',
      'plannedMinutes': '计划分钟',
      'fixedStartLocal': '开始时间',
      'objective': '具体目标',
      'timePolicy': '时间方式',
      'type': '执行动作',
      'minutes': '增加分钟',
      'reason': '原因',
      'report': '用户报告',
      'description': '说明',
      'why': '为什么',
      'notes': '备注',
      'evidenceDeadlineLocal': '材料截止',
      'beforeDate': '早于日期',
      'statement': '补记依据',
    };
    for (final entry in operation.input.entries) {
      final label = labels[entry.key];
      final value = entry.value;
      if (label != null && value != null && value is! List) {
        final display = switch (entry.key) {
          'timePolicy' => value == 'FIXED' ? '固定时间' : '自选时间',
          'report' => value == 'COMPLETED' ? '已完成' : '未完成',
          'type' => switch (value) {
            'START' => '开始',
            'PAUSE' => '暂停',
            'RESUME' => '继续',
            'EXTEND' => '延长',
            'END' => '结束',
            _ => '$value',
          },
          _ => '$value',
        };
        rows.add((label, display));
      }
    }
    final steps = operation.input['steps'];
    if (steps is List && steps.isNotEmpty) {
      rows.add(('行动步骤', steps.join(' → ')));
    }
    if (operation.toolName == 'mission_cancel') {
      rows.add(('影响', '保留排期和方案；不新增执行或失败事实'));
    }
    if (operation.toolName == 'mission_retry') {
      rows.add(('影响', '创建关联的新尝试，保留原任务的结果、记录及材料要求'));
    }
    if (operation.toolName == 'goal_outline_create') {
      final nodes = AssistantGoalOutline.rows(operation.input);
      final paths = <String, String>{};
      final counts = <String?, int>{};
      for (final node in nodes) {
        final parent = node['parentKey'] as String?;
        final number = counts.update(
          parent,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        final path = parent == null ? '$number' : '${paths[parent]}.$number';
        paths[node['key'] as String] = path;
        rows.add((
          path,
          '${node['title']}${node['description'] == null || node['description'] == '' ? '' : '\n${node['description']}'}',
        ));
      }
      rows.add(('保存范围', '新建1个目标、${nodes.length}个大纲节点；不创建任务或标记掌握'));
    }
    return [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                child: Text(
                  row.$1,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  row.$2,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.operation});
  final AssistantOperation operation;

  @override
  Widget build(BuildContext context) {
    final status = switch (operation.status) {
      AssistantOperationStatus.waitingConfirmation => '待确认',
      AssistantOperationStatus.running => '正在执行',
      AssistantOperationStatus.succeeded => '已完成',
      AssistantOperationStatus.failed => '未能执行',
      AssistantOperationStatus.cancelled => '已取消 · 零写入',
      AssistantOperationStatus.unknown => '需要核对',
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            _toolLabel(operation.toolName),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: AppLayout.spaceMd),
        Text(
          status,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}

class _WaitingActions extends StatelessWidget {
  const _WaitingActions({
    required this.onEdit,
    required this.onCancel,
    required this.onConfirm,
  });
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppLayout.spaceMd),
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(onPressed: onCancel, child: const Text('取消')),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: AppLayout.iconSm),
          label: const Text('修改'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            foregroundColor: AppColors.onPrimary,
            iconColor: AppColors.onPrimary,
            backgroundColor: AppColors.primary,
            disabledForegroundColor: AppColors.onDisabled,
            disabledBackgroundColor: AppColors.disabled,
          ),
          onPressed: onConfirm,
          child: const Text('确认执行'),
        ),
      ],
    ),
  );
}

class _ReadResultCard extends StatelessWidget {
  const _ReadResultCard({
    required this.operation,
    required this.onOpenReference,
  });
  final AssistantOperation operation;
  final void Function(String, String) onOpenReference;

  @override
  Widget build(BuildContext context) {
    final running = operation.status == AssistantOperationStatus.running;
    final failed =
        operation.status == AssistantOperationStatus.failed ||
        operation.error != null;
    final colors = Theme.of(context).colorScheme;
    final label =
        '${running
            ? '正在'
            : failed
            ? '未能'
            : '已'}${_toolLabel(operation.toolName)}';
    return Padding(
      key: ValueKey('assistant-read-${operation.callId}'),
      padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppLayout.spaceMd,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppLayout.spaceMd,
            0,
            AppLayout.spaceMd,
            AppLayout.spaceMd,
          ),
          minTileHeight: AppLayout.touchTargetMin,
          visualDensity: VisualDensity.compact,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  failed ? Icons.error_outline : Icons.check_circle_outline,
                  size: AppLayout.iconSm,
                  color: failed ? colors.error : colors.primary,
                ),
          title: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: failed ? colors.error : colors.onSurfaceVariant,
            ),
          ),
          children: [
            _ResultDetails(
              operation: operation,
              onOpenReference: onOpenReference,
              inlineData: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultDetails extends StatelessWidget {
  const _ResultDetails({
    required this.operation,
    required this.onOpenReference,
    this.inlineData = false,
  });
  final AssistantOperation operation;
  final void Function(String, String) onOpenReference;
  final bool inlineData;

  @override
  Widget build(BuildContext context) {
    final decoded = _decode(operation.output);
    final references = decoded?['references'];
    final message = decoded?['message'] ?? operation.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: AppLayout.spaceSm),
            child: Text(
              '$message'
                  .replaceFirst('Invalid argument(s): ', '')
                  .replaceFirst('Bad state: ', ''),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        if (references is List)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final reference in references)
                if (reference is Map && reference['id'] is String)
                  TextButton.icon(
                    onPressed: () => onOpenReference(
                      '${reference['type'] ?? 'mission'}',
                      '${reference['id']}',
                    ),
                    icon: Icon(
                      reference['type'] == 'goal'
                          ? Icons.track_changes
                          : Icons.task_outlined,
                      size: AppLayout.iconSm,
                    ),
                    label: Text('打开${reference['title'] ?? '记录'}'),
                  ),
            ],
          ),
        if (decoded != null)
          if (inlineData)
            _rawData(context, decoded)
          else
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                '查看返回数据',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              children: [_rawData(context, decoded)],
            ),
      ],
    );
  }

  Widget _rawData(BuildContext context, Map<String, Object?> decoded) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppLayout.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        ),
        child: SelectableText(
          _pretty(decoded),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );

  static Map<String, Object?>? _decode(String? output) {
    if (output == null) return null;
    try {
      final value = jsonDecode(output);
      return value is Map ? Map<String, Object?>.from(value) : null;
    } catch (_) {
      return null;
    }
  }

  static String _pretty(Map<String, Object?> value) {
    final text = const JsonEncoder.withIndent('  ').convert(value);
    return text.length > 6000 ? '${text.substring(0, 6000)}\n… 返回内容已截断' : text;
  }
}

class AssistantProposalEditor extends StatefulWidget {
  const AssistantProposalEditor({
    super.key,
    required this.operation,
    required this.onSave,
    required this.onCancel,
  });
  final AssistantOperation operation;
  final String? Function(Map<String, Object?> input) onSave;
  final VoidCallback onCancel;

  @override
  State<AssistantProposalEditor> createState() =>
      _AssistantProposalEditorState();
}

class _AssistantProposalEditorState extends State<AssistantProposalEditor> {
  late Map<String, Object?> _draft;
  late final Map<String, TextEditingController> _controllers;
  String? _error;
  final _touched = <String>{};

  Set<String> get _editableKeys {
    final tool = widget.operation.toolName;
    return switch (tool) {
      'mission_create' || 'mission_update' => {
        'title',
        'scheduledDate',
        'plannedMinutes',
        'fixedStartLocal',
        'objective',
        'steps',
        'notes',
        'description',
        'why',
      },
      'mission_reschedule' => {
        'scheduledDate',
        'plannedMinutes',
        'fixedStartLocal',
      },
      'mission_retry' => {
        'title',
        'scheduledDate',
        'plannedMinutes',
        'fixedStartLocal',
        'objective',
        'steps',
        'notes',
        if (widget.operation.missionBefore?.mission.verificationPolicy ==
            VerificationPolicy.requiredEvidence)
          'evidenceDeadlineLocal',
      },
      'goal_create' || 'goal_update' => {'title', 'description', 'why'},
      'goal_node_create' || 'goal_node_update' => {'title', 'description'},
      'mission_execute' => {
        if (_draft['type'] == 'EXTEND') 'minutes',
        if (_draft['type'] == 'PAUSE') 'reason',
      },
      'mission_complete_history' => {'statement'},
      _ => {},
    };
  }

  @override
  void initState() {
    super.initState();
    _draft = Map<String, Object?>.of(widget.operation.input);
    _controllers = {
      for (final key in [
        'title',
        'scheduledDate',
        'plannedMinutes',
        'fixedStartLocal',
        'objective',
        'steps',
        'minutes',
        'reason',
        'description',
        'why',
        'notes',
        'evidenceDeadlineLocal',
        'statement',
      ])
        key: TextEditingController(text: _textValue(_draft[key])),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.operation.toolName;
    if (tool == 'goal_outline_create') {
      return AssistantOutlineEditor(
        input: widget.operation.input,
        onSave: widget.onSave,
        onCancel: widget.onCancel,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ([
          'mission_create',
          'mission_update',
          'mission_retry',
          'goal_create',
          'goal_update',
          'goal_node_create',
          'goal_node_update',
        ].contains(tool))
          _field('title', '名称'),
        if ([
          'mission_create',
          'mission_update',
          'mission_reschedule',
          'mission_retry',
        ].contains(tool)) ...[
          _field('scheduledDate', '日期 YYYY-MM-DD'),
          _field('plannedMinutes', '计划分钟数', keyboardType: TextInputType.number),
          _field('fixedStartLocal', '固定开始 HH:mm（留空为自选）'),
        ],
        if (tool == 'mission_create' ||
            tool == 'mission_update' ||
            tool == 'mission_retry') ...[
          _field('objective', '具体目标'),
          _field('steps', '行动步骤，每行一步', maxLines: 4),
          _field('notes', '备注（可留空）', maxLines: 3),
        ],
        if (tool == 'mission_retry' &&
            widget.operation.missionBefore?.mission.verificationPolicy ==
                VerificationPolicy.requiredEvidence)
          _field('evidenceDeadlineLocal', '新材料截止 YYYY-MM-DD HH:mm'),
        if (tool == 'mission_reschedule' || tool == 'mission_update')
          _choice('timePolicy', '时间方式', const ['FLEXIBLE', 'FIXED']),
        if (tool == 'mission_complete_history')
          _field('statement', '补记依据', maxLines: 3),
        if (tool == 'mission_execute') ...[
          _choice('type', '执行动作', const [
            'START',
            'PAUSE',
            'RESUME',
            'EXTEND',
            'END',
          ]),
          if (_draft['type'] == 'EXTEND')
            _field('minutes', '增加分钟数', keyboardType: TextInputType.number),
          if (_draft['type'] == 'PAUSE') _field('reason', '暂停原因（可留空）'),
          if (_draft['type'] == 'END') ...[
            _choice('report', '用户报告结果', const ['COMPLETED', 'NOT_COMPLETED']),
            if (widget.operation.missionBefore?.mission.verificationPolicy ==
                    VerificationPolicy.optionalEvidence &&
                _draft['report'] == 'COMPLETED')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('稍后提交可选材料'),
                value: _draft['submitOptionalEvidence'] == true,
                onChanged: (value) =>
                    setState(() => _draft['submitOptionalEvidence'] = value),
              ),
          ],
        ],
        if ([
          'goal_create',
          'goal_update',
          'goal_node_create',
          'goal_node_update',
          'mission_create',
          'mission_update',
        ].contains(tool))
          _field('description', '说明（可留空）'),
        if ([
          'goal_create',
          'goal_update',
          'mission_create',
          'mission_update',
        ].contains(tool))
          _field('why', '为什么（可留空）'),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppLayout.spaceSm),
            child: Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: AppLayout.spaceMd),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(onPressed: widget.onCancel, child: const Text('取消修改')),
              FilledButton(
                style: FilledButton.styleFrom(
                  foregroundColor: AppColors.onPrimary,
                  iconColor: AppColors.onPrimary,
                  backgroundColor: AppColors.primary,
                  disabledForegroundColor: AppColors.onDisabled,
                  disabledBackgroundColor: AppColors.disabled,
                ),
                onPressed: _save,
                child: const Text('保存提案'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(
    String key,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppLayout.spaceMd),
    child: TextField(
      controller: _controllers[key],
      onChanged: (_) {
        _touched.add(key);
      },
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _choice(String key, String label, List<String> values) => Padding(
    padding: const EdgeInsets.only(bottom: AppLayout.spaceMd),
    child: DropdownButtonFormField<String>(
      initialValue: values.contains(_draft[key]) ? _draft[key] as String : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final value in values)
          DropdownMenuItem(value: value, child: Text(value)),
      ],
      onChanged: (value) => setState(() => _draft[key] = value),
    ),
  );

  void _save() {
    for (final key in _editableKeys) {
      if (!_draft.containsKey(key) && !_touched.contains(key)) continue;
      final text = _controllers[key]!.text.trim();
      if (key == 'plannedMinutes' || key == 'minutes') {
        final value = int.tryParse(text);
        if (value == null || value <= 0) {
          setState(() => _error = '分钟数必须是正整数');
          return;
        }
        _draft[key] = value;
      } else if (key == 'steps') {
        _draft[key] = text
            .split('\n')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } else if (key == 'fixedStartLocal' && text.isEmpty) {
        _draft.remove(key);
      } else {
        _draft[key] = text;
      }
    }
    if ([
          'mission_reschedule',
          'mission_update',
        ].contains(widget.operation.toolName) &&
        _touched.contains('fixedStartLocal') &&
        _controllers['fixedStartLocal']!.text.trim().isEmpty) {
      _draft['timePolicy'] = 'FLEXIBLE';
    }
    if (_draft['timePolicy'] == 'FLEXIBLE') _draft.remove('fixedStartLocal');
    if (widget.operation.toolName == 'mission_execute') {
      if (_draft['type'] != 'EXTEND') _draft.remove('minutes');
      if (_draft['type'] != 'PAUSE') _draft.remove('reason');
      if (_draft['type'] != 'END') {
        _draft.remove('report');
        _draft.remove('submitOptionalEvidence');
        _draft.remove('userReasonCategory');
        _draft.remove('userReasonText');
      } else if (_draft['report'] != 'COMPLETED' ||
          widget.operation.missionBefore?.mission.verificationPolicy !=
              VerificationPolicy.optionalEvidence) {
        _draft.remove('submitOptionalEvidence');
      }
    }

    final error = widget.onSave(_draft);
    if (error != null) setState(() => _error = error);
  }

  static String _textValue(Object? value) {
    if (value == null) return '';
    if (value is List) return value.join('\n');
    return '$value';
  }
}

String _toolLabel(String name) => switch (name) {
  'mission_complete_history' => '批量补记历史完成',
  'goal_outline_create' => '创建目标与分层大纲',
  'mission_retry' => '安排新的尝试',
  'schedule_query' => '查看日期安排',
  'mission_query' => '读取任务详情',
  'goal_list' => '查看目标列表',
  'goal_query' => '读取目标与节点',
  'mission_create' => '创建任务',
  'mission_reschedule' => '调整任务安排',
  'mission_update' => '修改任务',
  'goal_update' => '修改目标',
  'goal_node_update' => '修改节点',
  'goal_node_query' => '读取节点',
  'mission_search' => '搜索任务',
  'mission_content' => '读取任务片段',
  'mission_records' => '查看任务记录',
  'evidence_content' => '读取材料正文',
  'mission_execute' => '提交执行动作',
  'mission_cancel' => '取消任务',
  'goal_create' => '创建目标',
  'goal_node_create' => '创建目标节点',
  _ => name,
};
