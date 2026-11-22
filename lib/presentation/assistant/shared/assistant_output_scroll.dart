import 'package:flutter/widgets.dart';

/// 助手输出滚动的共同判定，适用于 reverse=true 的消息列表。
abstract final class AssistantOutputScroll {
  static const latestThreshold = 24.0;

  /// reverse 列表的最小滚动范围就是视觉上的最新消息位置。
  static bool isAtLatest(ScrollMetrics metrics) =>
      (metrics.pixels - metrics.minScrollExtent).abs() <= latestThreshold;

  /// 新内容到达且用户离开最新位置时，才显示回到底部入口。
  static bool shouldShowJumpToLatest({
    required bool following,
    required bool hasNewOutput,
  }) => !following && hasNewOutput;

  /// 只处理用户主动滚动，避免程序化滚动反过来取消跟随状态。
  static bool isUserScroll(ScrollNotification notification) =>
      notification.depth == 0 && notification is UserScrollNotification;
}
