import 'dart:async';

/// 按拥有者声明的顺序释放全部资源；一项失败不能跳过后面的连接或完成信号。
Future<bool> closeResources(
  Iterable<({String name, FutureOr<void> Function() close})> resources, {
  required void Function(String name, Object error, StackTrace stack) onError,
}) async {
  var succeeded = true;
  for (final resource in resources) {
    try {
      await resource.close();
    } catch (error, stack) {
      succeeded = false;
      onError(resource.name, error, stack);
    }
  }
  return succeeded;
}
