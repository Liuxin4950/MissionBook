import 'package:flutter/material.dart';

import '../../../domain/entities/mission_phase.dart';
import 'mission_phase_display.dart';
import '../../../core/theme/app_layout.dart';

/// 列表与当前任务栏共用的阶段标记；固定图标盒，行高仍随文字自然增加。
class MissionPhaseIcon extends StatelessWidget {
  const MissionPhaseIcon({super.key, required this.phase});

  final MissionPhase phase;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (phase) {
      MissionPhase.notStarted => Icons.radio_button_unchecked,
      MissionPhase.running => Icons.play_arrow_rounded,
      MissionPhase.paused => Icons.pause_rounded,
      MissionPhase.reportPending => Icons.fact_check_outlined,
      MissionPhase.closed => Icons.check_rounded,
      MissionPhase.cancelled => Icons.block_outlined,
      MissionPhase.evidencePending => Icons.upload_file_outlined,
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: phase == MissionPhase.running
            ? colors.secondaryContainer
            : colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
      ),
      child: Icon(
        icon,
        size: AppLayout.iconLg,
        color: colors.primary,
        semanticLabel: phaseLabel(phase),
      ),
    );
  }
}
