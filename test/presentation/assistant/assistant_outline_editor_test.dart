import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/assistant/assistant_operation_card.dart';
import 'package:mission_book/presentation/assistant/assistant_outline_editor.dart';

const _captureDir = String.fromEnvironment('AI_ACTION_CAPTURE_DIR');

void main() {
  setUpAll(() async {
    if (_captureDir.isEmpty) return;
    final font = FontLoader('ActionPreview');
    font.addFont(
      File(
        'C:/Windows/Fonts/msyh.ttc',
      ).readAsBytes().then(ByteData.sublistView),
    );
    await font.load();
  });
  testWidgets('手机大字可修改目标，移除父节点连同子树，整份编辑后提交', (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, Object?>? saved;
    final screen = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: _captureDir.isEmpty
            ? AppTheme.light
            : AppTheme.light.copyWith(
                textTheme: AppTheme.light.textTheme.apply(
                  fontFamily: 'ActionPreview',
                ),
              ),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            appBar: AppBar(title: const Text('修改目标大纲')),
            body: RepaintBoundary(
              key: screen,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AssistantOutlineEditor(
                  input: const {
                    'title': '学会 Flutter',
                    'nodes': [
                      {'key': 'base', 'title': '基础'},
                      {'key': 'layout', 'parentKey': 'base', 'title': '布局'},
                      {'key': 'project', 'title': '独立项目'},
                    ],
                  },
                  onSave: (input) {
                    saved = input;
                    return null;
                  },
                  onCancel: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('outline-field-title')),
      '我的 Flutter 目标',
    );
    tester.testTextInput.hide();
    await tester.ensureVisible(
      find.byKey(const ValueKey('outline-remove-base')),
    );
    await tester.tap(find.byKey(const ValueKey('outline-remove-base')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('outline-field-layout:title')),
      findsNothing,
    );
    await tester.ensureVisible(find.text('保存提案'));
    await tester.tap(find.text('保存提案'));
    await tester.pumpAndSettle();
    expect(saved!['title'], '我的 Flutter 目标');
    expect((saved!['nodes'] as List).single, containsPair('key', 'project'));
    expect(tester.takeException(), isNull);
    if (_captureDir.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary =
            screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(_captureDir).create(recursive: true);
        await File(
          '$_captureDir/outline-editor-320.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('再次尝试表单可调整日期及方案，不引入不支持字段或更换来源', (tester) async {
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssistantProposalEditor(
              operation: AssistantOperation(
                callId: 'retry',
                toolName: 'mission_retry',
                input: const {
                  'missionId': 'source',
                  'title': '重做布局',
                  'scheduledDate': '2026-10-30',
                  'plannedMinutes': 25,
                  'objective': '独立完成布局',
                  'fixedStartLocal': '10:00',
                },
              ),
              onSave: (input) {
                saved = input;
                return null;
              },
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    final date = find.widgetWithText(TextField, '日期 YYYY-MM-DD');
    await tester.enterText(date, '2026-10-31');
    await tester.enterText(
      find.widgetWithText(TextField, '固定开始 HH:mm（留空为自选）'),
      '',
    );
    await tester.ensureVisible(find.text('保存提案'));
    await tester.tap(find.text('保存提案'));
    await tester.pumpAndSettle();
    expect(saved!['scheduledDate'], '2026-10-31');
    expect(saved!['missionId'], 'source');
    expect(saved!.containsKey('fixedStartLocal'), isFalse);
    expect(saved!.containsKey('timePolicy'), isFalse);
  });
}
