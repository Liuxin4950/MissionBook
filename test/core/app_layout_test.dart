import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_layout.dart';

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
    // 840 宽窗口扣掉侧栏约 80 后只剩 760，不足 864：不能硬切双栏。
    expect(AppLayout.canSplitPane(840 - 80), isFalse);
    expect(AppLayout.canSplitPane(AppLayout.paneMinContentWidth - 1), isFalse);
    expect(AppLayout.canSplitPane(AppLayout.paneMinContentWidth), isTrue);
  });
}
