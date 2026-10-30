import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mission_book/presentation/missions/evidence/evidence_camera_panel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 内嵌相机拍照并确认，不离开材料草稿区', (tester) async {
    Uint8List? captured;
    DateTime? capturedAt;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EvidenceCameraPanel(
              missionTitle: '隔离的相机验收任务',
              onConfirmed: (bytes, at) async {
                captured = bytes;
                capturedAt = at;
              },
              onChooseFile: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    for (
      var i = 0;
      i < 60 &&
          find.byKey(const Key('evidence-camera-shoot')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(
      find.byKey(const Key('evidence-camera-shoot')),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((item) => item.data)
          .join(' | '),
    );
    await tester.tap(find.byKey(const Key('evidence-camera-shoot')));
    for (
      var i = 0;
      i < 60 &&
          find.byKey(const Key('evidence-camera-confirm')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byKey(const Key('evidence-camera-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('evidence-camera-confirm')));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured, isNotEmpty);
    expect(capturedAt!.isUtc, isTrue);
  });
}
