import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/widgets/app_date_picker.dart';

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(768, 1024),
    const Size(1400, 900),
  ]) {
    testWidgets('日期选择适配 ${size.width}，快捷选择确认与取消', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DateTime? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showAppDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 9, 1),
                  currentDate: DateTime(2026, 10, 27),
                  firstDate: DateTime(1),
                  lastDate: DateTime(9999, 12, 31),
                  title: '选择计划日期',
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-date-tomorrow')));
      await tester.pumpAndSettle();
      expect(find.text('2026年10月28日'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('app-date-confirm')));
      await tester.tap(find.byKey(const Key('app-date-confirm')));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 28));
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('取消'));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('手动输入日期时拒绝无效日期并保留输入', (tester) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showAppDatePicker(
                context: context,
                initialDate: DateTime(2026, 1, 1),
                currentDate: DateTime(2026, 1, 1),
                firstDate: DateTime(1),
                lastDate: DateTime(9999, 12, 31),
                title: '选择日期',
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-date-input-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('app-date-input')),
      '2026-02-30',
    );
    await tester.tap(find.byKey(const Key('app-date-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('请输入范围内的有效日期'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('app-date-input')),
      '2030-12-31',
    );
    await tester.tap(find.byKey(const Key('app-date-confirm')));
    await tester.pumpAndSettle();
    expect(result, DateTime(2030, 12, 31));
  });
}
