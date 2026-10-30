import 'mission_schedule_revision.dart';
import 'package:timezone/timezone.dart' as tz;

/// 追加式的用户时间声明；不把自报时间伪装成应用计时。
class UserExecutionReport {
  const UserExecutionReport({
    required this.id,
    required this.missionId,
    required this.occurrenceDate,
    required this.timeZoneId,
    required this.basis,
    this.actualStart,
    this.actualEnd,
    this.supersedesId,
    this.reportedAt,
  });
  final String id, missionId, occurrenceDate, timeZoneId, basis;
  final DateTime? actualStart, actualEnd, reportedAt;
  final String? supersedesId;
  Duration? get duration =>
      actualStart == null ? null : actualEnd!.difference(actualStart!);
  void validate(DateTime now) {
    validateScheduledDate(occurrenceDate);
    final location = tz.getLocation(timeZoneId);
    if (id.trim().isEmpty || missionId.trim().isEmpty || basis.trim().isEmpty) {
      throw ArgumentError('请填写补记依据');
    }
    if ((actualStart == null) != (actualEnd == null) ||
        (actualEnd != null &&
            (actualEnd!.isBefore(actualStart!) || actualEnd!.isAfter(now)))) {
      throw ArgumentError('实际时段无效或尚未发生');
    }
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (occurrenceDate.compareTo(day(tz.TZDateTime.from(now, location))) > 0 ||
        (actualStart != null &&
            day(tz.TZDateTime.from(actualStart!, location)) !=
                occurrenceDate)) {
      throw ArgumentError('发生日期须已到来，并与实际开始时刻一致');
    }
  }
}
