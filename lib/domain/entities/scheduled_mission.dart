import 'mission.dart';
import 'mission_schedule_revision.dart';
import 'mission_phase.dart';
import 'execution_event.dart';

/// 【查询组合】任务、当前排期及执行投影，供日期列表和实时标签读取。
///
/// 仓储查询 missions 与 mission_schedule_revisions 后，组合两个已有业务实体。
/// 它没有对应的独立数据库表，不额外保存一份任务；也不包含 Drift 行类型。
class ScheduledMission {
  const ScheduledMission({
    required this.mission,
    required this.schedule,
    this.phase = MissionPhase.notStarted,
    this.events = const [],
  });

  final Mission mission;
  final MissionScheduleRevision schedule;
  // 查询时从事件计算的投影，不是可写数据库状态。
  final MissionPhase phase;

  /// 同一次查询的执行事实，供列表实时显示 Focus；页面时钟不会写回事件。
  final List<ExecutionEvent> events;
}
