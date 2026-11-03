/// 对已持久化的历史补记回执分页；汇总始终覆盖完整范围。
Map<String, Object?> maintenanceOperationPage(
  Map<String, Object?> result,
  int offset,
) {
  if (offset < 0) throw ArgumentError('分页位置无效');
  final changed = result['missionIds'] as List? ?? const [];
  final skipped = result['skippedIds'] as List? ?? const [];
  final items = [
    for (final id in changed) {'missionId': id, 'status': 'changed'},
    for (final id in skipped) {'missionId': id, 'status': 'skipped'},
  ];
  final page = items.skip(offset).take(20).toList();
  final next = offset + page.length;
  return {
    'status': result['status'],
    'action': result['action'],
    'operationId': result['operationId'],
    'counts': {
      'changed': changed.length,
      'skipped': skipped.length,
      'total': items.length,
    },
    'items': page,
    'page': {
      'offset': offset,
      'complete': next >= items.length,
      if (next < items.length) 'nextOffset': next,
    },
  };
}

/// 对已持久化的历史补记回执分页；汇总始终覆盖完整范围。
Map<String, Object?> historyOperationPage(
  Map<String, Object?> result,
  int offset,
) {
  if (offset < 0) throw ArgumentError('分页位置无效');
  final issues = (result['issues'] as List?) ?? const [];
  final page = issues.skip(offset).take(20).toList();
  final next = offset + page.length;
  return {
    ...result,
    'issues': page,
    'page': {
      'offset': offset,
      'complete': next >= issues.length,
      if (next < issues.length) 'nextOffset': next,
    },
  };
}

/// 计划回执的完整条目保存在本地，模型按需分页读取。
Map<String, Object?> planOperationPage(
  Map<String, Object?> result,
  int offset,
) {
  if (offset < 0) throw ArgumentError('分页位置无效');
  final blocked = result['status'] == 'blocked';
  final key = blocked ? 'issues' : 'items';
  final items = (result[key] as List?) ?? const [];
  final page = items.skip(offset).take(20).toList();
  final next = offset + page.length;
  final compact = Map<String, Object?>.from(result)
    ..remove('references')
    ..remove('ok')
    ..remove('operation')
    ..remove('planId')
    ..remove('savedCount');
  return {
    ...compact,
    'status': blocked ? 'blocked' : 'success',
    'operationId': result['operationId'] ?? result['planId'],
    'counts':
        result['counts'] ??
        {'requested': items.length, 'changed': items.length},
    key: page,
    'page': {
      'offset': offset,
      'complete': next >= items.length,
      if (next < items.length) 'nextOffset': next,
    },
  };
}
