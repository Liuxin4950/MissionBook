import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/notifications/app_notification_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/notifications/notification_dispatcher.dart';
import 'package:mission_book/data/notifications/reminder_store.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/presentation/me/me_page.dart';

import '../support/me_fakes.dart';

class _SettingsStore extends ReminderStore {
  _SettingsStore(super.file);
  bool fail = false;
  @override
  Future<void> load() async {}
  @override
  Future<void> setReminderLeadMinutes(int minutes) async {
    if (fail) throw StateError('测试：保存失败');
    reminderLeadMinutes = minutes;
  }
}

void main() {
  late Directory dir;
  late AppDatabase database;
  late MissionService missions;
  late AppNotificationService notifications;
  late ReminderStore store;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('planned-settings');
    database = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(database));
    store = _SettingsStore(File('${dir.path}/reminders.json'));
    notifications = AppNotificationService(
      missions: missions,
      store: store,
      dispatcher: const UnsupportedNotificationDispatcher(),
      now: DateTime.now,
    );
    await notifications.start();
  });
  tearDown(() async {
    await notifications.dispose();
    await missions.dispose();
    await database.close();
    await dir.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester, {bool largeText = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 900),
            textScaler: TextScaler.linear(largeText ? 2 : 1),
          ),
          child: Scaffold(
            body: MePage(
              device: TestAppDevice(),
              backup: TestBackup(),
              notifications: notifications,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('我的页默认提前10分钟；选择后即时显示，取消选择不改值', (tester) async {
    await open(tester);
    final row = find.byKey(const Key('planned-reminder-setting'));
    await tester.scrollUntilVisible(
      row,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('提前 10 分钟提醒'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-minutes-30')));
    await tester.pumpAndSettle();
    expect(find.text('提前 30 分钟提醒'), findsOneWidget);
    expect(store.reminderLeadMinutes, 30);
    await tester.pumpAndSettle();
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(notifications.reminderLeadMinutes, 30);
  });

  testWidgets('设置保存失败保留原选择并说明错误，可以重试', (tester) async {
    await open(tester);
    (store as _SettingsStore).fail = true;
    final row = find.byKey(const Key('planned-reminder-setting'));
    await tester.scrollUntilVisible(
      row,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-minutes-15')));
    await tester.pumpAndSettle();
    expect(notifications.reminderLeadMinutes, 10);
    expect(find.textContaining('设置操作未完成'), findsOneWidget);
    (store as _SettingsStore).fail = false;
    await tester.pumpAndSettle();
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-minutes-15')));
    await tester.pumpAndSettle();
    expect(notifications.reminderLeadMinutes, 15);
    expect(find.textContaining('设置操作未完成'), findsNothing);
  });

  testWidgets('320宽双倍字体下设置与全部提醒选项可滚动到达', (tester) async {
    await open(tester, largeText: true);
    final row = find.byKey(const Key('planned-reminder-setting'));
    await tester.scrollUntilVisible(
      row,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    final last = find.byKey(const Key('reminder-minutes-60'));
    await tester.ensureVisible(last);
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(notifications.reminderLeadMinutes, 60);
    expect(tester.takeException(), isNull);
  });
}
