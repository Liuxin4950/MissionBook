import 'package:timezone/data/latest.dart' as tzdata;

import '../domain/entities/scheduled_mission.dart';
import '../domain/repositories/mission_repository.dart';

// 今天页的查询入口，与负责写入的 CreateMission 分开。
class GetScheduledMissions {
  GetScheduledMissions(this.repository) {
    // 页面按排期时区显示固定开始时间，也使用上海日历取得默认日期。
    tzdata.initializeTimeZones();
  }

  final MissionRepository repository;

  // 今天页的 _loadMissions 调用本方法：传入所选日期，等待一次查询结果。
  Future<List<ScheduledMission>> execute({required String scheduledDate}) {
    final parsed = DateTime.tryParse(scheduledDate);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(scheduledDate) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != scheduledDate) {
      throw ArgumentError('计划日期必须是有效的 YYYY-MM-DD 日期');
    }
    // 这里只约束输入；读表和存储类型转换由真实仓储负责。
    return repository.findScheduledOn(scheduledDate);
  }
}
