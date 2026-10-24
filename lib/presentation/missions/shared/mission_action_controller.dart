import 'package:flutter/foundation.dart';

import '../../../application/missions/mission_service.dart';
import '../../../domain/entities/execution_command.dart';
import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';

/// 页面共用的动作提交器。只管理等待、重试和查询结果，不另存一份任务阶段。
/// 页面跳转必须等 execute 返回 true；保存失败不能提前进入下一页。
class MissionActionController extends ChangeNotifier {
  MissionActionController({required this.detail, required this.service});

  MissionDetail detail;
  final MissionService service;
  bool busy = false;
  bool stale = false;
  String? error;
  ExecutionCommand? pending;
  MissionDetail? conflict;
  bool _disposed = false;

  bool get canAct => !busy && !stale && pending == null;
  bool get locked => busy || pending != null;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  ExecutionCommand prepare(
    ExecutionEventType type, {
    int? minutes,
    String? reason,
  }) => service.prepareExecution(
    detail: detail,
    type: type,
    minutes: minutes,
    reason: reason,
  );

  Future<bool> execute(ExecutionCommand command) async {
    if (busy) return false;
    pending = command;
    busy = true;
    error = null;
    conflict = null;
    _changed();
    try {
      await service.execute(command);
      // 当前操作页自己重读。服务的广播还会让其他页面各自查询所需的数据；
      // 两者共用数据库事实，不是把本页的 detail 直接复制给其他页面。
      final latest = await service.findDetail(missionId: detail.mission.id);
      if (latest == null) throw const ExecutionConflict('任务不存在，请返回列表');
      detail = latest;
      pending = null;
      stale = false;
      return true;
    } on ExecutionConflict catch (failure) {
      pending = null;
      stale = true;
      error = failure.message;
      try {
        final active = await service.findActive();
        for (final other in active) {
          if (other.mission.id != detail.mission.id &&
              other.phase == MissionPhase.running) {
            conflict = other;
            break;
          }
        }
      } catch (_) {
        // 附加查询失败不覆盖原来的动作冲突。
      }
    } on ArgumentError catch (failure) {
      pending = null;
      error = '${failure.message}';
    } catch (failure, stack) {
      debugPrint('执行动作失败：$failure\n$stack');
      // 可能已提交但响应丢失。保留原编号，重试不会再延长一次或重复结束。
      error = '保存未确认，请重试原操作，或重新读取状态；输入已保留。';
    } finally {
      busy = false;
      _changed();
    }
    return false;
  }

  Future<bool> refresh() async {
    if (busy) return false;
    busy = true;
    _changed();
    try {
      final latest = await service.findDetail(missionId: detail.mission.id);
      if (latest == null) throw StateError('任务不存在');
      detail = latest;
      pending = null;
      stale = false;
      conflict = null;
      error = null;
      return true;
    } catch (_) {
      error = '读取最新状态失败，请重试';
    } finally {
      busy = false;
      _changed();
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
