import 'mission.dart';
import 'mission_schedule_revision.dart';
import 'execution_plan.dart';

/// 表单保存的一整份创建请求，失败重试时复用编号和内容，避免重复创建任务。
class MissionCreation {
  const MissionCreation({
    required this.mission,
    required this.schedule,
    required this.plan,
  });
  final Mission mission;
  final MissionScheduleRevision schedule;
  final ExecutionPlan plan;
}
