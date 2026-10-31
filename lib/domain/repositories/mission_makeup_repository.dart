import '../entities/mission_detail.dart';
import '../entities/execution_event.dart';

/// 用户现在补做的原子命令：保留旧排期，改为今天自选并真实 START。
abstract interface class MissionMakeupRepository {
  /// 事务重读快照并校验新截止；重复 commandId 确认原事件，不重复改期。
  Future<ExecutionEvent> startMakeup(
    MissionDetail original,
    String commandId, {
    DateTime? evidenceDeadlineAt,
  });
}
