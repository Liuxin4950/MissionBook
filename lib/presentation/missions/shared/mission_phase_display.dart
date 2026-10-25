import '../../../domain/entities/mission_phase.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/failure_record.dart';

/// 页面、列表和读屏使用同一套阶段文案；这些文字不作为数据库事实保存。
String phaseLabel(MissionPhase phase) => switch (phase) {
  MissionPhase.notStarted => '待开始',
  MissionPhase.running => '执行中',
  MissionPhase.paused => '已暂停',
  MissionPhase.closed => '已结束',
  MissionPhase.cancelled => '已取消',
  MissionPhase.evidencePending => '待补材料',
};

/// 从同一次任务查询的正式事实准备材料提示，避免“完成报告”遮盖待补材料。
String evidenceStatusLabel(MissionDetail detail) {
  if (detail.phase == MissionPhase.evidencePending) return '执行已结束 · 待提交材料';
  if (detail.failures.any(
    (failure) => failure.trigger == evidenceDeadlineMissedTrigger,
  )) {
    return '材料超时';
  }
  if (detail.evidence.isNotEmpty) return '材料已提交';
  if (detail.mission.evidenceWaivedAt != null) return '已放弃提交材料';
  return '';
}

String missionOpenLabel(MissionPhase phase) => switch (phase) {
  MissionPhase.running || MissionPhase.paused => '进入执行任务',
  MissionPhase.closed => '查看任务详情',
  MissionPhase.cancelled => '查看取消记录',
  MissionPhase.evidencePending => '整理材料',
  MissionPhase.notStarted => '查看任务详情',
};
