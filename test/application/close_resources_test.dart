import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/lifecycle/close_resources.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/missions/planned_mission_scheduler.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';

void main() {
  test('前面同步和异步释放失败时仍关闭数据库并发送完成信号', () async {
    final order = <String>[];
    final failures = <String>[];
    final success = await closeResources([
      (
        name: 'assistant',
        close: () {
          order.add('assistant');
          throw StateError('failed');
        },
      ),
      (
        name: 'notifications',
        close: () async {
          order.add('notifications');
          throw StateError('failed');
        },
      ),
      (
        name: 'database',
        close: () async {
          order.add('database');
        },
      ),
      (
        name: 'finished',
        close: () {
          order.add('finished');
        },
      ),
    ], onError: (name, error, stack) => failures.add(name));
    expect(success, isFalse);
    expect(order, ['assistant', 'notifications', 'database', 'finished']);
    expect(failures, ['assistant', 'notifications']);
  });
  test('调度关闭与失败刷新重叠时，关闭等待结束并正常完成', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final missions = MissionService(DriftMissionRepository(db));
    final gate = Completer<void>();
    final scheduler = PlannedMissionScheduler(
      missions: missions,
      now: DateTime.now,
      beforeRefresh: () => gate.future,
    );
    final refresh = expectLater(scheduler.refresh(), throwsStateError);
    final closing = scheduler.dispose();
    gate.completeError(StateError('refresh failed'));
    await refresh;
    await closing;
    await scheduler.refresh();
    await missions.dispose();
    await db.close();
  });
}
