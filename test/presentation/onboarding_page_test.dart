import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/onboarding/onboarding_page.dart';
import 'package:mission_book/presentation/launch/launch_page.dart';

void main() {
  testWidgets('首次体验按三步介绍今天、目标和助手', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var finishes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OnboardingPage(
          onFinish: () async {
            finishes++;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('先从今天开始，不必先学会一切'), findsOneWidget);
    expect(find.text('第一步 · 今天'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('把目标写成可以走的路径'), findsOneWidget);
    expect(find.text('第二步 · 目标'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('需要时，让助手帮你整理'), findsOneWidget);
    expect(find.text('第三步 · 助手'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(finishes, 1);
  });

  testWidgets('跳过新手引导使用同一个完成回调', (tester) async {
    var finishes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OnboardingPage(
          onFinish: () async {
            finishes++;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(finishes, 1);
  });

  for (final size in [const Size(390, 844), const Size(768, 1024)]) {
    testWidgets('开屏在不同窗口尺寸保持品牌结构 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: LaunchPage()));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('MissionBook'), findsOneWidget);
      expect(find.text('让方向，成为今天的行动。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
