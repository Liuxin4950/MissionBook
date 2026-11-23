import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/notifications/today_widget_bridge.dart';
import 'package:mission_book/data/settings/today_widget_appearance.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:timezone/data/latest.dart' as tzdata;

ScheduledMission widgetMission(
  String id, {
  MissionPhase phase = MissionPhase.notStarted,
  DateTime? start,
}) {
  final now = DateTime.utc(2026, 11, 22);
  return ScheduledMission(
    phase: phase,
    mission: Mission(id: id, title: '任务 $id', createdAt: now, updatedAt: now),
    schedule: MissionScheduleRevision(
      id: '$id-schedule',
      missionId: id,
      revisionNumber: 1,
      scheduledDate: '2026-11-23',
      timeZone: 'Asia/Shanghai',
      timePolicy: start == null ? TimePolicy.flexible : TimePolicy.fixed,
      fixedStartAt: start,
      plannedDurationMinutes: 40,
      changedAt: now,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);

  test('快照按上海日界读取今天和明天，并排除取消任务', () async {
    final calls = <String>[];
    final json = await buildTodayWidgetSnapshot(
      now: DateTime.utc(2026, 11, 22, 16), // Shanghai 2026-11-23 00:00
      query: (date) async {
        calls.add(date);
        return date == '2026-11-23'
            ? [
                widgetMission('a', start: DateTime.utc(2026, 11, 23, 1)),
                widgetMission('b', phase: MissionPhase.cancelled),
              ]
            : [widgetMission('tomorrow')];
      },
    );
    final data = jsonDecode(json) as Map<String, dynamic>;
    expect(calls, ['2026-11-23', '2026-11-24']);
    expect((data['days'] as List).length, 2);
    expect((data['days'][0]['total']), 1);
    expect(data['days'][0]['rows'][0]['start'], '09:00');
    expect(data['days'][1]['total'], 1);
  });

  test('自选任务不伪造固定时间，保留派生阶段文本', () async {
    final json = await buildTodayWidgetSnapshot(
      now: DateTime.utc(2026, 11, 22, 1),
      query: (_) async => [
        widgetMission('x', phase: MissionPhase.reportPending),
      ],
    );
    final row = (jsonDecode(json)['days'][0]['rows'] as List).single;
    expect(row['start'], isNull);
    expect(row['end'], isNull);
    expect(row['phase'], 'reportPending');
  });

  group('外观通道', () {
    Map<String, Object?> appearance() => {
      ...TodayWidgetAppearance.defaults.toMap(),
      'headerSp': 15,
    };

    void mockWidgetChannel(Future<Object?> Function(MethodCall call) handler) {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(TodayWidgetBridge.channel, handler);
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(TodayWidgetBridge.channel, null),
      );
    }

    test('读取、保存、重绘与预览都使用契约方法名和参数', () async {
      final calls = <MethodCall>[];
      mockWidgetChannel((call) async {
        calls.add(call);
        switch (call.method) {
          case 'getAppearance':
            return {
              'version': 2,
              'appearance': appearance(),
              'defaults': TodayWidgetAppearance.defaults.toMap(),
              'recovered': false,
              'source': 'v2',
            };
          case 'setAppearance':
            return {'appearance': appearance(), 'widgets': 'partialFailure'};
          case 'redrawWidgets':
            return {'widgets': 'requested'};
          case 'previewAppearance':
            return {
              'version': 2,
              'sizeClass': 'medium',
              'rowLayout': 'wide',
              'spineVisible': false,
              'dividerVisible': true,
            };
          default:
            throw MissingPluginException(call.method);
        }
      });

      final read = await TodayWidgetBridge.getAppearance();
      expect(read['version'], 2);
      expect((read['appearance'] as Map<Object?, Object?>)['headerSp'], 15);

      final saved = await TodayWidgetBridge.setAppearance(appearance());
      expect(saved['widgets'], 'partialFailure');

      final redrawn = await TodayWidgetBridge.redrawWidgets();
      expect(redrawn['widgets'], 'requested');

      final preview = await TodayWidgetBridge.previewAppearance(
        appearance: appearance(),
        sizeClass: 'large',
        theme: 'dark',
      );
      expect(preview['sizeClass'], 'medium');
      expect(preview['rowLayout'], 'wide');
      expect(preview['spineVisible'], isFalse);
      expect(preview['dividerVisible'], isTrue);

      expect(calls.map((call) => call.method), [
        'getAppearance',
        'setAppearance',
        'redrawWidgets',
        'previewAppearance',
      ]);
      expect(calls[1].arguments, {'appearance': appearance()});
      expect(calls[2].arguments, isNull);
      expect(calls[3].arguments, {
        'appearance': appearance(),
        'sizeClass': 'large',
        'theme': 'dark',
      });
    });

    test('空回执不伪装成默认值，抛 FormatException 供界面重试', () async {
      mockWidgetChannel((_) async => null);
      await expectLater(
        TodayWidgetBridge.getAppearance(),
        throwsFormatException,
      );
    });

    test('原生拒绝写入时保留 PlatformException', () async {
      mockWidgetChannel(
        (_) async => throw PlatformException(
          code: 'invalidAppearance',
          message: '不支持的小组件外观',
        ),
      );
      await expectLater(
        TodayWidgetBridge.setAppearance(appearance()),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'invalidAppearance',
          ),
        ),
      );
    });
  });
}
