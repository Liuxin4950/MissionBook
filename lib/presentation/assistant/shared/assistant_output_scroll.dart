import 'package:flutter/widgets.dart';

/// 助手输出滚动的共同判定；主页面正向排列，悬浮聊天可使用反向排列。
abstract final class AssistantOutputScroll {
  static const latestThreshold = 24.0;

  /// 判断当前位置是否在最新消息端。
  static bool isAtLatest(ScrollMetrics metrics, {bool reverse = true}) {
    final latest = reverse ? metrics.minScrollExtent : metrics.maxScrollExtent;
    return (metrics.pixels - latest).abs() <= latestThreshold;
  }

  /// 新内容到达且用户离开最新位置时，才显示回到底部入口。
  static bool shouldShowJumpToLatest({
    required bool following,
    required bool hasNewOutput,
  }) => !following && hasNewOutput;

  /// 只处理用户主动滚动，避免程序化滚动反过来取消跟随状态。
  static bool isUserScroll(ScrollNotification notification) =>
      notification.depth == 0 && notification is UserScrollNotification;
}
