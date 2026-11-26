import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/settings/motion_settings.dart';
import 'package:mission_book/presentation/widgets/app_top_bar.dart';
import 'package:mission_book/presentation/widgets/detail_pane.dart';
import 'package:mission_book/presentation/motion/motion_settings_scope.dart';

void main() {
  late DetailPaneController pane;
  late MotionSettings settings;

  setUp(() {
    pane = DetailPaneController();
    settings = MotionSettings(read: () async => null, write: (_) async {});
  });

  tearDown(() {
    pane.dispose();
    settings.dispose();
  });

  Widget firstPage(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: '父页面'),
    body: Center(
      child: TextButton(
        key: const Key('open-grandchild'),
        onPressed: () => openDetailPane<void>(
          context,
          label: '子页面',
          builder: (_) => Scaffold(
            appBar: const AppTopBar(title: '子页面'),
            body: const Center(child: Text('子页面内容')),
          ),
        ),
        child: const Text('打开子页面'),
      ),
    ),
  );

  Widget app() => MaterialApp(
    builder: (_, child) =>
        MotionSettingsHost(settings: settings, child: child!),
    home: DetailPaneScope(
      controller: pane,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Builder(
                builder: (context) => TextButton(
                  key: const Key('open-root-page'),
                  onPressed: () => openDetailPane<void>(
                    context,
                    label: '父页面',
                    builder: firstPage,
                  ),
                  child: const Text('打开页面'),
                ),
              ),
            ),
            Positioned.fill(
              child: DetailPaneHost(controller: pane, restoreSplitOnBack: true),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('全屏新链固定在同一 Navigator，设置切换不迁移子页', (tester) async {
    settings.openSubpagesInPane = false;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('open-root-page')));
    await tester.pumpAndSettle();

    expect(pane.isPaneFullScreen, isTrue);
    expect(pane.shouldRestorePaneOnBack, isFalse);
    expect(find.byKey(const Key('pane-restore-split')), findsOneWidget);

    await settings.selectOpenSubpagesInPane(true);
    await tester.tap(find.byKey(const Key('open-grandchild')));
    await tester.pumpAndSettle();
    expect(pane.entries, hasLength(2));
    expect(pane.isPaneFullScreen, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pane.entries, hasLength(1));
    expect(pane.isPaneFullScreen, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pane.entries, isEmpty);
    expect(find.byKey(const Key('open-root-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('显式全屏返回先退子页，到进入时栈深才还原分栏', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('open-root-page')));
    await tester.pumpAndSettle();
    pane.togglePaneFullScreen();
    await tester.pumpAndSettle();
    expect(pane.shouldRestorePaneOnBack, isTrue);

    await tester.tap(find.byKey(const Key('open-grandchild')));
    await tester.pumpAndSettle();
    expect(pane.shouldRestorePaneOnBack, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pane.entries, hasLength(1));
    expect(pane.isPaneFullScreen, isTrue);
    expect(pane.shouldRestorePaneOnBack, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pane.entries, hasLength(1));
    expect(pane.isPaneFullScreen, isFalse);
    expect(find.text('父页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
