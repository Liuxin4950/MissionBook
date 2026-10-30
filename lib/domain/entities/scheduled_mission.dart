import 'mission.dart';
import 'mission_schedule_revision.dart';
import 'mission_phase.dart';
import 'execution_event.dart';

class PlannedMissionPoint {
  const PlannedMissionPoint({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

/// 调度只读取最邻近候选窗口及真实运行占用，不装配所有未来任务的方案和材料。
class PlannedMissionSnapshot {
  const PlannedMissionSnapshot({
    required this.hasRunning,
    required this.candidates,
    this.refreshAfterExpiredCandidate = false,
    this.nextEndAt,
  });
  final bool hasRunning;
  final List<PlannedMissionPoint> candidates;
  final bool refreshAfterExpiredCandidate;
  final DateTime? nextEndAt; // 已开始固定日程的下一次停止时刻，包含加时。
}

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
