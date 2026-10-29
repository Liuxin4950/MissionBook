import 'dart:async';

/// 一轮运行共享的取消信号；模型、授权等待和工具读取同一个对象。
final class CancellationToken {
  final Completer<void> _cancelled = Completer<void>();
  bool _deadlineExceeded = false;
  bool get deadlineExceeded => _deadlineExceeded;

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel({bool deadlineExceeded = false}) {
    _deadlineExceeded = _deadlineExceeded || deadlineExceeded;
    if (!isCancelled) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const AgentCancelled();
  }

  /// 用于可中断的等待；有写入副作用的工具必须等待真实执行结果。
  Future<T> wait<T>(Future<T> operation) {
    final cancelled = isCancelled
        ? Future<T>.error(const AgentCancelled())
        : whenCancelled.then<T>((_) => throw const AgentCancelled());
    return Future.any<T>([
      cancelled, // 即使已经取消，也先给 operation 装好错误处理再结束等待。
      operation,
    ]);
  }

  /// 退避等待也能立即取消，并真正释放计时器。
  Future<void> delay(Duration duration) async {
    throwIfCancelled();
    final completed = Completer<void>();
    final timer = Timer(duration, completed.complete);
    try {
      await wait(completed.future);
    } finally {
      timer.cancel();
    }
  }
}

/// 当前运行已经收到取消请求。
final class AgentCancelled implements Exception {
  const AgentCancelled();

  @override
  String toString() => 'Agent 运行已取消';
}
