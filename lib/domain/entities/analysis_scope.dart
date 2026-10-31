/// 总结队列的对象层级；数据库和工具协议只在边界使用稳定的 [name]。
enum AnalysisScope {
  record,
  mission,
  node,
  goal,
  memory;

  /// 未知层级必须报错，不能误当成目标总结或读取另一类对象。
  static AnalysisScope parse(String value) => switch (value) {
    'record' => record,
    'mission' => mission,
    'node' => node,
    'goal' => goal,
    'memory' => memory,
    _ => throw FormatException('未知总结层级：$value'),
  };
}
