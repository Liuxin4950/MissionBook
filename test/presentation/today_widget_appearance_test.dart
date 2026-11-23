import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/notifications/today_widget_bridge.dart';
import 'package:mission_book/data/settings/today_widget_appearance.dart';
import 'package:mission_book/presentation/me/settings_page.dart';
import 'package:mission_book/presentation/me/today_widget_preview.dart';

import '../support/me_fakes.dart';

const _entry = Key('settings-today-widget-entry');
const _close = Key('today-widget-close');
const _save = Key('today-widget-save');
const _status = Key('today-widget-status');
const _surface = Key('today-widget-preview-surface');
const _styleIndex = Key('today-widget-style-indexCard');
const _styleMinimal = Key('today-widget-style-minimal');
const _themeDark = Key('today-widget-theme-dark');
const _showStatus = Key('today-widget-showStatus');
const _showDate = Key('today-widget-showDate');
const _previewLarge = Key('today-widget-preview-size-large');
const _previewDark = Key('today-widget-preview-theme-dark');

Map<String, Object?> appearanceMap([Map<String, Object?> changes = const {}]) {
  final map = TodayWidgetAppearance.defaults.toMap();
  map.addAll(changes);
  return map;
}

Map<String, Object?> getEnvelope({
  Map<String, Object?>? appearance,
  Map<String, Object?>? defaults,
  bool recovered = false,
  String source = 'v2',
}) => {
  'version': 2,
  'appearance': appearance ?? appearanceMap(),
  'defaults': defaults ?? TodayWidgetAppearance.defaults.toMap(),
  'recovered': recovered,
  'source': source,
};

Map<String, Object?> previewEnvelope({
  String sizeClass = 'medium',
  String sizeSource = 'reference',
  int widthDp = 220,
  int heightDp = 109,
  String theme = 'light',
  String style = 'paper',
  List<Map<String, Object?>>? rows,
  bool headerVisible = true,
  String empty = 'none',
  String overflow = 'none',
  String rowLayout = 'stacked',
  bool spineVisible = false,
  bool dividerVisible = true,
}) => {
  'version': 2,
  'sizeClass': sizeClass,
  'sizeSource': sizeSource,
  'widthDp': widthDp,
  'heightDp': heightDp,
  'theme': theme,
  'style': style,
  'colors': {
    'surface': 0xFFF7F8F5.toSigned(32),
    'content': 0xFFFFFFFF.toSigned(32),
    'rowSurface': 0xFFEEF2EC.toSigned(32),
    'spine': 0xFF244D3D.toSigned(32),
    'primaryText': 0xFF282E2A.toSigned(32),
    'secondaryText': 0xFF626A64.toSigned(32),
    'accent': 0xFF244D3D.toSigned(32),
    'warn': 0xFF805D28.toSigned(32),
    'hairline': 0xFFE0E5DD.toSigned(32),
  },
  'metrics': {
    'horizontalPadding': 10,
    'verticalPadding': 6,
    'rowPadding': 4,
    'rowGap': 4,
    'radius': 16,
    'headerSp': 12,
    'taskSp': 12,
    'metaSp': 11,
    'headerHeight': 24,
    'footerHeight': 20,
    'rowHeight': 32,
  },
  'header': {
    'visible': headerVisible,
    'left': '今日任务',
    'right': '11月23日',
    'count': null,
  },
  'rows':
      rows ??
      [
        {
          'time': '08:00–09:40',
          'title': '品牌与营销管理实务',
          'status': '进行中',
          'showTime': true,
          'showStatus': true,
          'titleMaxLines': 1,
          'progress': '计划时段剩余 91 分钟',
        },
        {
          'time': '14:00–15:40',
          'title': 'Python程序设计基础',
          'status': '待开始',
          'showTime': true,
          'showStatus': true,
          'titleMaxLines': 1,
          'progress': null,
        },
      ],
  'footer': {'visible': true, 'kind': 'more', 'text': '另有 4 项'},
  'empty': empty,
  'overflow': overflow,
  'rowLayout': rowLayout,
  'spineVisible': spineVisible,
  'dividerVisible': dividerVisible,
  'sample': true,
  // Mock the binary preview returned by Android's RemoteViews renderer.
  'renderedPng': Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0B,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0xF8,
    0x0F,
    0x04,
    0x00,
    0x09,
    0xFB,
    0x03,
    0xFD,
    0xFB,
    0x5E,
    0x6B,
    0x2B,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]),
};

Map<Object?, Object?> _arguments(MethodCall call) {
  final arguments = call.arguments;
  if (arguments is Map<Object?, Object?>) return arguments;
  throw StateError('通道参数不是 Map：${call.method}');
}

Map<Object?, Object?> _nestedMap(Object? value) {
  if (value is Map<Object?, Object?>) return value;
  throw StateError('嵌套参数不是 Map：$value');
}

void mockWidgetChannel(
  WidgetTester tester,
  Future<Object?> Function(MethodCall call) handler,
) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(TodayWidgetBridge.channel, handler);
  addTearDown(
    () => messenger.setMockMethodCallHandler(TodayWidgetBridge.channel, null),
  );
}

Future<void> pumpSettings(
  WidgetTester tester, {
  Size size = const Size(480, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: SettingsPage(device: TestAppDevice(), backup: TestBackup()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pushSettings(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(480, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('host-open-settings'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    device: TestAppDevice(),
                    backup: TestBackup(),
                  ),
                ),
              ),
              child: const Text('打开设置'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('host-open-settings')));
  await tester.pumpAndSettle();
}

Future<void> openEditor(WidgetTester tester) async {
  final entry = find.byKey(_entry);
  await tester.ensureVisible(entry);
  await tester.pumpAndSettle();
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('外观模型', () {
    test('默认值与完整字段往返，未知多余字段忽略', () {
      final defaults = TodayWidgetAppearance.defaults;
      expect(TodayWidgetAppearance.fromMap(defaults.toMap()), defaults);
      expect(defaults.toMap()['version'], 2);
      expect(defaults.toMap().length, 17);

      final custom = defaults.copyWith(
        style: TodayWidgetStyle.indexCard,
        theme: TodayWidgetTheme.dark,
        headerSp: 17,
        taskSp: 20,
        metaSp: 16,
        horizontalPaddingDp: 16,
        verticalPaddingDp: 12,
        rowPaddingDp: 9,
        rowGapDp: 8,
        radiusDp: 8,
        showDetails: false,
        timeMode: TodayWidgetTimeMode.none,
        showStatus: false,
        showDate: false,
        showMore: false,
        rowLimit: 1,
      );
      expect(TodayWidgetAppearance.fromMap(custom.toMap()), custom);
      expect(custom.toMap()['style'], 'index');
      expect(custom.toMap()['timeMode'], 'none');
      expect(custom.copyWith(), custom);

      final tolerant = appearanceMap({'futureField': 'ignored'});
      expect(TodayWidgetAppearance.fromMap(tolerant), defaults);
    });

    test('风格预设映射到完整草稿组合且不增加持久化字段', () {
      final custom = TodayWidgetAppearance.defaults.copyWith(
        taskSp: 18,
        showDate: false,
      );
      final timeline = TodayWidgetPreset.timeline.applyTo(custom);
      expect(timeline.style, TodayWidgetStyle.timeline);
      expect(timeline.theme, TodayWidgetTheme.light);
      expect(timeline.taskSp, 13);
      expect(timeline.showDate, isTrue);
      expect(timeline.toMap().length, 17);
      expect(timeline.matchingPreset, TodayWidgetPreset.timeline);
      expect(
        TodayWidgetPreset.darkForest.applyTo(custom).theme,
        TodayWidgetTheme.dark,
      );
    });

    test('非整数、未知枚举、越界与非法版本都抛出 FormatException', () {
      final invalid = <Map<String, Object?>>[
        {...appearanceMap(), 'version': 1},
        {...appearanceMap(), 'version': 3},
        {...appearanceMap()}..remove('version'),
        appearanceMap({'style': 'unknown'}),
        appearanceMap({'theme': 'auto'}),
        appearanceMap({'timeMode': 'end'}),
        appearanceMap({'headerSp': 10}),
        appearanceMap({'taskSp': 21}),
        appearanceMap({'metaSp': 9}),
        appearanceMap({'horizontalPaddingDp': 7}),
        appearanceMap({'verticalPaddingDp': 13}),
        appearanceMap({'rowPaddingDp': 10}),
        appearanceMap({'rowGapDp': 9}),
        appearanceMap({'radiusDp': 10}),
        appearanceMap({'rowLimit': 6}),
        appearanceMap({'headerSp': '12'}),
        appearanceMap({'headerSp': null}),
        appearanceMap({'showDetails': 'yes'}),
      ];
      for (final map in invalid) {
        expect(
          () => TodayWidgetAppearance.fromMap(map),
          throwsFormatException,
          reason: '$map',
        );
      }
    });

    test('预览计划解析颜色、度量、行、空态与示例标记', () {
      final preview = TodayWidgetPreview.fromMap(previewEnvelope());
      expect(preview.sizeClass, TodayWidgetSizeClass.medium);
      expect(preview.sizeSource, TodayWidgetSizeSource.reference);
      expect(preview.widthDp, 220);
      expect(preview.heightDp, 109);
      expect(preview.theme, TodayWidgetTheme.light);
      expect(preview.style, TodayWidgetStyle.paper);
      expect(preview.colors.surface, 0xFFF7F8F5.toSigned(32));
      expect(preview.metrics.radius, 16);
      expect(preview.metrics.rowHeight, 32);
      expect(preview.header.left, '今日任务');
      expect(preview.rows, hasLength(2));
      expect(preview.rows.first.title, '品牌与营销管理实务');
      expect(preview.rows.first.progress, '计划时段剩余 91 分钟');
      expect(preview.rows.first.titleMaxLines, 1);
      expect(preview.footer.kind, TodayWidgetPreviewFooterKind.more);
      expect(preview.empty, TodayWidgetPreviewEmpty.none);
      expect(preview.overflow, TodayWidgetPreviewOverflow.none);
      expect(preview.rowLayout, TodayWidgetPreviewRowLayout.stacked);
      expect(preview.spineVisible, isFalse);
      expect(preview.dividerVisible, isTrue);
      expect(preview.sample, isTrue);

      expect(
        () => TodayWidgetPreview.fromMap(previewEnvelope(theme: 'system')),
        throwsFormatException,
      );
      expect(
        () => TodayWidgetPreview.fromMap({
          ...previewEnvelope(),
          'metrics': <String, Object?>{},
        }),
        throwsFormatException,
      );
      expect(
        () => TodayWidgetPreview.fromMap({
          ...previewEnvelope(),
          'empty': 'loading',
        }),
        throwsFormatException,
      );
      expect(
        () => TodayWidgetPreview.fromMap({
          ...previewEnvelope(),
          'rowLayout': 'triSlot',
        }),
        throwsFormatException,
      );
      for (final field in ['rowLayout', 'spineVisible', 'dividerVisible']) {
        final map = previewEnvelope()..remove(field);
        expect(
          () => TodayWidgetPreview.fromMap(map),
          throwsFormatException,
          reason: '缺少 $field 必须整体拒绝',
        );
      }
    });
  });

  group('外观编辑器', () {
    testWidgets('读取迁移回执并显示恢复提示与迁移后的值', (tester) async {
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope(
              appearance: appearanceMap({'headerSp': 15, 'taskSp': 15}),
              recovered: true,
              source: 'migrated',
            );
          case 'previewAppearance':
            return previewEnvelope();
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      await openEditor(tester);

      expect(find.byKey(const Key('today-widget-load-notice')), findsOneWidget);
      expect(find.textContaining('已从旧版颜色和文字大小迁移'), findsOneWidget);
      expect(find.textContaining('已恢复为默认外观'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('today-widget-headerSp-value')))
            .data,
        '15sp',
      );
      expect(find.byKey(_surface), findsOneWidget);
      expect(find.text('示例数据'), findsOneWidget);
      expect(find.textContaining('参考尺寸 220 × 109 dp'), findsOneWidget);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('读取失败给出重试，重试成功后加载编辑器', (tester) async {
      var reads = 0;
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            if (reads++ == 0) return null;
            return getEnvelope();
          case 'previewAppearance':
            return previewEnvelope();
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      await openEditor(tester);

      expect(find.byKey(const Key('today-widget-load-error')), findsOneWidget);
      await tester.tap(find.byKey(const Key('today-widget-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today-widget-load-error')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('today-widget-headerSp-value')))
            .data,
        '12sp',
      );
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('预览回执缺少新增字段时显示可重试错误，不静默推断', (tester) async {
      var previews = 0;
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope();
          case 'previewAppearance':
            previews++;
            if (previews == 1) {
              return previewEnvelope()
                ..remove('rowLayout')
                ..remove('spineVisible')
                ..remove('dividerVisible');
            }
            return previewEnvelope();
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      await openEditor(tester);
      expect(
        find.byKey(const Key('today-widget-preview-error')),
        findsOneWidget,
      );
      expect(find.text('暂时无法生成预览，请重试。'), findsOneWidget);
      expect(find.byKey(_surface), findsNothing);
      await tester.tap(find.byKey(const Key('today-widget-preview-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today-widget-preview-error')), findsNothing);
      expect(find.byKey(_surface), findsOneWidget);
      expect(previews, 2);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('保存回执四态：成功、部分失败后重绘、失败与无实例', (tester) async {
      var widgetsState = 'requested';
      final writes = <Map<Object?, Object?>>[];
      var redraws = 0;
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope();
          case 'previewAppearance':
            return previewEnvelope();
          case 'setAppearance':
            final appearance = _nestedMap(_arguments(call)['appearance']);
            writes.add(appearance);
            return {'appearance': appearance, 'widgets': widgetsState};
          case 'redrawWidgets':
            redraws++;
            return {'widgets': widgetsState};
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      await openEditor(tester);

      await tapVisible(tester, find.byKey(_styleIndex));
      await tapVisible(tester, find.byKey(_save));
      expect(writes, hasLength(1));
      expect(writes.single['version'], 2);
      expect(writes.single['style'], 'index');
      expect(find.text('已保存'), findsWidgets);
      expect(
        find.byKey(const Key('today-widget-widgets-warning')),
        findsNothing,
      );

      widgetsState = 'partialFailure';
      await tapVisible(tester, find.byKey(_themeDark));
      await tapVisible(tester, find.byKey(_save));
      expect(writes, hasLength(2));
      expect(writes.last['theme'], 'dark');
      expect(
        find.byKey(const Key('today-widget-widgets-warning')),
        findsOneWidget,
      );
      widgetsState = 'requested';
      await tapVisible(tester, find.byKey(const Key('today-widget-redraw')));
      expect(redraws, 1);
      expect(
        find.byKey(const Key('today-widget-widgets-warning')),
        findsNothing,
      );

      widgetsState = 'failed';
      await tapVisible(tester, find.byKey(_showStatus));
      await tapVisible(tester, find.byKey(_save));
      expect(
        find.byKey(const Key('today-widget-widgets-warning')),
        findsOneWidget,
      );
      expect(find.text('已保存，桌面暂未更新'), findsOneWidget);

      widgetsState = 'noInstances';
      await tapVisible(tester, find.byKey(_showStatus));
      await tapVisible(tester, find.byKey(_save));
      expect(
        find.byKey(const Key('today-widget-widgets-warning')),
        findsNothing,
      );
      expect(find.text('已保存，尚未添加桌面小组件'), findsOneWidget);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('保存失败保留草稿并显示服务端消息', (tester) async {
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope();
          case 'previewAppearance':
            return previewEnvelope();
          case 'setAppearance':
            throw PlatformException(
              code: 'invalidAppearance',
              message: '任务名超出允许范围',
            );
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      await openEditor(tester);

      await tapVisible(
        tester,
        find.byKey(const Key('today-widget-taskSp-plus')),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('today-widget-taskSp-value')))
            .data,
        '13sp',
      );
      await tapVisible(tester, find.byKey(_save));
      expect(find.byKey(const Key('today-widget-save-error')), findsOneWidget);
      expect(find.textContaining('任务名超出允许范围'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('today-widget-taskSp-value')))
            .data,
        '13sp',
      );
      expect(
        tester.widget<FilledButton>(find.byKey(_save)).onPressed,
        isNotNull,
      );
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('切换尺寸与浅深示例只刷新预览，不保存也不改草稿', (tester) async {
      final previews = <Map<Object?, Object?>>[];
      var saves = 0;
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope();
          case 'previewAppearance':
            final arguments = _arguments(call);
            previews.add(arguments);
            final size = arguments['sizeClass'];
            final theme = arguments['theme'];
            return previewEnvelope(
              sizeClass: size is String ? size : 'medium',
              theme: theme is String ? theme : 'light',
              heightDp: size == 'large' ? 220 : 109,
            );
          case 'setAppearance':
            saves++;
            return {'appearance': appearanceMap(), 'widgets': 'requested'};
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      await openEditor(tester);
      expect(previews, isNotEmpty);
      final initialPreview = tester.widget<SizedBox>(find.byKey(_surface));
      expect(
        initialPreview.width! / initialPreview.height!,
        closeTo(220 / 109, .01),
      );

      await tapVisible(tester, find.byKey(_previewLarge));
      expect(previews.last['sizeClass'], 'large');
      final largePreview = tester.widget<SizedBox>(find.byKey(_surface));
      expect(largePreview.width, largePreview.height);
      expect(tester.widget<Text>(find.byKey(_status)).data, '已是最新');

      await tapVisible(tester, find.byKey(_previewDark));
      expect(previews.last['theme'], 'dark');
      expect(saves, 0);
      expect(tester.widget<Text>(find.byKey(_status)).data, '已是最新');
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('连续改数值合并预览请求，latest-wins 丢弃旧回执', (tester) async {
      final previews = <Completer<Object?>>[];
      var saves = 0;
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope();
          case 'previewAppearance':
            final completer = Completer<Object?>();
            previews.add(completer);
            return completer.future;
          case 'setAppearance':
            saves++;
            return {'appearance': appearanceMap(), 'widgets': 'requested'};
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      final entry = find.byKey(_entry);
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pump();
      await tester.pump();
      expect(previews, hasLength(1));

      final plus = find.byKey(const Key('today-widget-headerSp-plus'));
      await tester.ensureVisible(plus);
      await tester.pump();
      await tester.tap(plus);
      await tester.tap(plus);
      await tester.tap(plus);
      await tester.pump();
      expect(previews, hasLength(1), reason: '防抖期间不重复请求');
      await tester.pump(const Duration(milliseconds: 150));
      expect(previews, hasLength(2), reason: '连续改动合并成一次请求');
      expect(
        tester
            .widget<Text>(find.byKey(const Key('today-widget-headerSp-value')))
            .data,
        '15sp',
      );

      previews.last.complete(
        previewEnvelope(widthDp: 220, heightDp: 220, sizeClass: 'large'),
      );
      await tester.pump();
      await tester.pump();
      final latestPreview = tester.widget<SizedBox>(find.byKey(_surface));
      expect(latestPreview.width, latestPreview.height);

      previews.first.complete(previewEnvelope());
      await tester.pump();
      await tester.pump();
      final afterOldReply = tester.widget<SizedBox>(find.byKey(_surface));
      expect(afterOldReply.width, afterOldReply.height, reason: '旧回执不能覆盖新计划');
      expect(saves, 0);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('保存中防重入，成功后就地反馈不退出', (tester) async {
      final result = Completer<Object?>();
      var writes = 0;
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope();
          case 'previewAppearance':
            return previewEnvelope();
          case 'setAppearance':
            writes++;
            return result.future;
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      await openEditor(tester);
      await tapVisible(tester, find.byKey(_styleMinimal));
      await tester.ensureVisible(find.byKey(_save));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_save));
      await tester.pump();
      await tester.tap(find.byKey(_save), warnIfMissed: false);
      await tester.pump();
      expect(writes, 1);
      expect(find.text('保存中…'), findsWidgets);

      result.complete({
        'appearance': appearanceMap({'style': 'minimal'}),
        'widgets': 'requested',
      });
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.byKey(_close), findsOneWidget);
      expect(find.text('已保存'), findsWidgets);
      expect(tester.widget<Text>(find.byKey(_status)).data, '已保存');
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('收起编辑器与顶栏返回都会确认未保存草稿', (tester) async {
      var loads = 0;
      var saves = 0;
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            loads++;
            return getEnvelope();
          case 'previewAppearance':
            return previewEnvelope();
          case 'setAppearance':
            saves++;
            return {'appearance': appearanceMap(), 'widgets': 'requested'};
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pushSettings(tester);
      await openEditor(tester);

      await tapVisible(tester, find.byKey(_styleIndex));
      await tester.ensureVisible(find.byKey(_close));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_close));
      await tester.pumpAndSettle();
      expect(find.text('放弃小组件外观修改？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(find.byKey(_close), findsOneWidget);

      await tester.ensureVisible(find.byKey(_close));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃修改'));
      await tester.pumpAndSettle();
      expect(find.byKey(_close), findsNothing);
      expect(find.byKey(_entry), findsOneWidget);
      expect(saves, 0);

      await openEditor(tester);
      expect(loads, 2);
      final selected = tester.widget<TextButton>(find.byKey(_styleIndex));
      expect(selected.onPressed, isNotNull);

      await tapVisible(tester, find.byKey(_styleIndex));
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('放弃小组件外观修改？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(find.byKey(_entry), findsOneWidget);

      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃修改'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('host-open-settings')), findsOneWidget);
      expect(find.byKey(_entry), findsNothing);
      expect(saves, 0);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('恢复默认只改草稿，不写通道', (tester) async {
      var saves = 0;
      var previews = 0;
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope(appearance: appearanceMap({'headerSp': 15}));
          case 'previewAppearance':
            previews++;
            return previewEnvelope();
          case 'setAppearance':
            saves++;
            return {'appearance': appearanceMap(), 'widgets': 'requested'};
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      await openEditor(tester);
      final before = previews;
      await tapVisible(tester, find.byKey(const Key('today-widget-reset')));
      expect(
        tester
            .widget<Text>(find.byKey(const Key('today-widget-headerSp-value')))
            .data,
        '12sp',
      );
      expect(saves, 0);
      expect(previews, greaterThan(before));
      expect(tester.widget<Text>(find.byKey(_status)).data, '有未保存的修改');
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('关闭详细信息后保留时间与阶段选值，再开启仍可保存这些值', (tester) async {
      final writes = <Map<Object?, Object?>>[];
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope();
          case 'previewAppearance':
            return previewEnvelope();
          case 'setAppearance':
            final appearance = _nestedMap(_arguments(call)['appearance']);
            writes.add(appearance);
            return {'appearance': appearance, 'widgets': 'requested'};
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      await openEditor(tester);

      await tapVisible(tester, find.byKey(_showStatus));
      await tapVisible(tester, find.byKey(_showDate));
      await tapVisible(
        tester,
        find.byKey(const Key('today-widget-showDetails')),
      );
      // 关闭详细信息后仍可调整时间方式（值保留，重新开启时继续生效）。
      await tapVisible(tester, find.byKey(const Key('today-widget-time-none')));
      await tapVisible(
        tester,
        find.byKey(const Key('today-widget-showDetails')),
      );
      await tapVisible(tester, find.byKey(_save));
      expect(writes, hasLength(1));
      expect(writes.single['showDetails'], isTrue);
      expect(writes.single['timeMode'], 'none');
      expect(writes.single['showStatus'], isFalse);
      expect(writes.single['showDate'], isFalse);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('切换样式保留已调字号与显示开关', (tester) async {
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope();
          case 'previewAppearance':
            return previewEnvelope();
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester);
      await openEditor(tester);
      expect(
        tester.widget<FilledButton>(find.byKey(_save)).onPressed,
        isNull,
        reason: '没有改动时不能保存',
      );

      await tapVisible(
        tester,
        find.byKey(const Key('today-widget-headerSp-plus')),
      );
      await tapVisible(tester, find.byKey(_showStatus));
      await tapVisible(tester, find.byKey(_styleIndex));
      expect(
        tester
            .widget<Text>(find.byKey(const Key('today-widget-headerSp-value')))
            .data,
        '13sp',
      );
      expect(tester.widget<Switch>(find.byKey(_showStatus)).value, isFalse);
      expect(
        tester.widget<FilledButton>(find.byKey(_save)).onPressed,
        isNotNull,
      );
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('预览空态和溢出提示来自回执', (tester) async {
      final preview = TodayWidgetPreview.fromMap(
        previewEnvelope(
          sizeClass: 'small',
          widthDp: 109,
          heightDp: 109,
          rows: const [],
          headerVisible: true,
          empty: 'waiting',
          overflow: 'headerOnly',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TodayWidgetPreviewPane(
                preview: preview,
                sizeClass: TodayWidgetSizeClass.small,
                exampleTheme: TodayWidgetTheme.light,
                loading: false,
                error: null,
                onSizeClassChanged: (_) {},
                onExampleThemeChanged: (_) {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('空间不足，仅保留题头入口'), findsOneWidget);
      expect(find.text('示例数据'), findsOneWidget);
      expect(find.textContaining('参考尺寸 109 × 109 dp'), findsOneWidget);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('非 Android 不展示入口且不调用外观通道', (tester) async {
      final calls = <String>[];
      mockWidgetChannel(tester, (call) async {
        calls.add(call.method);
        return getEnvelope();
      });
      await pumpSettings(tester);
      expect(find.byKey(_entry), findsNothing);
      expect(calls, isEmpty);
    }, variant: const TargetPlatformVariant({TargetPlatform.windows}));

    testWidgets('宽窗口左预览右设置', (tester) async {
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope();
          case 'previewAppearance':
            return previewEnvelope();
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester, size: const Size(1100, 1200));
      await openEditor(tester);
      final widePreview = find.byKey(const Key('today-widget-preview-frame'));
      final wideForm = find.byKey(_styleIndex);
      expect(widePreview, findsOneWidget);
      expect(wideForm, findsOneWidget);
      expect(
        tester.getTopLeft(wideForm).dx,
        greaterThan(tester.getTopLeft(widePreview).dx),
      );
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('窄窗口预览与设置纵排', (tester) async {
      mockWidgetChannel(tester, (call) async {
        switch (call.method) {
          case 'getAppearance':
            return getEnvelope();
          case 'previewAppearance':
            return previewEnvelope();
          default:
            throw MissingPluginException(call.method);
        }
      });
      await pumpSettings(tester, size: const Size(480, 900));
      await openEditor(tester);
      final narrowPreview = find.byKey(const Key('today-widget-preview-frame'));
      final narrowForm = find.byKey(_styleIndex);
      expect(narrowPreview, findsOneWidget);
      expect(narrowForm, findsOneWidget);
      expect(
        tester.getTopLeft(narrowForm).dy,
        greaterThan(tester.getTopLeft(narrowPreview).dy),
      );
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));
  });

  testWidgets('预览画布直接显示原生渲染回执', (tester) async {
    final preview = TodayWidgetPreview.fromMap(
      previewEnvelope(sizeClass: 'medium', widthDp: 220, heightDp: 109),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: TodayWidgetPreviewCanvas(preview: preview),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(_surface), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
  });

  testWidgets('预览画布按回执的真实宽高比、圆角与行绘制', (tester) async {
    final preview = TodayWidgetPreview.fromMap(
      previewEnvelope(
        sizeClass: 'large',
        widthDp: 220,
        heightDp: 220,
        theme: 'dark',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: TodayWidgetPreviewCanvas(preview: preview),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = tester.widget<SizedBox>(find.byKey(_surface));
    expect(surface.width, surface.height);
    expect(surface.width, lessThanOrEqualTo(280));
    expect(find.byType(Image), findsOneWidget);
  });
}
