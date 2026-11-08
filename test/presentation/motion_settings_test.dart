import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/settings/motion_settings.dart';
import 'package:mission_book/core/theme/app_motion.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/me/settings_page.dart';
import 'package:mission_book/presentation/me/motion_preferences_sheet.dart';
import 'package:mission_book/presentation/me/motion_style_sheet.dart';
import 'package:mission_book/presentation/widgets/app_animated_size.dart';
import 'package:mission_book/presentation/widgets/motion_settings_scope.dart';

import '../support/me_fakes.dart';

void main() {
  testWidgets('切换减少动效与正常动效时尺寸组件保留输入状态', (tester) async {
    final settings = MotionSettings(
      read: () async => null,
      write: (_) async {},
    );
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            MotionSettingsHost(settings: settings, child: child!),
        home: const Scaffold(body: AppAnimatedSize(child: TextField())),
      ),
    );
    await tester.enterText(find.byType(TextField), '保留草稿');
    await settings.select(MotionPreference.reduced);
    await tester.pumpAndSettle();
    expect(find.text('保留草稿'), findsOneWidget);
    await settings.select(MotionPreference.full);
    await tester.pumpAndSettle();
    expect(find.text('保留草稿'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('组件预览有真实中间帧，减少动效后立即显示目标值', (tester) async {
    final settings = MotionSettings(
      read: () async => null,
      write: (_) async {},
    );
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (_, child) =>
            MotionSettingsHost(settings: settings, child: child!),
        home: Scaffold(body: MotionPreferencesSheet(settings: settings)),
      ),
    );
    await tester.pumpAndSettle();
    double progress() => tester
        .widget<LinearProgressIndicator>(
          find.byKey(const Key('motion-preview-progress')),
        )
        .value!;
    expect(progress(), .25);
    await tester.tap(find.byKey(const Key('motion-preview-replay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(progress(), inExclusiveRange(.25, 1));
    await tester.pumpAndSettle();
    expect(progress(), 1);
    await tester.tap(find.byKey(const ValueKey('motion-option-reduced')));
    await tester.pumpAndSettle();
    expect(find.text('减少动效已生效'), findsOneWidget);
    expect(progress(), .25);
    await tester.tap(find.byKey(const Key('motion-preview-replay')));
    await tester.pump();
    expect(progress(), 1);
    await tester.tap(find.text('组件预览'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('motion-preview-progress')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final component in [true, false]) {
    testWidgets('${component ? '组件' : '页面'}预览在320宽双倍字号可操作', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = MotionSettings(
        read: () async => null,
        write: (_) async {},
      );
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: MotionSettingsHost(settings: settings, child: child!),
          ),
          home: Scaffold(
            body: component
                ? MotionPreferencesSheet(settings: settings)
                : MotionStyleSheet(settings: settings),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final option = find.byKey(
        ValueKey(component ? 'motion-option-reduced' : 'page-style-slide'),
      );
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      if (component) {
        expect(settings.preference, MotionPreference.reduced);
      } else {
        expect(settings.pageStyle, PageMotionStyle.slide);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('系统减少动效时可在设置显式开启，跟随系统和减少动效仍可恢复', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    String? saved;
    final settings = MotionSettings(
      read: () async => saved,
      write: (value) async => saved = value,
    );
    addTearDown(settings.dispose);
    await settings.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) =>
            MotionSettingsHost(settings: settings, child: child!),
        home: SettingsPage(device: TestAppDevice(), backup: TestBackup()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('系统要求减少动效'), findsOneWidget);
    expect(
      AppMotion.resolve(
        tester.element(find.byType(SettingsPage)),
        AppMotion.standard,
      ),
      Duration.zero,
    );
    await tester.tap(find.byKey(const ValueKey('page-motion-system')));
    await tester.pumpAndSettle();
    expect(find.text('组件预览'), findsOneWidget);
    for (final choice in [
      MotionPreference.full,
      MotionPreference.reduced,
      MotionPreference.system,
    ]) {
      final labels = {
        MotionPreference.full: '开启动效',
        MotionPreference.reduced: '减少动效',
        MotionPreference.system: '跟随系统',
      };
      await tester.ensureVisible(find.text(labels[choice]!).last);
      await tester.tap(find.text(labels[choice]!).last);
      await tester.pumpAndSettle();
      expect(jsonDecode(saved!)['preference'], choice.name);
      final duration = AppMotion.resolve(
        tester.element(find.byType(SettingsPage)),
        AppMotion.standard,
      );
      expect(
        duration,
        choice == MotionPreference.full ? AppMotion.standard : Duration.zero,
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
