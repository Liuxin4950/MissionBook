import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/widgets/app_confirm_dialog.dart';

Widget dialogApp(ValueChanged<bool> onResult, {double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            final result = await AppConfirmDialog.show(
              context: context,
              title: '放弃本次填写？',
              message: '返回后，已填写的内容不会保存。',
              cancelText: '继续填写',
              confirmText: '放弃填写',
            );
            onResult(result);
          },
          child: const Text('打开确认框'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('仅明确确认返回 true，继续、遮罩及系统返回均为 false', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(dialogApp(results.add));
    for (final action in ['继续填写', '遮罩', '系统返回', '放弃填写']) {
      await tester.tap(find.text('打开确认框'));
      await tester.pumpAndSettle();
      if (action == '遮罩') {
        await tester.tapAt(const Offset(8, 8));
      } else if (action == '系统返回') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text(action));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AppConfirmDialog), findsNothing);
      expect(find.text('打开确认框'), findsOneWidget);
    }
    expect(results, [false, false, false, true]);
  });

  testWidgets('390宽按钮等宽横排，读屏保留标题和两个操作', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(dialogApp((_) {}));
      await tester.tap(find.text('打开确认框'));
      await tester.pumpAndSettle();
      final cancel = tester.getRect(find.byType(FilledButton));
      final confirm = tester.getRect(find.byType(OutlinedButton));
      expect(cancel.top, confirm.top);
      expect(cancel.width, confirm.width);
      expect(cancel.height, greaterThanOrEqualTo(48));
      expect(confirm.height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('放弃本次填写？'), findsOneWidget);
      expect(find.bySemanticsLabel('继续填写'), findsOneWidget);
      expect(find.bySemanticsLabel('放弃填写'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('320宽双倍字体按钮纵排，矮视口可滚动到确认并关闭', (tester) async {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;
    await tester.pumpWidget(dialogApp((value) => result = value, textScale: 2));
    await tester.tap(find.text('打开确认框'));
    await tester.pumpAndSettle();
    final cancel = tester.getRect(find.byType(FilledButton));
    final confirm = tester.getRect(find.byType(OutlinedButton));
    expect(confirm.top, greaterThanOrEqualTo(cancel.bottom + 12));
    expect(cancel.left, confirm.left);
    expect(cancel.right, confirm.right);
    expect(cancel.left, greaterThanOrEqualTo(24));
    expect(confirm.right, lessThanOrEqualTo(296));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃填写'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}
