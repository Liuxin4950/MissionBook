import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/widgets/app_segmented_control.dart';

void main() {
  testWidgets('分类共享同一背景块，点击与快速反向选择均从当前位置连续移动', (tester) async {
    var selected = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return AppSegmentedControl<int>(
                options: const {0: '进行中', 1: '已搁置', 2: '已达成'},
                selected: selected,
                onSelected: (value) => update(() => selected = value),
              );
            },
          ),
        ),
      ),
    );
    final surface = find.byKey(const Key('segmented-selection-surface'));
    final start = tester.getCenter(surface).dx;
    final target = tester.getCenter(find.text('已达成')).dx;
    await tester.tap(find.text('已达成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final midway = tester.getCenter(surface).dx;
    expect(midway, inExclusiveRange(start, target));
    await tester.tap(find.text('进行中'));
    await tester.pump();
    expect(tester.getCenter(surface).dx, closeTo(midway, .01));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getCenter(surface).dx, inExclusiveRange(start, midway));
    await tester.pumpAndSettle();
    expect(tester.getCenter(surface).dx, closeTo(start, .01));
    expect(surface, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
