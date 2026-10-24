import '../../../domain/entities/mission_phase.dart';

/// 页面、列表和读屏使用同一套阶段文案；这些文字不作为数据库事实保存。
String phaseLabel(MissionPhase phase) => switch (phase) {
  MissionPhase.notStarted => '待开始',
  MissionPhase.running => '执行中',
  MissionPhase.paused => '已暂停',
  MissionPhase.closed => '已结束',
  MissionPhase.cancelled => '已取消',
  MissionPhase.evidencePending => '待补材料',
};

String missionOpenLabel(MissionPhase phase) => switch (phase) {
  MissionPhase.running || MissionPhase.paused => '进入执行任务',
  MissionPhase.closed => '查看任务详情',
  MissionPhase.cancelled => '查看取消记录',
  MissionPhase.evidencePending => '整理材料',
  MissionPhase.notStarted => '查看任务详情',
};
