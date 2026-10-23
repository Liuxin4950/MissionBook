import 'mission.dart';
import 'mission_schedule_revision.dart';

/// 【查询组合】任务＋当前排期，供日期列表读取。
///
/// 仓储查询 missions 与 mission_schedule_revisions 后，组合两个已有业务实体。
/// 它没有对应的独立数据库表，不额外保存一份任务；也不包含 Drift 行类型。
class ScheduledMission {
  const ScheduledMission({required this.mission, required this.schedule});

  final Mission mission;
  final MissionScheduleRevision schedule;
}
