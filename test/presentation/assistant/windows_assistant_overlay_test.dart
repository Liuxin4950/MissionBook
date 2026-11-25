import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/presentation/assistant/desktop/windows_assistant_overlay.dart';

void main() {
  testWidgets('更多中的关闭悬浮球请求原生关闭开关', (tester) async {
    const channel = MethodChannel('mission_book/windows_overlay');
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final semantics = tester.ensureSemantics();

    Future<void> publishParts(List<String> ids) async {
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall('layout', {
            'w': 320,
            'h': 360,
            'dock': 0,
            'parts': [
              for (var i = 0; i < ids.length; i++)
                {'id': ids[i], 'x': 20, 'y': i * 64, 'w': 50, 'h': 50},
            ],
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    runWindowsAssistantOverlay();
    await tester.pumpAndSettle();
    await publishParts(['text', 'voice', 'capture', 'more']);
    expect(find.text('关闭'), findsNothing);
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    expect(calls.last.method, 'mode');
    expect((calls.last.arguments as Map)['value'], 'more');

    // 原生宿主发布第二层布局，Flutter 渲染动作并把关闭请求交回宿主保存。
    await publishParts(['main', 'usage', 'close', 'back']);
    expect(find.text('截图'), findsNothing);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('关闭悬浮球')), findsOneWidget);
    calls.clear();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(calls.map((call) => call.method), ['closeOverlay']);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
