import 'mission_detail.dart';

/// 用户明确补报历史任务完成；固定预览中的任务集合，提交时整批核对。
class HistoricalCompletion {
  HistoricalCompletion({
    required this.id,
    required this.goalId,
    required this.beforeDate,
    required this.statement,
    required List<MissionDetail> originals,
    required List<MissionDetail> excluded,
  }) : originals = List.unmodifiable(originals),
       excluded = List.unmodifiable(excluded);

  final String id;
  final String goalId;
  final String beforeDate; // 不含这一天。
  final String statement; // 用户的补记依据，随事件保存。
  final List<MissionDetail> originals;

  /// 预览时不符合补记条件的同范围任务，提交时也必须重新核对。
  final List<MissionDetail> excluded;
}
