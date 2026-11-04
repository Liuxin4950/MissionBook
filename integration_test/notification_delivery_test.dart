import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/notifications/app_notification_service.dart';
import 'package:mission_book/application/notifications/execution_reminder.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/notifications/android_notification_dispatcher.dart';
import 'package:mission_book/data/notifications/reminder_store.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

/// Android 通知栏验收：隔离事实和偏好，真实系统通知；清空由外部 ADB 驱动。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('清空其他通知后四种任务通知仍保留，结束后正常撤销', (tester) async {
    const controlId = 860001;
    const reuseId = 860002;
    const appearance = MethodChannel('mission_book/notification_appearance');
    final database = AppDatabase(executor: NativeDatabase.memory());
    var now = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
    final missions = MissionService(
      DriftMissionRepository(database, clock: () => now),
      clock: () => now,
    );
    final temporary = await (await getTemporaryDirectory()).createTemp(
      'notification-audit-',
    );
    final file = File('${temporary.path}/reminders.json');
    // 独立编号区间，避免覆盖模拟器中原有应用通知。
    await file.writeAsString(jsonEncode({'nextNotificationId': 850000}));
    final store = ReminderStore(file);
    await store.load();
    await store.setReminderLeadMinutes(15);
    timezone.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_mission'),
      ),
    );
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    if (await android.areNotificationsEnabled() != true) {
      debugPrint('NOTIFICATION_AUDIT_PERMISSION');
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (await android.areNotificationsEnabled() != true &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(
        await android.areNotificationsEnabled(),
        isTrue,
        reason: '先由测试驱动授予模拟器通知权限',
      );
    }
    final dispatcher = AndroidNotificationDispatcher(
      plugin: plugin,
      exactAlarmsAllowed: false,
    );
    final notifications = AppNotificationService(
      missions: missions,
      store: store,
      dispatcher: dispatcher,
      now: () => now,
    );
    addTearDown(() async {
      await notifications.dispose();
      for (final id in {...store.notificationIds.values, controlId, reuseId}) {
        await dispatcher.cancel(id);
      }
      await missions.dispose();
      await database.close();
      await temporary.delete(recursive: true);
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('通知栏验收中'))),
      ),
    );

    Future<String> create(
      String title, {
      DateTime? start,
      int minutes = 30,
    }) async {
      final request = missions.prepareCreation(
        title: title,
        scheduledDate: now.toIso8601String().substring(0, 10),
        timeZone: 'UTC',
        plannedDurationMinutes: minutes,
        timePolicy: start == null ? TimePolicy.flexible : TimePolicy.fixed,
        fixedStartAt: start,
      );
      await missions.createPrepared(request);
      return request.mission.id;
    }

    Future<void> execute(String id, ExecutionEventType type) async {
      final detail = (await missions.findDetail(missionId: id))!;
      await missions.execute(
        missions.prepareExecution(detail: detail, type: type),
      );
    }

    final stoppedId = await create('到点待确认测试', start: now, minutes: 1);
    await missions.reconcileScheduledMissions();
    now = now.add(const Duration(minutes: 1));
    await missions.reconcileScheduledMissions();
    expect(
      (await missions.findDetail(missionId: stoppedId))!.phase,
      MissionPhase.reportPending,
    );
    final pausedId = await create('已暂停测试');
    await execute(pausedId, ExecutionEventType.start);
    now = now.add(const Duration(seconds: 10));
    await execute(pausedId, ExecutionEventType.pause);
    now = DateTime.now().toUtc();
    final runningId = await create('正在计时测试');
    await execute(runningId, ExecutionEventType.start);
    final upcomingId = await create(
      '课前常驻测试',
      start: now.add(const Duration(minutes: 10)),
    );
    final futureId = await create(
      '未来课程调度测试',
      start: now.add(const Duration(hours: 1)),
    );
    await notifications.refresh();
    final futureNotificationId = store.notificationIds.entries
        .singleWhere(
          (entry) =>
              entry.key.startsWith('mission-$futureId-startReminder-') &&
              !entry.key.endsWith('-waiting'),
        )
        .value;
    expect(
      (await plugin.pendingNotificationRequests()).any(
        (item) => item.id == futureNotificationId,
      ),
      isTrue,
    );
    final pinnedIds = {
      store.notificationIds['mission-$stoppedId-execution']!,
      store.notificationIds['mission-$pausedId-execution']!,
      store.notificationIds['mission-$runningId-execution']!,
      store.notificationIds.entries
          .singleWhere(
            (entry) =>
                entry.key.startsWith('mission-$upcomingId-startReminder-') &&
                !entry.key.endsWith('-waiting'),
          )
          .value,
    };

    // 同一编号可合法重新呈现；旧代次、取消后的迟到装饰均不能复活通知。
    final running = (await missions.findDetail(missionId: runningId))!;
    await dispatcher.show(executionReminder(running, reuseId, now: now));
    final oldToken = await appearance.invokeMethod<int>('prepare', {
      'id': reuseId,
    });
    await dispatcher.cancel(reuseId);
    await appearance.invokeMethod<void>('decorateExecution', {
      'id': reuseId,
      'token': oldToken,
    });
    expect(
      (await plugin.getActiveNotifications()).any((item) => item.id == reuseId),
      isFalse,
    );
    await dispatcher.show(executionReminder(running, reuseId, now: now));
    await appearance.invokeMethod<void>('decorateExecution', {
      'id': reuseId,
      'token': oldToken,
    });
    expect(
      (await plugin.getActiveNotifications()).any((item) => item.id == reuseId),
      isTrue,
    );
    await dispatcher.cancel(reuseId);

    await plugin.show(
      id: controlId,
      title: '可清除对照通知',
      body: '仅用于验证一键清空确实执行',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'notification_audit',
          '通知验收对照',
          icon: 'ic_stat_mission',
          autoCancel: true,
        ),
      ),
    );
    final before = (await plugin.getActiveNotifications())
        .map((item) => item.id)
        .toSet();
    expect(before.containsAll({...pinnedIds, controlId}), isTrue);
    debugPrint('NOTIFICATION_AUDIT_READY');
    // 外部驱动观察系统通知栏并点击“全部清除”，真实验证 Android 行为。
    await Future<void>.delayed(const Duration(seconds: 60));
    final after = (await plugin.getActiveNotifications())
        .map((item) => item.id)
        .toSet();
    expect(after.containsAll(pinnedIds), isTrue, reason: '课前、运行、暂停、到点待确认均应保留');
    expect(after.contains(controlId), isFalse, reason: '对照通知必须消失，证明实际执行过一键清空');
    final afterClearDetails = await missions.findDetail(missionId: runningId);
    expect(afterClearDetails!.phase, MissionPhase.running);
    expect(
      afterClearDetails.lastSequence,
      running.lastSequence,
      reason: '清空通知不能写任务事实',
    );
    final futureStillScheduled = (await plugin.pendingNotificationRequests())
        .any((item) => item.id == futureNotificationId);
    expect(futureStillScheduled, isTrue, reason: '清空通知不应移除尚未触发的课程提醒');

    // 用户取消课程后通知应真正撤销，常驻不能阻断业务清理。
    await missions.cancel(missionId: upcomingId);
    now = DateTime.now().toUtc();
    await missions.execute(
      missions.prepareExecution(
        detail: (await missions.findDetail(missionId: runningId))!,
        type: ExecutionEventType.end,
        report: UserReportedResult.completed,
      ),
    );
    await notifications.refresh();
    final finalIds = (await plugin.getActiveNotifications())
        .map((item) => item.id)
        .toSet();
    final upcomingNotification = pinnedIds.difference({
      store.notificationIds['mission-$stoppedId-execution']!,
      store.notificationIds['mission-$pausedId-execution']!,
      store.notificationIds['mission-$runningId-execution']!,
    }).single;
    expect(finalIds.contains(upcomingNotification), isFalse);
    final runningNotification =
        store.notificationIds['mission-$runningId-execution']!;
    expect(
      finalIds.contains(runningNotification),
      isFalse,
      reason: '用户提交 END 后移除执行通知',
    );
    final capabilities = await const MethodChannel(
      'mission_book/device',
    ).invokeMapMethod<String, dynamic>('capabilities');
    binding.reportData = {
      'pinned_ids': pinnedIds.toList(),
      'before_clear': before.toList(),
      'after_clear': after.toList(),
      'control_removed': !after.contains(controlId),
      'cancelled_course_removed': !finalIds.contains(upcomingNotification),
      'ended_execution_removed': !finalIds.contains(runningNotification),
      'future_course_still_scheduled': futureStillScheduled,
      'stale_decoration_rejected': true,
      'notification_id_reused': true,
      'device_capabilities': capabilities,
    };
  }, skip: !const bool.fromEnvironment('RUN_NOTIFICATION_AUDIT'));
}
