import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/backup/backup_service.dart';
import 'package:mission_book/application/settings/app_device.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/me/settings_page.dart';
import '../support/me_fakes.dart';

class _Backup implements BackupExporter {
  int calls = 0;
  Completer<Uint8List>? pending;
  bool fail = false;
  @override
  Future<Uint8List> create() async {
    calls++;
    if (fail) throw StateError('测试：缺失附件');
    return pending?.future ?? Uint8List.fromList([1, 2, 3]);
  }
}

class _Device extends TestAppDevice {
  String? saved;
  DevicePlatform platform = DevicePlatform.android;
  bool? notifications = false;
  bool? exactAlarms = true;
  bool failCapabilities = false;
  bool? executionNotifications = true;
  bool? islandSupported = false;
  bool? focusPermission;
  int capabilityQueries = 0;
  Completer<DeviceCapabilities>? pendingCapabilities;
  final settings = <bool>[];
  @override
  Future<DeviceCapabilities> capabilities() async {
    capabilityQueries++;
    if (failCapabilities) throw StateError('测试：权限查询失败');
    return pendingCapabilities?.future ??
        DeviceCapabilities(
          version: '0.2.2 (4)',
          android: platform == DevicePlatform.android,
          platform: platform,
          notifications: notifications,
          exactAlarms: exactAlarms,
          executionNotifications: executionNotifications,
          islandSupported: islandSupported,
          focusPermission: focusPermission,
        );
  }

  @override
  Future<void> openSettings({required bool exactAlarms}) async =>
      settings.add(exactAlarms);
  @override
  Future<String?> saveBackup(Uint8List bytes, String fileName) async {
    expect(bytes, [1, 2, 3]);
    return saved;
  }
}

void main() {
  late _Backup backup;
  late _Device device;
  setUp(() {
    backup = _Backup();
    device = _Device();
  });

  Future<void> open(WidgetTester tester, {bool reduceMotion = false}) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: SettingsPage(device: device, backup: backup),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('导出等待阻止重复操作，取消不显示成功，失败后可以重试保存', (tester) async {
    backup.pending = Completer<Uint8List>();
    await open(tester);
    final export = find.byKey(const Key('backup-export'));
    await tester.ensureVisible(export);
    await tester.pumpAndSettle();
    await tester.tap(export);
    await tester.pump();
    await tester.ensureVisible(export);
    await tester.pump();
    await tester.tap(export);
    await tester.pump();
    expect(backup.calls, 1);
    expect(tester.widget<ButtonStyleButton>(export).onPressed, isNull);
    backup.pending!.complete(Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();
    expect(find.text('已取消保存，可以随时重新导出'), findsOneWidget);
    backup.pending = null;
    backup.fail = true;
    await tester.ensureVisible(export);
    await tester.pumpAndSettle();
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(find.textContaining('导出失败'), findsOneWidget);
    backup.fail = false;
    device.saved = '已保存到 下载\nMissionBook.zip';
    await tester.ensureVisible(export);
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(find.text('已保存到 下载\nMissionBook.zip'), findsOneWidget);
    expect(backup.calls, 3);
  });

  testWidgets('仅缺失权限显示入口，回前台授权后收起，关于显示实际版本', (tester) async {
    device.exactAlarms = false;
    await open(tester);
    expect(find.text('开启系统通知'), findsOneWidget);
    expect(find.text('系统未允许'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('grant-notifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('grant-exact-alarms')));
    await tester.pumpAndSettle();
    expect(device.settings, [false, true]);
    device.notifications = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grant-notifications')), findsNothing);
    expect(find.text('准时提醒权限待开启'), findsOneWidget);
    expect(find.byKey(const Key('grant-exact-alarms')), findsOneWidget);
    device.exactAlarms = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('提醒权限已就绪'), findsOneWidget);
    expect(find.text('去设置'), findsNothing);
    final about = find.byKey(const Key('about-toggle'));
    await tester.scrollUntilVisible(
      about,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(about);
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(find.textContaining('0.2.2 (4)'), findsOneWidget);
    expect(find.textContaining('系统提醒尚未接通'), findsNothing);
    expect(find.textContaining('授权后也不会自动发送提醒'), findsNothing);
  });

  testWidgets('已授权打开页面不显示授权入口，撤销通知权限后恢复对应入口', (tester) async {
    device.notifications = true;
    await open(tester);
    expect(find.text('提醒权限已就绪'), findsOneWidget);
    expect(find.text('去设置'), findsNothing);
    device.notifications = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('开启系统通知'), findsOneWidget);
    expect(find.byKey(const Key('grant-notifications')), findsOneWidget);
    expect(find.byKey(const Key('grant-exact-alarms')), findsNothing);
  });

  testWidgets('权限未知或读取失败不显示就绪，可重试恢复', (tester) async {
    device.notifications = null;
    device.exactAlarms = null;
    await open(tester);
    expect(find.text('部分提醒权限无法查询'), findsOneWidget);
    expect(find.text('提醒权限已就绪'), findsNothing);
    expect(find.text('去设置'), findsNothing);
    device.failCapabilities = true;
    await tester.tap(find.byKey(const Key('refresh-permissions')));
    await tester.pumpAndSettle();
    expect(find.text('暂时无法确认提醒权限'), findsOneWidget);
    device.failCapabilities = false;
    device.notifications = true;
    device.exactAlarms = true;
    await tester.tap(find.byKey(const Key('refresh-permissions')));
    await tester.pumpAndSettle();
    expect(find.text('提醒权限已就绪'), findsOneWidget);
    expect(find.byKey(const Key('refresh-permissions')), findsNothing);
  });

  testWidgets('应用通知已允许但执行分类关闭时明确提示；超级岛权限单独显示', (tester) async {
    device.notifications = true;
    device.executionNotifications = false;
    device.islandSupported = true;
    device.focusPermission = false;
    await open(tester);
    expect(find.text('执行状态通知已关闭'), findsOneWidget);
    expect(find.text('提醒权限已就绪'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('island-capability-status')),
    );
    expect(find.textContaining('本应用尚未获准焦点通知'), findsOneWidget);
  });

  testWidgets('Windows 显示系统通知入口及后台限制，不展示 Android 专属能力', (tester) async {
    device.platform = DevicePlatform.windows;
    device.notifications = null;
    await open(tester);
    expect(find.text('Windows 通知设置'), findsOneWidget);
    expect(find.textContaining('小米超级岛'), findsNothing);
    expect(find.text('准时提醒权限'), findsNothing);
    await tester.tap(find.byKey(const Key('windows-notification-settings')));
    await tester.pumpAndSettle();
    expect(device.settings, [false]);
    expect(find.textContaining('应用关闭期间不会自动开始'), findsOneWidget);
  });

  testWidgets('未接入提醒的平台说明限制且不提供无效配置', (tester) async {
    device.platform = DevicePlatform.web;
    await open(tester);
    expect(find.text('当前平台尚未接入系统提醒'), findsOneWidget);
    expect(
      find.byKey(const Key('windows-notification-settings')),
      findsNothing,
    );
    expect(find.byKey(const Key('grant-notifications')), findsNothing);
    expect(find.byKey(const Key('planned-reminder-setting')), findsNothing);
    expect(find.textContaining('无法配置提前提醒'), findsOneWidget);
  });

  testWidgets('首次权限查询未完成时回前台，会重读并丢弃返回前的旧结果', (tester) async {
    final pending = Completer<DeviceCapabilities>();
    device.pendingCapabilities = pending;
    await open(tester);
    expect(find.text('正在读取提醒权限'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    device.pendingCapabilities = null;
    device.notifications = true;
    pending.complete(
      const DeviceCapabilities(
        version: '旧结果',
        android: true,
        notifications: false,
        exactAlarms: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(device.capabilityQueries, 2);
    expect(find.text('提醒权限已就绪'), findsOneWidget);
    expect(find.text('去设置'), findsNothing);
  });
  testWidgets('备份范围准确，关于的展开状态可访问且支持减少动画', (tester) async {
    final semantics = tester.ensureSemantics();

    await open(tester, reduceMotion: true);
    final scope = find.textContaining('不含 API Key 与未发送草稿');
    await tester.scrollUntilVisible(
      scope,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(scope);
    expect(scope, findsOneWidget);
    expect(find.textContaining('暂不支持恢复'), findsOneWidget);
    final about = find.byKey(const Key('about-toggle'));
    await tester.scrollUntilVisible(
      about,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(about);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(find.textContaining('把目标落到行动，让记录忠于事实'), findsOneWidget);
    expect(find.byType(AnimatedSize), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
