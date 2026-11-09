import 'package:flutter/material.dart';

import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../widgets/adaptive_sheet.dart';
import '../shared/mission_phase_display.dart';
import 'timetable_layout.dart';

/// 日时间轴和整周课表共用真实冲突明细，包括被筛选隐藏的另一项任务。
Future<void> showTimetableConflicts(
  BuildContext context, {
  required List<({DateTime day, TimetableDay layout})> days,
  required ValueChanged<String> onOpen,
  TimetableSlot? selected,
}) async {
  final target = await showAdaptiveSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: ListView(
          padding: const EdgeInsets.all(AppLayout.spaceXxl),
          children: [
            Text('计划时间冲突', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppLayout.spaceSm),
            const Text('以下计划时段重叠，点击任务查看或调整。'),
            for (final entry in days)
              if (entry.layout.conflicts.isNotEmpty) ...[
                const SizedBox(height: AppLayout.spaceLg),
                Text(
                  timetableDateKey(entry.day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final conflict
                    in selected?.conflicts ?? entry.layout.conflicts) ...[
                  const SizedBox(height: AppLayout.spaceMd),
                  Text(
                    '${timetableClock(conflict.start)}–${timetableClock(conflict.end)}'
                    ' · 重叠 ${(conflict.end - conflict.start).ceil()} 分钟',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                  for (final slot in [conflict.first, conflict.second])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(slot.detail.mission.title),
                      subtitle: Text(
                        '${slot.timeLabel} · ${phaseLabel(slot.detail.phase)}'
                        '${entry.layout.slots.any((item) => item.id == slot.id) ? '' : ' · 已被筛选隐藏'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, slot.id),
                    ),
                  const Divider(),
                ],
              ],
          ],
        ),
      ),
    ),
  );
  if (target != null && context.mounted) onOpen(target);
}
