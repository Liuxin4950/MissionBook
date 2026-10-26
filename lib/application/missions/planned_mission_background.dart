import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/local/app_database.dart';
import '../../data/notifications/android_notification_dispatcher.dart';
import '../../data/notifications/planned_alarm_bridge.dart';
import '../../data/notifications/reminder_store.dart';
import '../../data/repositories/drift_mission_repository.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/notifications/reminder_request.dart';
import '../notifications/execution_reminder.dart';
import 'mission_service.dart';
import 'planned_mission_scheduler.dart';

/// 无页面的后台入口；读取设置但不改提醒 JSON，避免与前台设置保存互相覆盖。
Future<void> runPlannedMissionBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bridge = PlannedAlarmBridge();
  final database = AppDatabase();
  final missions = MissionService(DriftMissionRepository(database));
  PlannedMissionScheduler? scheduler;
  bool failed = false;
  try {
    final dir = await getApplicationSupportDirectory();
    final store = ReminderStore(File('${dir.path}/reminders.json'));
    await store.load();
    scheduler = PlannedMissionScheduler(
      missions: missions,

      now: DateTime.now,
      beforeRefresh: bridge.beginSync,
      scheduleInSystem: bridge.schedule,
    );
    // 一次唤醒只做一次事务与下一次唤醒安排；不订阅长存的前台变更流。
    await scheduler.refresh();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_mission'),
      ),
    );
    final dispatcher = AndroidNotificationDispatcher(
      plugin: plugin,
      exactAlarmsAllowed: false,
    );
    final details = await missions.findAllDetails();
    for (final detail in details) {
      final id = detail.mission.id;
      if (detail.events.isNotEmpty || detail.phase == MissionPhase.cancelled) {
        for (final entry in store.notificationIds.entries) {
          if (entry.key.startsWith('mission-$id-startReminder-')) {
            await dispatcher.cancel(entry.value);
          }
        }
      }
      final notificationId = store.notificationIds['mission-$id-execution'];
      if (notificationId != null &&
          (detail.phase == MissionPhase.running ||
              detail.phase == MissionPhase.paused)) {
        await dispatcher.show(executionReminder(detail, notificationId));
      }
      final start = detail.schedule.fixedStartAt;
      if (detail.phase == MissionPhase.notStarted &&
          start != null &&
          !start.isAfter(DateTime.now()) &&
          start
              .add(Duration(minutes: detail.schedule.plannedDurationMinutes))
              .isAfter(DateTime.now())) {
        // 保留当前执行的冲突策略：明确提醒，不伪装成该计划已经开始。
        final key = 'mission-$id-startReminder-${detail.schedule.id}-waiting';
        final reminderId = store.notificationIds[key];
        if (reminderId != null) {
          await dispatcher.show(
            ReminderRequest(
              idempotencyKey: key,
              notificationId: reminderId,
              missionId: id,
              scheduleRevisionId: detail.schedule.id,
              kind: ReminderKind.upcomingReminder,
              title: '计划任务等待开始：${detail.mission.title}',
              body: '另一个任务正在执行，点击查看并处理',
              expectedSequence: detail.lastSequence,
              candidateEventIds: const {},
            ),
          );
        }
      }
    }
  } catch (error, stack) {
    failed = true;
    debugPrint('计划任务后台执行失败：$error\n$stack');
    await PlannedAlarmBridge.channel.invokeMethod<void>('failed');
    await bridge.beginSync();
    await bridge.schedule(DateTime.now().add(const Duration(seconds: 30)));
  } finally {
    await scheduler?.dispose();
    await missions.dispose();
    await database.close();
    await PlannedAlarmBridge.channel.invokeMethod<void>('finished', {
      'failed': failed,
    });
  }
}
