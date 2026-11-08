import '../../domain/notifications/reminder_request.dart';

/// 将同一执行摘要投影为澎湃 OS 3 的计时模板；系统走秒，不逐秒发送通知。
Map<String, Object?> xiaomiExecutionPayload(ReminderRequest request) {
  final focus = request.focusMilliseconds;
  final at = request.projectedAt;
  if (focus == null || at == null) {
    throw ArgumentError('超级岛计时需要完整的执行摘要');
  }
  final running = request.kind == ReminderKind.executionRunning;
  final advancing = running && !request.clockBehind;
  final state = request.clockBehind
      ? '请校时'
      : running
      ? '执行中'
      : request.kind == ReminderKind.executionStopped
      ? '待确认'
      : '已暂停';
  final seconds = focus ~/ 1000;
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = seconds >= 3600
      ? '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}'
      : '${two(seconds ~/ 60)}:${two(seconds % 60)}';
  final timer = <String, Object?>{
    'timerType': 1, // 官方模板的正计时；起点扣除累计暂停后的专注时长。
    'timerWhen': at.millisecondsSinceEpoch - focus,
    'timerTotal': focus,
    'timerSystemCurrent': at.millisecondsSinceEpoch,
  };
  const icon = 'miui.focus.pic_execution';
  // 岛默认只保留一小时；长课不能在仍计时时提前消失，终态仍由业务主动撤销。
  const minimumLifetimeMinutes = 12 * 60; // 沿用焦点通知默认的十二小时存活期。
  const maximumLifetimeMinutes = 0x7fffffff ~/ 60; // 岛的秒数是 32 位整数。
  final lifetimeMinutes = ((request.budgetMinutes ?? 0) + 60).clamp(
    minimumLifetimeMinutes,
    maximumLifetimeMinutes,
  );
  final hasAction =
      request.kind == ReminderKind.executionRunning ||
      request.kind == ReminderKind.executionPaused;
  return {
    'param_v2': {
      'protocol': 1,
      'business': 'mission_execution',
      'updatable': true,
      'timeout': lifetimeMinutes,
      'reopen': 'reopen',
      'enableFloat': false,
      'islandFirstFloat': false,
      'filterWhenNoPermission': false,
      'aodTitle': '${request.title} · $state',
      'ticker': '$state · $clock',
      'highlightInfo': {
        if (advancing) 'timerInfo': timer else 'title': clock,
        'picFunction': icon,
        'content': request.title,
        'subContent': state,
      },
      'picInfo': {'type': 1},
      if (hasAction)
        'actions': [
          {'action': 'miui.focus.action_primary'},
        ],
      'param_island': {
        'islandProperty': 1,
        'islandTimeout': lifetimeMinutes * 60,
        'bigIslandArea': {
          'imageTextInfoLeft': {
            'type': 1,
            'picInfo': {'type': 1, 'pic': icon},
            'textInfo': {'title': state},
          },
          'sameWidthDigitInfo': {
            if (advancing) 'timerInfo': timer else 'digit': clock,
          },
        },
        'smallIslandArea': {
          'picInfo': {'type': 1, 'pic': icon},
        },
      },
    },
  };
}
