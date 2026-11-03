import 'mission_detail.dart';

enum MissionMaintenanceAction { cancel, delete, reset }

/// 用户看到的操作范围及固定快照；提交时仓储重新核对整个范围。
class MissionMaintenanceProposal {
  const MissionMaintenanceProposal({
    required this.action,
    required this.items,
    required this.fingerprint,
    this.ids,
    this.goalId,
    this.beforeDate,
    this.phase,
  });
  final MissionMaintenanceAction action;
  final List<MissionDetail> items;
  final String fingerprint;
  final List<String>? ids;
  final String? goalId;
  final String? beforeDate;
  final String? phase;
}
