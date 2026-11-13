/// 总结队列的对象层级；数据库和工具协议只在边界使用稳定的 [name]。
enum AnalysisScope {
  mission,
  node,
  goal,
  memory,
  reflection;

  /// 未知层级必须报错，不能误当成目标总结或读取另一类对象。
  static AnalysisScope parse(String value) => switch (value) {
    'mission' => mission,
    'node' => node,
    'goal' => goal,
    'memory' => memory,
    'reflection' => reflection,
    _ => throw FormatException('未知总结层级：$value'),
  };
}
