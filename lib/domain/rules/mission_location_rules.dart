/// 地点是任务的可选单行文字，和固定/自选时间策略相互独立。
const maxMissionLocationLength = 200;

/// 统一手工、助手和导入的地点输入；空白表示没有记录地点。
String? normalizeMissionLocation(String? value) {
  final text = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text == null || text.isEmpty) return null;
  if (text.runes.length > maxMissionLocationLength) {
    throw ArgumentError('地点不能超过 $maxMissionLocationLength 个字符');
  }
  return text;
}

/// 仓储直接创建也检查相同规则，不让旁路入口保存不同格式。
void validateMissionLocation(String? value) {
  if (value != normalizeMissionLocation(value)) {
    throw ArgumentError('地点需去除首尾空白并使用单行文字；未填写时为 null');
  }
}
