import 'mission_creation.dart';
import 'mission_detail.dart';
import 'mission_schedule_revision.dart';

/// 一份待保存的安排；任务创建与改期在同一事务内一起提交。
class ScheduleProposal {
  ScheduleProposal({
    required this.id,
    required List<ScheduleProposalItem> items,
  }) : items = List.unmodifiable(items) {
    if (id.trim().isEmpty || items.isEmpty || items.length > 20) {
      throw ArgumentError('一份计划需要 1–20 项安排和固定操作编号');
    }
    if (items.map((item) => item.id).toSet().length != items.length ||
        items.map((item) => item.missionId).toSet().length != items.length) {
      throw ArgumentError('一份计划不能重复安排同一个条目或任务');
    }
  }

  final String id; // 同一次保存和结果核对共用的身份。
  final List<ScheduleProposalItem> items;
}

/// 条目保留原任务快照；用户修改预览时不能换成另一个任务。
class ScheduleProposalItem {
  const ScheduleProposalItem.create({
    required this.id,
    required MissionCreation value,
  }) : creation = value,
       original = null,
       _schedule = null;

  const ScheduleProposalItem.reschedule({
    required this.id,
    required MissionDetail before,
    required MissionScheduleRevision schedule,
  }) : original = before,
       _schedule = schedule,
       creation = null;

  final String id; // 预览中稳定的条目编号，删除或排序后仍保持不变。
  final MissionCreation? creation;
  final MissionDetail? original;
  final MissionScheduleRevision? _schedule;

  bool get isCreation => creation != null;
  String get missionId => creation?.mission.id ?? original!.mission.id;
  String get title => creation?.mission.title ?? original!.mission.title;
  MissionScheduleRevision get schedule => creation?.schedule ?? _schedule!;
}

/// 冲突来自实际排期或同份计划，按条目展示；不把建议当成已保存结果。
class ScheduleConflict {
  const ScheduleConflict({
    required this.itemId,
    required this.otherMissionId,
    required this.message,
  });

  final String itemId;
  final String otherMissionId;
  final String message;
}

class ScheduleConflictException implements Exception {
  ScheduleConflictException(this.conflicts);
  final List<ScheduleConflict> conflicts;
  @override
  String toString() => conflicts.map((item) => item.message).join('；');
}
