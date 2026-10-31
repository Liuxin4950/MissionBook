import '../../widgets/app_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/mission.dart';
import 'mission_schedule_fields.dart';
import '../../../core/theme/app_layout.dart';

/// 任务材料要求输入区。只管理日历展开；草稿值由父页面持有并统一保存。
class MissionEvidenceFields extends StatefulWidget {
  const MissionEvidenceFields({
    super.key,
    required this.policy, // 父页面持有的材料策略草稿。
    required this.criteriaController, // 材料要求正文，由父页面读取与释放。
    required this.deadlineDate, // 当前截止年月日；实际保存时再结合时区和时分。
    required this.suggestedDate, // 尚未选择截止日期时，日历定位到任务排期日。
    required this.hourController,
    required this.minuteController,
    required this.timeZone, // 沿用任务排期时区，不使用设备时区猜测截止。
    required this.enabled, // 保存或关闭期间禁止继续改草稿。
    required this.onPolicyChanged, // 将策略选择交回父页面，不在本组件写库。
    required this.onDateChanged,
  });

  final VerificationPolicy policy;
  final TextEditingController criteriaController;
  final DateTime? deadlineDate;
  final DateTime suggestedDate;
  final TextEditingController hourController;
  final TextEditingController minuteController;
  final String timeZone;
  final bool enabled;
  final ValueChanged<VerificationPolicy> onPolicyChanged;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<MissionEvidenceFields> createState() => _MissionEvidenceFieldsState();
}

class _MissionEvidenceFieldsState extends State<MissionEvidenceFields> {
  bool _calendarExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requiredEvidence =
        widget.policy == VerificationPolicy.requiredEvidence;
    final date = widget.deadlineDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('完成后的材料', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppLayout.spaceMd),
        // Wrap 允许窄屏或大字体换行，不挤压三个选项的触控范围。
        Wrap(
          spacing: AppLayout.spaceSm,
          runSpacing: AppLayout.spaceSm,
          children: [
            _policyChip(VerificationPolicy.optionalEvidence, '可选提交'),
            _policyChip(VerificationPolicy.requiredEvidence, '必须提交'),
            _policyChip(VerificationPolicy.selfReport, '仅自报'),
          ],
        ),
        const SizedBox(height: AppLayout.spaceMd),
        Text(switch (widget.policy) {
          VerificationPolicy.optionalEvidence => '可以留下文本或图片，也可以不交。结束时由你决定。',
          VerificationPolicy.requiredEvidence => '报告完成后需要提交材料；未提交时，任务项会提示待补。',
          VerificationPolicy.selfReport => '报告完成情况即可结束，不安排材料环节。',
        }, style: theme.textTheme.bodyMedium),
        if (widget.policy != VerificationPolicy.selfReport) ...[
          const SizedBox(height: AppLayout.spaceXl),
          MissionInputLabel(
            label: requiredEvidence ? '材料要求' : '材料说明（选填）',
            isRequired: requiredEvidence,
            child: TextField(
              key: const ValueKey('mission-evidence-criteria'),
              controller: widget.criteriaController,
              enabled: widget.enabled,
              minLines: 2,
              maxLines: 4,
              style: theme.textTheme.bodyLarge,
              decoration: missionInputDecoration(
                context,
                hint: requiredEvidence ? '例如：提交运行结果截图，展示事务回滚' : '需要时再写，留空也可以',
              ),
            ),
          ),
        ],
        if (requiredEvidence) ...[
          const SizedBox(height: AppLayout.spaceXl),
          MissionInputLabel(
            label: '提交截止日期',
            fieldSemantics: false,
            child: OutlinedButton.icon(
              key: const ValueKey('mission-evidence-deadline-date'),
              onPressed: widget.enabled
                  ? () {
                      FocusScope.of(context).unfocus();
                      setState(() => _calendarExpanded = !_calendarExpanded);
                    }
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(missionInputHeight(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppLayout.radiusLg),
                ),
              ),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                date == null
                    ? '选择截止日期'
                    : '${date.year}年${date.month}月${date.day}日',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
          if (_calendarExpanded)
            AppCalendar(
              key: ValueKey(
                'evidence-calendar-${date ?? widget.suggestedDate}',
              ),
              initialDate: date ?? widget.suggestedDate,
              firstDate: DateTime(1),
              lastDate: DateTime(9999, 12, 31),
              onDateChanged: (selected) {
                if (!widget.enabled) return;
                widget.onDateChanged(selected); // 选中的年月日交回父页面草稿。
                setState(() => _calendarExpanded = false);
              },
            ),
          const SizedBox(height: AppLayout.spaceLg),
          Text('截止时间 · 24小时制', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppLayout.spaceSm),
          LayoutBuilder(
            builder: (context, constraints) {
              final hour = _timeField(
                '小时',
                widget.hourController,
                'mission-evidence-deadline-hour',
                '00–23',
              );
              final minute = _timeField(
                '分钟',
                widget.minuteController,
                'mission-evidence-deadline-minute',
                '00–59',
              );
              final scale = MediaQuery.textScalerOf(context).scale(18) / 18;
              if (constraints.maxWidth < 240 * scale) {
                return Column(
                  children: [
                    hour,
                    const SizedBox(height: AppLayout.spaceMd),
                    minute,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: hour),
                  const SizedBox(width: AppLayout.spaceLg),
                  Expanded(child: minute),
                ],
              );
            },
          ),
          const SizedBox(height: AppLayout.spaceSm),
          Text(
            '按任务时区 ${widget.timeZone} 记录，此处是材料截止；固定日程按计划结束时间停止计时。',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }

  Widget _policyChip(VerificationPolicy value, String label) => ChoiceChip(
    key: ValueKey('mission-evidence-policy-${value.name}'),
    label: Text(label),
    selected: widget.policy == value,
    onSelected: widget.enabled ? (_) => widget.onPolicyChanged(value) : null,
  );

  Widget _timeField(
    String label,
    TextEditingController controller,
    String key,
    String hint,
  ) => MissionInputLabel(
    label: label,
    child: TextField(
      key: ValueKey(key),
      controller: controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: missionInputDecoration(context, hint: hint),
    ),
  );
}
