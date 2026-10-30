import '../entities/mission_detail.dart';
import '../entities/execution_event.dart';

abstract interface class MissionMakeupRepository {
  Future<ExecutionEvent> startMakeup(
    MissionDetail original,
    String commandId, {
    DateTime? evidenceDeadlineAt,
  });
}
