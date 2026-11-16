import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/core/theme/app_typography.dart';
import 'package:mission_book/presentation/launch/launch_page.dart';
import 'package:mission_book/presentation/me/settings_page.dart';
import 'package:mission_book/presentation/onboarding/onboarding_page.dart';
import 'package:mission_book/presentation/onboarding/onboarding_scene.dart';

import '../support/me_fakes.dart';

const _captureDir = String.fromEnvironment('UI_CAPTURE_DIR');
final _screen = GlobalKey();

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _open(
  WidgetTester tester, {
  Future<bool> Function()? onFinish,
  double scale = 1,
  bool reduced = false,
  Widget? home,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _captureDir.isEmpty
          ? AppTheme.light
          : AppTheme.light.copyWith(
              textTheme: AppTheme.light.textTheme.apply(
                fontFamily: 'UiPreview',
              ),
              textButtonTheme: TextButtonThemeData(
                style: AppTheme.light.textButtonTheme.style?.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    AppTypography.secondaryAction.copyWith(
                      fontFamily: 'UiPreview',
                    ),
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: AppTheme.light.filledButtonTheme.style?.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    AppTypography.primaryAction.copyWith(
                      fontFamily: 'UiPreview',
                    ),
                  ),
                ),
              ),
            ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: RepaintBoundary(key: _screen, child: child),
      ),
      home: home ?? OnboardingPage(onFinish: onFinish ?? () async => true),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDir.isEmpty) return;
  await tester.runAsync(() async {
    for (final (asset, width) in [
      ('assets/branding/mission_book_logo_v4.png', null),
      ('assets/branding/shuqi-avatar.png', 120),
    ]) {
      final ImageProvider provider = width == null
          ? AssetImage(asset)
          : ResizeImage(AssetImage(asset), width: width);
      await precacheImage(provider, _screen.currentContext!);
    }
  });
  await tester.pumpAndSettle();
  final boundary =
      _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final frame = await boundary.toImage();
    final data = await frame.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_captureDir).create(recursive: true);
    await File(
      '$_captureDir/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    frame.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (_captureDir.isEmpty) return;
    final font = FontLoader('UiPreview')
      ..addFont(
        File(
          '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('三步引导只在结束时保存', (tester) async {
    _size(tester, const Size(390, 844));
    var finishes = 0;
    await _open(
      tester,
      onFinish: () async {
        finishes++;
        return true;
      },
    );
    expect(find.text('今天，先走一步'), findsOneWidget);
    await _capture(tester, 'phone-today');
    for (var i = 1; i < 3; i++) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<OnboardingScene>(find.byType(OnboardingScene)).progress,
        i,
      );
      expect(finishes, 0);
      await _capture(tester, i == 1 ? 'phone-goal' : 'phone-assistant');
    }
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(finishes, 1);
  });

  testWidgets('连续过渡保留同一卡片且有真实中间位置，支持反向返回', (tester) async {
    _size(tester, const Size(390, 844));
    await _open(tester);
    final paper = find.byKey(const Key('onboarding-shared-paper'));
    final originalElement = tester.element(paper);
    Rect rect() {
      final positioned = tester.widget<Positioned>(paper);
      return Rect.fromLTWH(
        positioned.left!,
        positioned.top!,
        positioned.width!,
        positioned.height!,
      );
    }

    final start = rect();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final middle = rect();
    expect(
      tester.widget<OnboardingScene>(find.byType(OnboardingScene)).progress,
      inExclusiveRange(0, 1),
    );
    expect(tester.element(paper), same(originalElement));
    await tester.pumpAndSettle();
    final end = rect();
    expect(middle.top, inExclusiveRange(start.top, end.top));
    expect(tester.element(paper), same(originalElement));
    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();
    expect(rect(), start);
    expect(tester.element(paper), same(originalElement));
  });

  testWidgets('触屏拖动跟手，松手落在正确步骤', (tester) async {
    _size(tester, const Size(390, 844));
    await _open(tester);
    final area = find.byKey(const Key('onboarding-pages'));
    final start = tester.getCenter(area);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-140, 0));
    await tester.pump();
    expect(
      tester.widget<OnboardingScene>(find.byType(OnboardingScene)).progress,
      inExclusiveRange(0, 1),
    );
    await gesture.moveBy(const Offset(-100, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<OnboardingScene>(find.byType(OnboardingScene)).progress,
      1,
    );
  });

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(600, 960), 1.0),
    (const Size(768, 1024), 1.0),
    (const Size(1024, 768), 1.0),
    (const Size(1440, 900), 1.0),
    (const Size(844, 390), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(600, 360), 2.0),
  ]) {
    testWidgets('引导三步与封面适配 $size 字号 $scale', (tester) async {
      _size(tester, size);
      var finishes = 0;
      await _open(
        tester,
        scale: scale,
        onFinish: () async {
          finishes++;
          return true;
        },
      );
      for (var i = 0; i < 3; i++) {
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('onboarding-next')).hitTestable(),
          findsOneWidget,
        );
        if (i < 2) {
          await tester.tap(find.byKey(const Key('onboarding-next')));
          await tester.pumpAndSettle();
        }
      }
      await _capture(
        tester,
        'adapt-${size.width.toInt()}x${size.height.toInt()}-$scale',
      );
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(finishes, 1);
      await _open(
        tester,
        scale: scale,
        home: LaunchPage(onContinue: () {}),
      );
      expect(find.text('MissionBook'), findsOneWidget);
      expect(
        find.byKey(const Key('launch-continue')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        'cover-${size.width.toInt()}x${size.height.toInt()}-$scale',
      );
    });
  }

  for (final size in [const Size(768, 1024), const Size(1024, 768)]) {
    testWidgets('平板重新组织画布与操作，不放大手机或挤成窄列 $size', (tester) async {
      _size(tester, size);
      await _open(tester);
      expect(
        tester.widget<OnboardingScene>(find.byType(OnboardingScene)).expanded,
        isTrue,
      );
      final horizontal = size.width > size.height;
      expect(
        find.byKey(const Key('onboarding-two-columns')),
        horizontal ? findsOneWidget : findsNothing,
      );
      final next = tester.getRect(find.byKey(const Key('onboarding-next')));
      final title = tester.getRect(find.text('今天，先走一步'));
      expect(next.top - title.bottom, lessThan(210));
      if (horizontal) {
        expect(next.center.dx, greaterThan(size.width / 2));
        expect(
          tester.getRect(find.byKey(const Key('onboarding-artwork'))).right,
          lessThan(next.left),
        );
      } else {
        expect(next.center.dx, closeTo(size.width / 2, 1));
      }
      await _capture(
        tester,
        'tablet-${horizontal ? 'landscape' : 'portrait'}-today',
      );
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await _capture(
        tester,
        'tablet-${horizontal ? 'landscape' : 'portrait'}-goal',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('示意图语义独立于标题，减少动效中途切换收敛到目的步骤', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _open(tester);
      expect(
        tester.getSemantics(find.byKey(const Key('onboarding-artwork'))).label,
        '操作示意：从今天的任务卡片开始一次二十分钟的阅读',
      );
      await tester.tap(find.byKey(const Key('onboarding-indicator-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await _open(tester, reduced: true);
      expect(
        tester.widget<OnboardingScene>(find.byType(OnboardingScene)).progress,
        2,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('封面允许用户提前进入', (tester) async {
    var entered = 0;
    await _open(tester, home: LaunchPage(onContinue: () => entered++));
    await tester.tap(find.byKey(const Key('launch-continue')));
    expect(entered, 1);
  });

  testWidgets('窗口旋转和桌面缩放保留当前步骤', (tester) async {
    _size(tester, const Size(390, 844));
    await _open(tester);
    await tester.tap(find.byKey(const Key('onboarding-indicator-1')));
    await tester.pumpAndSettle();
    for (final size in [
      const Size(1024, 768),
      const Size(844, 390),
      const Size(320, 568),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(
        tester.widget<OnboardingScene>(find.byType(OnboardingScene)).progress,
        1,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('键盘左右切换且减少动效立即到位', (tester) async {
    await _open(tester, reduced: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      tester.widget<OnboardingScene>(find.byType(OnboardingScene)).progress,
      1,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(
      tester.widget<OnboardingScene>(find.byType(OnboardingScene)).progress,
      0,
    );
  });

  testWidgets('保存未完成时防止重复，失败后可以重试跳过', (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    await _open(
      tester,
      onFinish: () {
        calls++;
        return calls == 1 ? pending.future : Future.value(true);
      },
    );
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('onboarding-skip')))
          .onPressed,
      isNull,
    );
    expect(calls, 1);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('暂时没能保存，请再试一次。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('回调异常转为可重试提示', (tester) async {
    await _open(tester, onFinish: () async => throw StateError('failed'));
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(find.text('暂时没能保存，请再试一次。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('平板半屏设置重看引导使用全窗口，返回保留设置', (tester) async {
    _size(tester, const Size(1024, 768));
    await _open(
      tester,
      home: Row(
        children: [
          const Expanded(child: ColoredBox(color: Colors.white)),
          Expanded(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) =>
                    SettingsPage(device: TestAppDevice(), backup: TestBackup()),
              ),
            ),
          ),
        ],
      ),
    );
    final settingsElement = tester.element(find.byType(SettingsPage));
    final entry = find.byKey(const Key('settings-onboarding-entry'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(OnboardingPage)).width, 1024);
    expect(find.byKey(const Key('onboarding-two-columns')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
    expect(tester.element(find.byType(SettingsPage)), same(settingsElement));
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置重看引导结束后回到设置', (tester) async {
    _size(tester, const Size(390, 844));
    await _open(
      tester,
      home: SettingsPage(device: TestAppDevice(), backup: TestBackup()),
    );
    final entry = find.byKey(const Key('settings-onboarding-entry'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
