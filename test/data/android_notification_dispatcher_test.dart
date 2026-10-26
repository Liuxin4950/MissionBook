import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/notifications/android_notification_dispatcher.dart';
import 'package:mission_book/domain/notifications/reminder_request.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pluginChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const appearanceChannel = MethodChannel(
    'mission_book/notification_appearance',
  );
  final calls = <MethodCall>[];
  late AndroidNotificationDispatcher dispatcher;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    for (final channel in [pluginChannel, appearanceChannel]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    }
    dispatcher = AndroidNotificationDispatcher(
      plugin: FlutterLocalNotificationsPlugin(),
      exactAlarmsAllowed: false,
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    for (final channel in [pluginChannel, appearanceChannel]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  ReminderRequest request(ReminderKind kind) => ReminderRequest(
    idempotencyKey: 'execution-test',
    notificationId: 42,
    missionId: 'mission',
    scheduleRevisionId: 'schedule',
    kind: kind,
    title: '阅读',
    body: '事实摘要',
    expectedSequence: 2,
    candidateEventIds: const {'pause': 'pause-id', 'resume': 'resume-id'},
    focusMilliseconds: kind == ReminderKind.upcomingReminder ? null : 75000,
    projectedAt: DateTime.utc(2026, 10, 26),
    budgetMinutes: 30,
  );

  for (final kind in [
    ReminderKind.executionRunning,
    ReminderKind.executionPaused,
  ]) {
    test('执行通知 $kind 静默更新且保留动作和身份，自定义内容接收同一摘要', () async {
      final projected = request(kind);
      await dispatcher.show(projected);
      expect(calls.map((call) => call.method), ['show', 'decorateExecution']);
      final sent = calls.first.arguments as Map;
      final android = sent['platformSpecifics'] as Map;
      expect(android['channelId'], 'mission_execution_v2');
      expect(android['importance'], Importance.low.value);
      expect(android['silent'], isTrue);
      expect(android['onlyAlertOnce'], isTrue);
      expect(android['autoCancel'], isFalse);
      expect(
        android['icon'],
        kind == ReminderKind.executionRunning
            ? 'ic_stat_running'
            : 'ic_stat_paused',
      );
      final actions = android['actions'] as List;
      expect(
        (actions.single as Map)['id'],
        kind == ReminderKind.executionRunning ? 'stop' : 'resume',
      );
      expect((actions.single as Map)['cancelNotification'], isFalse);
      final payload = ReminderRequest.fromPayload(sent['payload'] as String)!;
      expect(payload.expectedSequence, 2);
      expect(payload.candidateEventIds, projected.candidateEventIds);
      final custom = calls.last.arguments as Map;
      expect(custom['focusMilliseconds'], 75000);
      expect(custom['running'], kind == ReminderKind.executionRunning);
      expect(custom['id'], 42);
      await dispatcher.cancel(42);
      expect(calls[calls.length - 2].method, 'invalidate');
      expect(calls.last.method, 'cancel');
    });
  }

  test('计划提醒继续用提醒频道和单色图标，不套执行计时布局', () async {
    await dispatcher.show(request(ReminderKind.upcomingReminder));
    expect(calls, hasLength(1));
    final android = (calls.single.arguments as Map)['platformSpecifics'] as Map;
    expect(android['channelId'], 'mission_reminders');
    expect(android['importance'], Importance.high.value);
    expect(android['icon'], 'ic_stat_mission');
  });

  test('外观失效通道失败仍撤销系统通知并传回错误', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appearanceChannel, (_) async {
          throw PlatformException(code: 'appearance_unavailable');
        });
    await expectLater(dispatcher.cancel(42), throwsA(isA<PlatformException>()));
    expect(calls.single.method, 'cancel');
  });
}
