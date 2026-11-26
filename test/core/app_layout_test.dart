import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/layout/app_layout.dart';
import 'package:mission_book/core/theme/app_metrics.dart';

void main() {
  test('窗口分档按语义断点划分：compact<600、medium<840、expanded 起', () {
    expect(AppLayout.windowClassForWidth(320), WindowClass.compact);
    expect(AppLayout.windowClassForWidth(599), WindowClass.compact);
    expect(AppLayout.windowClassForWidth(600), WindowClass.medium);
    expect(AppLayout.windowClassForWidth(839), WindowClass.medium);
    expect(AppLayout.windowClassForWidth(840), WindowClass.expanded);
    expect(AppLayout.windowClassForWidth(1280), WindowClass.expanded);
  });

  test('双栏按内容区宽度启用：凑不齐左右最小宽就落回单列', () {
    expect(AppLayout.canShowSplitPaneForWindow(840), isFalse);
    expect(AppLayout.canSplitPane(AppLayout.paneMinContentWidth - 1), isFalse);
    expect(AppLayout.canSplitPane(AppLayout.paneMinContentWidth), isTrue);
  });

  test('页面区块间距 16，分栏间距 24', () {
    expect(AppMetrics.sectionGap, 16);
    expect(AppLayout.paneGap, 24);
    expect(AppLayout.paneMinContentWidth, 864);
  });
}
