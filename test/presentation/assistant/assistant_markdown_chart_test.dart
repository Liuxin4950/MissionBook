import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/presentation/assistant/shared/assistant_markdown.dart';
import 'package:mission_book/presentation/assistant/shared/assistant_markdown_chart.dart';

void main() {
  test('图表数据限制类型、点数、文字和数值范围', () {
    final valid = AssistantChartData.tryParse(
      '{"type":"bar","title":"每周完成","unit":"项","data":[{"label":"周一","value":3},{"label":"周二","value":5},{"label":"周三","value":-2}]}',
    );
    expect(valid?.type, AssistantChartType.bar);
    expect(valid?.points, hasLength(3));

    final longTitle = List.filled(81, 'x').join();
    final tooManyPoints = List.generate(
      13,
      (index) => '{"label":"$index","value":1}',
    ).join(',');
    final invalidCases = [
      '{"type":"pie","title":"占比","data":[{"label":"A","value":1}]}',
      '{"type":"line","title":"趋势","data":[{"label":"唯一","value":1}]}',
      '{"type":"bar","title":"$longTitle","data":[{"label":"A","value":1}]}',
      '{"type":"bar","title":"范围","data":[{"label":"A","value":-1000000001}]}',
      '{"type":"bar","title":"范围","data":[{"label":"A","value":1000000001}]}',
      '{"type":"bar","title":"点数","data":[$tooManyPoints]}',
    ];
    for (final value in invalidCases) {
      expect(AssistantChartData.tryParse(value), isNull);
    }
  });

  testWidgets('聊天 Markdown 将柱状图和趋势图渲染为可读原生块', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fence = String.fromCharCode(96) * 3;
    final text = [
      '本周表现：周二完成最多。',
      '',
      '${fence}missionbook-chart',
      '{"type":"bar","title":"每周完成","unit":"项","data":[{"label":"周一","value":3},{"label":"周二","value":5},{"label":"周三","value":-2}]}',
      fence,
      '',
      '${fence}missionbook-chart',
      '{"type":"line","title":"趋势","data":[{"label":"一月","value":2},{"label":"二月","value":4},{"label":"三月","value":3}]}',
      fence,
    ].join('\n');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AssistantMarkdown(text: text)),
      ),
    );

    expect(find.text('每周完成'), findsOneWidget);
    expect(find.text('趋势'), findsOneWidget);
    expect(find.text('周一'), findsOneWidget);
    expect(find.text('3 项'), findsOneWidget);
    expect(find.text('-2 项'), findsOneWidget);
    expect(find.text('二月: 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('非法图表保留可选择的原始数据', (tester) async {
    const raw = '{"type":"pie","title":"占比"}';
    final fence = String.fromCharCode(96) * 3;
    final text = ['${fence}missionbook-chart', raw, fence].join('\n');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AssistantMarkdown(text: text)),
      ),
    );

    expect(find.text('图表数据无法显示'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data?.contains('"type":"pie"') == true,
      ),
      findsOneWidget,
    );
  });
}
