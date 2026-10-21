# 异步、Stream、并发与错误语义

来源：[Asynchrony](https://dart.dev/language/async) · [Concurrency](https://dart.dev/language/concurrency) · [Error handling](https://dart.dev/language/error-handling) · [Using streams](https://dart.dev/libraries/async/using-streams)

## Future 与 await

- `(LANGUAGE)` `async` 返回 `Future<T>` 或 `Future<void>`；在异步函数中 `await` 一个 `Future` 得到完成结果或接收错误。没有被 await 的 Future 不自动属于调用事务。
- `(TEAM)` 业务写操作必须是可等待的 `Future<Result>`；除 UI 不要求等待的预定场景，不显式选择 `unawaited` 就不能无意丢弃 Future。
- `(TEAM)` 外部调用只可重试**幂等操作**；带事件追加的任务按唯一请求键或事务状态去重，不能通过重试造出额外 START/END。
- `(TEAM)` 一个调用的“成功”需要明确定义为业务事实提交；通知投递、缓存刷新等后续副作用可失败，不能伪装整个业务已回滚。

## Stream / Cancel

- `(LANGUAGE)` `StreamSubscription` 有 `cancel()`；Widget/VM 释放时应取消自己拥有的订阅。
- `(TEAM)` 明确单订阅/广播流、异常流与关闭语义；同一事实源向多个订阅者广播不代表有多个可写事实源。
- `(TEAM)` 从未订阅的流不会神奇完成工作；测试要控制发射时机和订阅生命周期。

## Isolate

- `(LANGUAGE)` isolate 之间不共享普通可变对象内存，依消息传递协作；异步 event loop 并不是数据库原子事务。
- `(TEAM)` 需要在数据库连接/持有锁的实现边界配置串行化，不要用全局 Dart bool 假装跨 isolate、跨进程唯一执行约束。
- `(TEAM)` 大计算可移到 isolate，但不要在多个 isolate 中直接复用一个不可共享的数据库连接对象。

## 异常和业务结果

- `(LANGUAGE)` `throw`, `on`, `catch`, `finally`, `rethrow` 有明确控制流；`rethrow` 保留原异常上下文。
- `(TEAM)` 对预期的业务拒绝（如状态非法、截止已到）优先设计可识别的 typed failure/result；不要捕获所有异常后返回“成功”。
- `(TEAM)` 程序故障（IO 失败、DB 损坏、解析意外）应保留诊断信息，向用户展示安全且准确的说明。
- `(TEAM)` 时钟倒退与截止已到不是同一种错误，不能共用一个笼统 `Exception('invalid')`。

## 反例

```dart
Future<void> startMission() async {                   // 有异步函数签名。
  repository.insertStartEvent();                      // 错误：未等待保存完成，且可能丢失异常。
  notifyUserSuccess();                                // 错误：提交之前就宣布成功。
}
```

## 较好写法（接口示意）

```dart
Future<void> startMission() async {                   // 明确可等待的命令。
  await repository.insertStartEvent();                // 业务事实成功提交后继续。
  await refreshUiProjection();                        // 事实视图重新查询，不重复造状态。
}
```

这里只演示 `await` 顺序，不证明 `repository.insertStartEvent` 的事务/并发正确性；必须在具体 repository 和数据库测试中验证。
