import 'package:flutter/material.dart';

import '../../../application/missions/mission_service.dart';
import '../../../application/errors/user_error_message.dart';
import '../../../domain/entities/mission_maintenance.dart';
import '../../widgets/app_confirm_dialog.dart';

/// 单条和筛选范围操作先固定快照，再展示数量，确认后共用事务提交。
Future<bool> maintainMissions(
  BuildContext context,
  MissionService service,
  MissionMaintenanceAction action,
  List<String> ids,
) async {
  if (ids.isEmpty) return false;
  final label = switch (action) {
    MissionMaintenanceAction.cancel => '取消',
    MissionMaintenanceAction.delete => '永久删除',
    MissionMaintenanceAction.reset => '撤销执行结果',
  };
  try {
    final proposal = await service.prepareMaintenance(action: action, ids: ids);
    if (!context.mounted) return false;
    final accepted = await AppConfirmDialog.show(
      context: context,
      title: '$label ${proposal.items.length} 项任务？',
      message:
          '${proposal.items.take(5).map((d) => d.mission.title).join('、')}${proposal.items.length > 5 ? '等' : ''}。${switch (action) {
            MissionMaintenanceAction.cancel => '仅取消未开始任务，其他任务会跳过。',
            MissionMaintenanceAction.delete => '任务、排期、执行记录和任务材料将永久删除，不能恢复。独立来源记录和聊天保留。',
            MissionMaintenanceAction.reset => '原执行、报告及材料归入撤销历史。任务回到未开始，改为自选时间，原排期仍可追溯；请随后重新安排。',
          }}',
      confirmText: label,
      cancelText: '返回',
    );
    if (!accepted) return false;
    final result = await service.applyMaintenance(proposal);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已$label ${result['count']} 项，跳过 ${(result['skippedIds'] as List).length} 项',
          ),
        ),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userErrorMessage(error, fallback: '操作失败，请刷新后重试')),
        ),
      );
    }
    return false;
  }
}
