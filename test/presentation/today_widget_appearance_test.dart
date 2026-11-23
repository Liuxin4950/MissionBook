import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/notifications/today_widget_bridge.dart';
import 'package:mission_book/presentation/me/settings_page.dart';

import '../support/me_fakes.dart';

const _entry = Key('settings-today-widget-entry');
const _system = Key('today-widget-theme-system');
const _light = Key('today-widget-theme-light');
const _dark = Key('today-widget-theme-dark');
const _large = Key('today-widget-text-large');

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(device: TestAppDevice(), backup: TestBackup()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAppearance(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(_entry));
    await tester.tap(find.byKey(_entry));
    await tester.pumpAndSettle();
  }

  void mockNative(
    WidgetTester tester,
    Future<Object?> Function(MethodCall) handler,
  ) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(TodayWidgetBridge.channel, handler);
    addTearDown(
      () => messenger.setMockMethodCallHandler(TodayWidgetBridge.channel, null),
    );
  }

  ChoiceChip chip(WidgetTester tester, Key key) =>
      tester.widget<ChoiceChip>(find.byKey(key));

  testWidgets('Android 小组件颜色、字号独立保存，重开从原生读回', (tester) async {
    var native = {'theme': 'system', 'textSize': 'standard'};
    final writes = <Map<String, String>>[];
    mockNative(tester, (call) async {
      switch (call.method) {
        case 'getAppearance':
          return native;
        case 'setAppearance':
          native = Map<String, String>.from(call.arguments as Map);
          writes.add(native);
          return null;
        default:
          throw MissingPluginException(call.method);
      }
    });
    await openSettings(tester);
    await openAppearance(tester);
    expect(chip(tester, _system).selected, isTrue);
    await tester.tap(find.byKey(_light));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_large));
    await tester.pumpAndSettle();
    expect(writes, [
      {'theme': 'light', 'textSize': 'standard'},
      {'theme': 'light', 'textSize': 'large'},
    ]);
    await tester.tap(find.byTooltip('关闭小组件样式'));
    await tester.pumpAndSettle();
    await openAppearance(tester);
    expect(chip(tester, _light).selected, isTrue);
    expect(chip(tester, _large).selected, isTrue);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('读取可重试，保存等待回执且失败保留上一个值', (tester) async {
    var reads = 0;
    final write = Completer<Object?>();
    mockNative(tester, (call) async {
      if (call.method == 'getAppearance') {
        if (reads++ == 0) return null;
        return {'theme': 'system', 'textSize': 'standard'};
      }
      expect(call.method, 'setAppearance');
      return write.future;
    });
    await openSettings(tester);
    await openAppearance(tester);
    expect(find.text('暂时无法读取小组件样式。'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_dark));
    await tester.pump();
    expect(chip(tester, _system).selected, isTrue);
    expect(chip(tester, _light).onSelected, isNull);
    write.completeError(PlatformException(code: 'today_widget_failed'));
    await tester.pumpAndSettle();
    expect(chip(tester, _system).selected, isTrue);
    expect(chip(tester, _dark).onSelected, isNotNull);
    expect(find.text('无法应用小组件样式，请重试。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('其他平台不展示 Android 小组件配置', (tester) async {
    await openSettings(tester);
    expect(find.byKey(_entry), findsNothing);
  }, variant: const TargetPlatformVariant({TargetPlatform.windows}));
}
