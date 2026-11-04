import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/notifications/xiaomi_execution_payload.dart';
import 'package:mission_book/domain/notifications/reminder_request.dart';

void main() {
  final at = DateTime.utc(2026, 11, 4, 10);
  ReminderRequest request(
    ReminderKind kind, {
    bool clockBehind = false,
    int budgetMinutes = 45,
  }) => ReminderRequest(
    idempotencyKey: 'mission-test-execution',
    notificationId: 42,
    missionId: 'test',
    scheduleRevisionId: 'schedule',
    kind: kind,
    title: '高数课',
    body: '任务事实摘要',
    expectedSequence: 3,
    candidateEventIds: const {'pause': 'pause', 'resume': 'resume'},
    focusMilliseconds: 75_000,
    projectedAt: at,
    budgetMinutes: budgetMinutes,
    clockBehind: clockBehind,
  );

  test('展开态与摘要态共用扣除暂停后的专注起点，系统正计时', () {
    final payload = xiaomiExecutionPayload(
      request(ReminderKind.executionRunning),
    );
    final params = payload['param_v2'] as Map;
    final highlight = params['highlightInfo'] as Map;
    final island = params['param_island'] as Map;
    final digits =
        (island['bigIslandArea'] as Map)['sameWidthDigitInfo'] as Map;
    expect(highlight['timerInfo'], {
      'timerType': 1,
      'timerWhen': at.millisecondsSinceEpoch - 75_000,
      'timerTotal': 75_000,
      'timerSystemCurrent': at.millisecondsSinceEpoch,
    });
    expect(digits['timerInfo'], highlight['timerInfo']);
    expect(highlight.containsKey('title'), isFalse);
    expect(params['filterWhenNoPermission'], isFalse);
    expect(params['enableFloat'], isFalse);
  });

  for (final (kind, state, hasAction) in [
    (ReminderKind.executionPaused, '已暂停', true),
    (ReminderKind.executionStopped, '待确认', false),
  ]) {
    test('$state 显示冻结数字，动作与原执行通知一致', () {
      final params = xiaomiExecutionPayload(request(kind))['param_v2'] as Map;
      final highlight = params['highlightInfo'] as Map;
      final island = params['param_island'] as Map;
      final digits =
          (island['bigIslandArea'] as Map)['sameWidthDigitInfo'] as Map;
      expect(highlight['title'], '01:15');
      expect(highlight['subContent'], state);
      expect(highlight.containsKey('timerInfo'), isFalse);
      expect(digits, {'digit': '01:15'});
      expect(params.containsKey('actions'), hasAction);
    });
  }

  test('时钟回拨不伪造连续计时，仍保留原动作入口', () {
    final params =
        xiaomiExecutionPayload(
              request(ReminderKind.executionRunning, clockBehind: true),
            )['param_v2']
            as Map;
    final highlight = params['highlightInfo'] as Map;
    expect(highlight['subContent'], '请校时');
    expect(highlight['title'], '01:15');
    expect(highlight.containsKey('timerInfo'), isFalse);
    expect(params['actions'], hasLength(1));
  });

  test('长课不使用一小时默认过期时间，通知与岛的存活期一致', () {
    final params =
        xiaomiExecutionPayload(
              request(ReminderKind.executionRunning, budgetMinutes: 120),
            )['param_v2']
            as Map;
    final seconds = (params['param_island'] as Map)['islandTimeout'] as int;
    expect(seconds, greaterThanOrEqualTo(120 * 60));
    expect(seconds, (params['timeout'] as int) * 60);
  });
}
