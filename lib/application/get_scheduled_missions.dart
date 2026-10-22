import 'package:timezone/data/latest.dart' as tzdata;

import '../domain/entities/mission_schedule_revision.dart';
import '../domain/entities/scheduled_mission.dart';
import '../domain/repositories/mission_repository.dart';

/// 按计划日期读取一次任务及当前排期，不订阅后续变化。
class GetScheduledMissions {
  GetScheduledMissions(this.repository) {
    // 页面按排期时区显示固定开始时间，也使用上海日历取得默认日期。
    tzdata.initializeTimeZones();
  }

  final MissionRepository repository;

  /// 检查 YYYY-MM-DD 日历日期，返回按仓储约定排序的查询结果。
  ///
  /// 无效输入以 ArgumentError 结束 Future，仓储错误继续向上传递。
  /// 今天页的 _loadMissions 提供所选日期，并等待此 Future 后显示结果。
  Future<List<ScheduledMission>> execute({
    required String scheduledDate,
  }) async {
    validateScheduledDate(scheduledDate);
    // 这里只约束输入；读表和存储类型转换由真实仓储负责。
    final missions = await repository.findScheduledOn(scheduledDate);
    return missions;
  }
}
