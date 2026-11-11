// Drift 2.34.0 声明公共 API 稳定，实验标记仅指底层传输协议；这里只解包公开异常。
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:sqlite3/common.dart' show SqliteException;

/// Native 后台连接会包装原异常；保留 SQLite 结果码判断，不解析驱动错误文案。
bool isSqliteBusy(Object error) {
  var cause = error;
  while (cause is DriftRemoteException) {
    cause = cause.remoteCause;
  }
  return cause is SqliteException && [5, 6].contains(cause.resultCode);
}
