import 'dart:convert';
import 'package:agent_core/agent_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:mission_book/application/assistant/assistant_tool_result.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);
  Map<String, Object?> format(Map<String, Object?> value) =>
      (jsonDecode(
                AssistantToolResultFormatter(
                  clock: () => DateTime.utc(2026, 11, 2, 18),
                ).format(ToolOutput.success(jsonEncode(value))).text,
              )
              as Map)
          .cast<String, Object?>();

  test('毫秒、ISO 时刻与撤销历史统一转换，日期时长和ID不变且不改原数据', () {
    final epoch = DateTime.utc(2026, 11, 2, 18).millisecondsSinceEpoch;
    final original = <String, Object?>{
      'createdAt': epoch,
      'scheduledDate': '2026-11-02',
      'durationSeconds': epoch,
      'id': '$epoch',
      'capturedAt': null,
      'items': [
        {'occurred_at': epoch, 'updatedAt': '2026-11-02T18:00:00.000Z'},
      ],
    };
    final result = format(original);
    expect(result['createdAt'], '2026-11-03T02:00:00.000+08:00');
    expect(
      (result['items'] as List).single['occurred_at'],
      result['createdAt'],
    );
    expect((result['items'] as List).single['updatedAt'], result['createdAt']);
    expect((result['timeContext'] as Map)['today'], '2026-11-03');
    expect(result['scheduledDate'], '2026-11-02');
    expect(result['durationSeconds'], epoch);
    expect(result['id'], '$epoch');
    expect(result['capturedAt'], isNull);
    expect(original['createdAt'], epoch);
  });
  test('条目继承自身时区并按实际夏令时偏移转换，同一时间前后回拨不混淆', () {
    final result = format({
      'timeZone': 'America/New_York',
      'items': [
        {'occurredAt': '2026-11-01T05:30:00Z'},
        {'occurredAt': '2026-11-01T06:30:00Z'},
        {'timeZone': 'Asia/Tokyo', 'actualStart': '2026-11-02T18:00:00Z'},
      ],
    });
    final items = result['items'] as List;
    expect(items[0]['occurredAt'], '2026-11-01T01:30:00.000-04:00');
    expect(items[1]['occurredAt'], '2026-11-01T01:30:00.000-05:00');
    expect(items[2]['actualStart'], '2026-11-03T03:00:00.000+09:00');
  });
  test('失败与非JSON结果原样返回，无效时区以UTC呈现已提交结果', () {
    final formatter = AssistantToolResultFormatter();
    final failure = ToolOutput.failure('conflict', '范围已变化');
    expect(identical(formatter.format(failure), failure), isTrue);
    const plain = ToolOutput.success('完成');
    expect(identical(formatter.format(plain), plain), isTrue);
    expect(
      format({'timeZone': 'invalid', 'createdAt': 0})['createdAt'],
      '1970-01-01T00:00:00.000+00:00',
    );
  });
}
