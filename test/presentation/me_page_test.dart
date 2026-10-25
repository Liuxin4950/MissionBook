import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/backup/backup_service.dart';
import 'package:mission_book/application/settings/app_device.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/me/me_page.dart';
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
  bool notifications = false;
  final settings = <bool>[];
  @override
  Future<DeviceCapabilities> capabilities() async => DeviceCapabilities(
    version: '0.2.2 (4)',
    android: true,
    notifications: notifications,
    exactAlarms: true,
  );
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

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MePage(device: device, backup: backup),
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
    await tester.tap(export);
    await tester.pump();
    await tester.tap(export);
    await tester.pump();
    expect(backup.calls, 1);
    expect(tester.widget<FilledButton>(export).onPressed, isNull);
    backup.pending!.complete(Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();
    expect(find.text('已取消保存，可以随时重新导出'), findsOneWidget);
    backup.pending = null;
    backup.fail = true;
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

  testWidgets('两项权限独立打开，回前台重读，关于显示实际查询的版本', (tester) async {
    await open(tester);
    expect(find.text('系统未允许'), findsOneWidget);
    expect(find.text('系统已允许'), findsOneWidget);
    await tester.tap(find.text('去设置').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('去设置').last);
    await tester.pumpAndSettle();
    expect(device.settings, [false, true]);
    device.notifications = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('系统已允许'), findsNWidgets(2));
    final about = find.byKey(const Key('about-toggle'));
    await tester.ensureVisible(about);
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(find.textContaining('0.2.2 (4)'), findsOneWidget);
    expect(find.textContaining('系统提醒尚未接通'), findsOneWidget);
  });
}

