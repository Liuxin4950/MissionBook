import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/settings/motion_settings.dart';
import 'package:mission_book/core/theme/app_motion.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/me/settings_page.dart';
import 'package:mission_book/presentation/widgets/motion_settings_scope.dart';

import '../support/me_fakes.dart';

void main() {
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
      await tester.tap(
        find.byKey(ValueKey('page-motion-${settings.preference.name}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(labels[choice]!).last);
      await tester.pumpAndSettle();
      expect(saved, choice.name);
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
