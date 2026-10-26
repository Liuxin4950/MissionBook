import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/presentation/widgets/app_illustration.dart';

void main() {
  testWidgets('隐藏页不提前播放，首次可见时进入并在结束后停止', (tester) async {
    var visible = false;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return TickerMode(
              enabled: visible,
              child: const AppIllustration(
                asset: 'assets/illustrations/goal-path.png',
                width: 192,
                height: 128,
              ),
            );
          },
        ),
      ),
    );
    final opacity = find.descendant(
      of: find.byType(AppIllustration),
      matching: find.byType(Opacity),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Opacity>(opacity).opacity, 0);
    change(() => visible = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(tester.binding.transientCallbackCount, 0);
    change(() => visible = false);
    await tester.pump();
    change(() => visible = true);
    await tester.pump();
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('减少动态效果时直接展示插画，不启动入场计时', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AppIllustration(
            asset: 'assets/illustrations/day-plan.png',
            width: 156,
            height: 104,
          ),
        ),
      ),
    );
    final opacity = find.descendant(
      of: find.byType(AppIllustration),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
