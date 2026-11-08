import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/settings/motion_settings.dart';
import 'package:mission_book/core/theme/app_motion.dart';
import 'package:mission_book/presentation/widgets/app_content_transition.dart';
import 'package:mission_book/presentation/widgets/motion_settings_scope.dart';
import 'package:mission_book/presentation/widgets/adaptive_sheet.dart';
import 'package:mission_book/presentation/me/motion_style_sheet.dart';

void main() {
  for (final style in PageMotionStyle.values) {
    testWidgets('Android ${style.name} 保留预测返回的取消和提交', (tester) async {
      final settings = MotionSettings(
        read: () async => null,
        write: (_) async {},
      );
      addTearDown(settings.dispose);
      await settings.selectPageStyle(style);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          navigatorKey: nav,
          builder: (context, child) =>
              MotionSettingsHost(settings: settings, child: child!),
          home: const Scaffold(body: Text('列表')),
        ),
      );
      final route = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('详情')),
      );
      nav.currentState!.push(route);
      await tester.pumpAndSettle();
      Future<bool?> back(String method, [double? progress]) =>
          tester.runAsync(() async {
            final response = Completer<ByteData?>();
            tester.binding.channelBuffers.push(
              SystemChannels.backGesture.name,
              SystemChannels.backGesture.codec.encodeMethodCall(
                MethodCall(
                  method,
                  progress == null
                      ? null
                      : {
                          'touchOffset': <double>[progress * 400, 300],
                          'progress': progress,
                          'swipeEdge': 0,
                        },
                ),
              ),
              response.complete,
            );
            return SystemChannels.backGesture.codec.decodeEnvelope(
                  (await response.future)!,
                ) ==
                true;
          });

      expect(await back('startBackGesture', 0), isTrue);
      await back('updateBackGestureProgress', .5);
      await tester.pump();
      expect(route.popGestureInProgress, isTrue);
      await back('cancelBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('详情'), findsOneWidget);
      expect(nav.currentState!.canPop(), isTrue);
      expect(await back('startBackGesture', 0), isTrue);
      await back('updateBackGestureProgress', .7);
      await tester.pump();
      await back('commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('列表'), findsOneWidget);
      expect(nav.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('本机减少动效使详情和弹层零时长，嵌套预览同样生效', (tester) async {
    final settings = MotionSettings(
      read: () async => null,
      write: (_) async {},
    );
    addTearDown(settings.dispose);
    await settings.select(MotionPreference.reduced);
    final nav = GlobalKey<NavigatorState>();
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        builder: (_, child) =>
            MotionSettingsHost(settings: settings, child: child!),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('列表'));
          },
        ),
      ),
    );
    final route = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('详情')),
    );
    nav.currentState!.push(route);
    await tester.pumpAndSettle();
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    unawaited(
      showAdaptiveSheet<void>(
        context: pageContext,
        builder: (_) => MotionStyleSheet(settings: settings),
      ),
    );
    await tester.pumpAndSettle();
    final sheetRoute = ModalRoute.of(
      tester.element(find.byType(MotionStyleSheet)),
    )!;
    expect(sheetRoute.transitionDuration, Duration.zero);
    await tester.tap(find.byKey(const ValueKey('page-style-slide')));
    await tester.pumpAndSettle();
    expect(settings.pageStyle, PageMotionStyle.slide);
    expect(find.byKey(const ValueKey('motion-preview-detail')), findsOneWidget);
    final previewRoute = ModalRoute.of(tester.element(find.text('返回')))!;
    expect(previewRoute.transitionDuration, Duration.zero);
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(find.text('预览'), findsOneWidget);
    await tester.tap(find.byKey(const Key('page-motion-replay')));
    await tester.pumpAndSettle();
    expect(find.text('返回'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('快速切换保留输入状态，途中减少动效立即显示最终内容', (tester) async {
    final settings = MotionSettings(
      read: () async => null,
      write: (_) async {},
    );
    addTearDown(settings.dispose);
    var identity = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            MotionSettingsHost(settings: settings, child: child!),
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Scaffold(
              body: AppContentTransition(
                identity: identity,
                child: const TextField(),
              ),
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '草稿');
    update(() => identity = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    update(() => identity = 2);
    await tester.pump();
    await settings.select(MotionPreference.reduced);
    await tester.pump();
    expect(find.text('草稿'), findsOneWidget);
    final fade = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(AppContentTransition),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1);
    expect(
      AppMotion.resolve(
        tester.element(find.byType(TextField)),
        AppMotion.standard,
      ),
      Duration.zero,
    );
    expect(tester.takeException(), isNull);
  });
}
