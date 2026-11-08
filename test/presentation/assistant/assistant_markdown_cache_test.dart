import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/presentation/assistant/shared/assistant_markdown.dart';
import 'package:mission_book/presentation/assistant/shared/assistant_markdown_cache.dart';

void main() {
  test('Markdown AST 缓存按最近使用顺序淘汰并限制容量', () {
    final cache = AssistantMarkdownAstCache(
      maxEntries: 2,
      maxWeight: 1000,
      maxSourceLength: 100,
    );
    const first = '# First\n\nOne paragraph.';
    const second = '# Second\n\nOne paragraph.';
    const third = '# Third\n\nOne paragraph.';

    final firstAst = cache.parse(first);
    cache.parse(second);
    expect(identical(firstAst, cache.parse(first)), isTrue);
    cache.parse(third);

    expect(cache.entryCount, 2);
    expect(cache.estimatedWeight, lessThanOrEqualTo(1000));
    expect(identical(firstAst, cache.parse(second)), isFalse);
    expect(cache.entryCount, 2);
  });

  test('超过单条上限的 Markdown 不进入 AST 缓存', () {
    final cache = AssistantMarkdownAstCache(
      maxEntries: 2,
      maxWeight: 1000,
      maxSourceLength: 12,
    );
    const source = 'a paragraph that is too long to retain';

    expect(identical(cache.parse(source), cache.parse(source)), isFalse);
    expect(cache.entryCount, 0);
    expect(cache.estimatedWeight, 0);
  });

  testWidgets('长 Markdown 使用惰性列表且保留 GFM 块内容', (tester) async {
    final filler = List.filled(20, '说明').join();
    final lastParagraph = '正文段落 99 $filler';
    final text = [
      '# 规划',
      '',
      '[资料链接](https://example.invalid/spec)',
      '',
      '| 项目 | 状态 |',
      '| --- | --- |',
      '| 同步 | 开启 |',
      '',
      '- 任务',
      '  - 子项',
      '',
      '```dart',
      'final value = 1;',
      '```',
      '',
      ...List.generate(100, (index) => '正文段落 $index $filler'),
    ].join('\n');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AssistantMarkdown(text: text),
          ),
        ),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Scrollbar && widget.thumbVisibility == true,
      ),
      findsOneWidget,
    );
    expect(find.text('同步'), findsOneWidget);
    expect(find.text('子项'), findsOneWidget);
    expect(find.text('final value = 1;'), findsOneWidget);
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      launcherChannel,
      (call) async {
        calls.add(call);
        return false;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        null,
      ),
    );
    await tester.tap(find.text('资料链接'));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'launch');
    expect(
      (calls.single.arguments as Map)['url'],
      'https://example.invalid/spec',
    );
    expect(find.text('无法打开该链接，可以复制后查看'), findsOneWidget);

    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -10000));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains(lastParagraph),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
