import 'mission.dart';
import 'mission_schedule_revision.dart';

/// 查询结果的一项：任务基本信息，加上它的当前排期。
/// 这是业务层可读的数据组合，不引用 Drift 的表或数据库行类型。
class ScheduledMission {
  const ScheduledMission({required this.mission, required this.schedule});

  final Mission mission;
  final MissionScheduleRevision schedule;
}
